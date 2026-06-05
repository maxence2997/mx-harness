---
name: mx-flow
description: >
  Full development workflow orchestrator. Brainstorm → plan → scope analysis → worktree →
  convergent loop (TDD → commit → review → triage) → verify → PR → finish.
  Plan, scope, worktree, TDD, verify, and finish are built-in phases.
  Scope analysis (read-only Explore sub-agent) emits .mx/<name>/scope.yaml with per-task
  predicted files, dependencies, complexity (S/M/L), and a parallelizable flag. Phase 5
  consumes this directly: independent M/L tasks in plans of 3+ tasks are dispatched to
  concurrent sub-agents — each in its own isolated git worktree — and the parent
  cherry-picks their commits back in task-id order. Cherry-pick conflicts triage to
  trivial (parent auto-resolves) or non-trivial (task bounces to sequential). Falls
  back to fully sequential on integration-test failure or scope-analyzer failure.
  Verify includes an autonomous content check (cancellation cleanup + squash-into-parent,
  tree-invariant guarded) before handing off to the PR phase.
  Pauses at one human gate (spec approval), all others auto-proceed.
  Use when starting a new feature or significant change from scratch.
  After merge, use /mx-flow finish <name> to clean up.
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-flow
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
---

# mx-flow

## Trigger

```
/mx-flow <topic>          ← full pipeline: idea to PR
/mx-flow finish <name>    ← post-merge cleanup (skip to Phase 8)
```

mx-flow pauses at **one human gate** (spec approval). All other gates auto-proceed —
reports are still shown for visibility.

| Gate | Behaviour |
|------|-----------|
| **GATE 1 — Spec** | **Human** — requires explicit approval |
| **GATE 2 — Task list** | Auto-approved — show for visibility, proceed immediately |
| **GATE 3 — Triage** | Auto-approved — show triage report for visibility, execute all "fix" items immediately |
| **GATE 4 — PR** | Auto-proceed — agent drafts and publishes the PR autonomously. Only pause if the agent cannot determine how to proceed (e.g. no remote configured, ambiguous platform, missing credentials) |

The convergent loop safety limit (3 iterations) always applies — escalation requires
human input regardless.

---

## Overview

mx-flow runs the full development workflow automatically, pausing only at the spec gate.
Between gates, each phase runs in sequence without interruption.

```
Phase 1  Brainstorm  →  Design spec + ADR        (/mx-brainstorm)
           [GATE 1] Spec approval                 ← human (only hard gate)
Phase 2  Plan        →  Ordered task list         (built-in)
Phase 3  Scope     →  Per-task DAG + complexity   (built-in, Explore sub-agent)
Phase 4  Worktree    →  Isolated branch + baseline (built-in)

── convergent loop (max 3 iterations) ──────────────
  Phase 5a  TDD (per task) → Commit              (built-in + /mx-commit)
  Phase 5b  Review → Triage                      (/mx-team-review + /mx-review-triage)
  → if fixes: back to TDD
  → if clean: exit loop
────────────────────────────────────────────────────

Phase 6  Verify      →  Tests + plan + content check (built-in)
Phase 7  PR          →  Draft → publish            (/mx-pr)
Phase 8  Finish      →  Clean up branch + worktree (built-in, post-merge)
```

---

## Gate behaviour

Gates are not "y/n continue" prompts. They are real review and discussion opportunities:

| Gate | Behaviour |
|------|-----------|
| **GATE 1 — Spec** | Show the draft spec. Discuss and adjust until user confirms. |
| **GATE 2 — Tasks** | Show the task list for visibility, then proceed immediately. |
| **GATE 3 — Triage** | Show the triage report for visibility, auto-approve all "fix" items, proceed. |
| **GATE 4 — PR** | Auto-proceed — agent drafts and publishes autonomously. Pause only if agent cannot determine how to proceed. |

---

## Path resolution

All phases use two base directories. Resolve them once at the start.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$REPO_ROOT")
```

| Variable | Path | Contains |
|----------|------|----------|
| `GLOBAL_MX` | `~/.mx/<project>/<name>/` | spec.md, adr.md (permanent) |
| `LOCAL_MX` | `<repo-root>/.mx/<name>/` | plan.md, scope.yaml, worktree/, tmp/ (ephemeral) |

- `~/.mx/<project>/ai-learning.md` is also in GLOBAL (project-level, not per-feature)
- Create directories as needed: `mkdir -p` for both GLOBAL_MX and LOCAL_MX
- On Windows: `GLOBAL_MX` = `%USERPROFILE%\.mx\<project>\<name>\`

---

## Phase 0 — Initialize

Before anything else:

1. Derive the feature name from the topic (kebab-case, ≤ 4 words). Example: `write-timeout-error-propagation`
2. Resolve GLOBAL_MX and LOCAL_MX per the path resolution section above
3. Create both directories if they do not exist
4. **Check `.gitignore`** — ensure `.mx/` is gitignored:
   ```bash
   if [ ! -f "$REPO_ROOT/.gitignore" ]; then
     echo '.mx/' > "$REPO_ROOT/.gitignore"
   elif ! grep -q '^\.mx/$' "$REPO_ROOT/.gitignore"; then
     echo '.mx/' >> "$REPO_ROOT/.gitignore"
   fi
   ```
   If `.gitignore` was created or modified, commit it:
   ```bash
   git add .gitignore && git commit -m "chore: add .mx/ to .gitignore"
   ```
5. **Read relevant context** — based on the topic, use Glob and Read to collect information the brainstorm will need:
   - Files, modules, or packages mentioned explicitly in the topic
   - Related code that is likely in scope (e.g. if topic mentions a component, read adjacent files)
   - Any design docs, behaviour specs, or CLAUDE.md files that apply
   - Read broadly enough that the first brainstorm question is grounded in actual code
6. Announce clearly:

```
mx-flow started
Feature : <feature-name>
Spec    : ~/.mx/<project>/<name>/spec.md (will be written after GATE 1)
Plan    : .mx/<name>/plan.md
Phase   : 1 — Brainstorm
```

Do this before asking any questions or writing any files.

---

## Phase 1 — Brainstorm

Run /mx-brainstorm with the following context:
- The GLOBAL_MX directory has already been created in Phase 0
- The topic is already provided — begin asking clarifying questions immediately, do not ask if the user wants to start

Follow mx-brainstorm's full procedure. It owns the spec and ADR output (written to GLOBAL_MX).

**GATE 1**: Present the draft spec. Do not proceed until the user explicitly confirms.

---

## Phase 2 — Plan

Decompose the approved spec into a concrete, ordered task list.

### Planning principles

These bind every task you write in this phase. The TDD loop in Phase 5 executes the plan literally — if the plan over-reaches, the implementation will too. Lock scope here, not later.

**Simplicity first — minimum code that satisfies the spec.**

- No tasks beyond what the spec requires.
- No abstractions, interfaces, or "flexibility" layers the spec did not ask for.
- No error handling for impossible scenarios.
- No speculative configuration, feature flags, or extension points "for the future".
- If a single function would do, do not invent a class. If a class would do, do not invent a package.

**Surgical changes — touch only what the spec requires.**

- Do not plan to "improve" adjacent code, comments, or formatting that the spec did not call out.
- Do not plan refactors of code that is not broken.
- Match existing style and structure even if a different style would be your preference.
- If you notice unrelated dead code or technical debt, mention it once to the user — do not silently add a cleanup task.
- Orphans your tasks create (now-unused imports, variables, helpers) **must** be cleaned in the same task. Pre-existing dead code is out of scope unless the user approves.

The test for every task: it traces directly to a sentence in the spec. If it does not, drop it or ask the user.

### 2.1 — Read the design spec

Read `GLOBAL_MX/spec.md` in full.
Also read relevant existing code (entry points, interfaces, test files) to understand
the current structure before decomposing.

### 2.2 — Decompose into tasks

Break the spec into the smallest tasks where each task:

- Implements **one behavior** (not a file, not a layer)
- Maps to **one commit type** (`feat`, `fix`, `refactor`, `test`, `chore`, `doc`)
- Has a **concrete expected test**: what to write, what it verifies, expected output
- Can be committed independently without breaking the build

**Forbidden content in any task:**
- `TBD` or `TODO`
- "similar to Task N"
- "add error handling" (without specifying what error and how)
- "update tests" (without specifying which behavior)
- Pseudo-code or vague descriptions

Task format:

```markdown
### Task N — <type>: <subject (≤ 50 chars)>

**What**: <one sentence describing the behavior added or changed>
**Test**: <what test to write — file, scenario, expected result>
**Files**: <which files will change>
```

### 2.3 — Order the tasks

Order tasks so that:
1. Infrastructure / scaffolding comes first
2. Each task builds on previous ones without requiring future tasks
3. Tests for a behavior come in the same task as the implementation (not before, not after)

### 2.4 — Write the plan

Write `LOCAL_MX/plan.md`:

```markdown
# <name> — Plan

> Design spec: ~/.mx/<project>/<name>/spec.md

## Tasks

- [ ] Task 1 — feat: <subject>
- [ ] Task 2 — test: <subject>
- [ ] Task 3 — fix: <subject>
```

Show the full task breakdown (with Task N details) to the user for review.

**GATE 2**: Show the task list for visibility, then proceed immediately. Announce: `Task list auto-approved.`

Allow the user to add, remove, reorder, or rewrite tasks if they intervene before auto-proceed.

---

## Phase 3 — Scope analysis

Read the spec, the plan, and the repo, then produce machine-readable per-task metadata that downstream phases use to reason about dependencies and complexity. The output is `.mx/<name>/scope.yaml`. This phase runs **autonomously via a read-only sub-agent** — no user gate; the parent prints a one-line summary at the end for visibility.

This metadata drives Phase 5's execution mode: tasks marked `parallelizable: true` are dispatched to concurrent sub-agents in a batch (5a-parallel); the rest run sequentially (5a-sequential). Never skip this phase — without `scope.yaml`, every task falls back to sequential execution.

### 3.1 — Spawn the scope analyzer sub-agent

Invoke the Agent tool with `subagent_type: Explore` — read-only repo-scanning is exactly its profile. Brief the sub-agent with:

- Path to `~/.mx/<project>/<name>/spec.md`
- Path to `.mx/<name>/plan.md`
- Repo root (`git rev-parse --show-toplevel`)
- The schema spec (section 3.2) and complexity rubric (section 3.3)
- A directive: write only `.mx/<name>/scope.yaml`; do not modify code, plan, or spec

The sub-agent must:

1. Read spec.md and plan.md
2. Pre-scan the repo: list likely target directories, grep for similar modules / patterns the tasks will extend, identify which existing files are obvious candidates
3. For each task in plan.md, infer the schema fields below
4. Compute `parallelizable = (total_tasks >= 3) AND (depends_on == []) AND (complexity in {M, L})`
   - The `total_tasks >= 3` gate suppresses parallel dispatch on tiny plans, where sub-agent spin-up overhead exceeds the wall-clock savings. The parent passes the total task count to the sub-agent as part of the brief.
5. Write `.mx/<name>/scope.yaml` and return a short summary to the parent (counts of vague tasks, parallel batches, sequential tasks)

### 3.2 — Schema

```yaml
- id: task-1                                   # matches plan.md ordering: task-1, task-2, ...
  task: "<verbatim copy of plan.md bullet>"
  predicted_files:                             # repo-relative paths
    - internal/cache/adapter.go
    - internal/cache/adapter_test.go
  predicted_touches:                           # symbols, functions, endpoints
    - RedisClient.Get
    - RedisClient.Set
  depends_on: []                               # ids of tasks that must finish first; [] if independent
  complexity: M                                # S | M | L
  complexity_reason: "two new files, ~80 LOC, follows existing adapter pattern"
  vague: false                                 # true only when sub-agent could not reliably infer
  vague_reason: ""                             # populated only when vague: true
  parallelizable: false                        # derived field; computed by the sub-agent
```

`depends_on` should reflect either **shared files** (two tasks edit the same file → ordering matters) or **logical preconditions** (task B calls a symbol introduced by task A). When unsure, add the dependency rather than omit it.

### 3.3 — Complexity rubric

| Level | Criteria |
|-------|----------|
| **S** | ≤ ~30 LOC, single file, predicted 1 TDD round, no external integration |
| **M** | ~30–150 LOC, 2–3 files, predicted 1–2 TDD rounds, may touch one integration boundary |
| **L** | > 150 LOC, multi-module, ≥ 2 TDD rounds expected, or non-trivial external integration (DB / network / filesystem / external API) |

When signals are ambiguous, bias toward **higher** complexity and **more** dependencies. Over-estimating costs nothing (parent falls back to sequential); under-estimating creates merge collisions later.

### 3.4 — Refinement loop (max 2 rounds)

After the sub-agent returns, the parent reads `scope.yaml` and inspects for `vague: true` entries.

**Round 1 → Round 2.** If any task has `vague: true`, the parent rewrites those specific bullets in `plan.md` using the sub-agent's `vague_reason` as guidance — name the file(s), the function/endpoint, the interface contract. Then re-invoke the sub-agent. Tasks that were not vague stay untouched.

**After Round 2.** Whatever the sub-agent returns is final. Any task still marked `vague: true` keeps its conservative defaults (`complexity: L`, `parallelizable: false`) and proceeds. Bouncing further has diminishing returns — the task is one that requires hands-on discovery during TDD.

Cap is **2 rounds**. Never loop indefinitely.

### 3.5 — Fallback on failure

If the sub-agent fails (timeout, crash, invalid YAML, missing file after invocation), the parent writes a minimal `scope.yaml` directly:

```yaml
- id: task-N
  task: "<copy from plan.md>"
  predicted_files: []
  predicted_touches: []
  depends_on: []
  complexity: L
  complexity_reason: "scope analyzer failed; conservative default applied"
  vague: true
  vague_reason: "scope analyzer failed; safe fallback applied"
  parallelizable: false
```

Every task gets the same shape. Downstream phases see zero parallelizable tasks and run fully sequential. The flow does not block.

### 3.6 — Summary

Print one line to the user for visibility (not a gate):

```
Scope analysis: <N> tasks → <K> parallel batches (B1: T1+T3, B2: T4), <S> sequential (T2, T5).
```

If everything sequential:

```
Scope analysis: <N> tasks, all sequential (no independent batches identified).
```

If the fallback fired:

```
Scope analysis: failed → conservative defaults applied, all tasks sequential.
```

Then auto-proceed to Phase 4.

---

## Phase 4 — Worktree

Create an isolated git worktree for the feature branch.

### 4.1 — Determine branch name

Apply branch naming convention:

| Change type | Prefix |
|---|---|
| New feature | `feat/<name>` |
| Bug fix | `bugfix/<name>` |
| Quick fix (config, docs, CI) | `fix/<name>` |
| Maintenance, deps, tooling | `chore/<name>` |

If the user provided a name without a prefix, ask which prefix applies.
If the name already has a correct prefix, proceed.

### 4.2 — Create the worktree

First, resolve the base branch in this order:

1. Check if `develop` exists (local or remote):
   ```bash
   git rev-parse --verify develop 2>/dev/null || git rev-parse --verify origin/develop 2>/dev/null
   ```
2. If found → use `develop` as base
3. Otherwise, check if `main` exists:
   ```bash
   git rev-parse --verify main 2>/dev/null || git rev-parse --verify origin/main 2>/dev/null
   ```
4. If found → use `main` as base
5. If neither exists → ask the user which branch to base from

Then create the worktree under LOCAL_MX:

```bash
git worktree add .mx/<name>/worktree -b <branch-name> <base-branch>
```

Verify it was created:

```bash
git worktree list
```

### 4.3 — Run project setup

From within the worktree directory, auto-detect and run setup:

```bash
cd .mx/<name>/worktree

# Go
if [ -f go.mod ]; then go mod download; fi

# Node.js
if [ -f package.json ]; then
  if [ -f pnpm-lock.yaml ]; then pnpm install
  elif [ -f yarn.lock ]; then yarn install
  else npm install; fi
fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi
```

### 4.4 — Verify baseline

Run the full test suite to confirm the worktree starts clean.

Auto-detect priority:
1. `Makefile` with a `check` or `test` target → `make check` or `make test`
2. `package.json` with a `test` script → `npm test` / `yarn test` / `pnpm test`
3. Language detection: `.go` → `go test ./...`, `.rs` → `cargo test`, `.py` → `pytest`, `.cs` → `dotnet test`

**If baseline fails:**
Report the failures and ask the user whether to proceed or investigate first.
Do not proceed silently with a failing baseline.

### 4.5 — Report

```
Worktree ready at .mx/<name>/worktree/
Branch  : <branch-name>
Baseline: <N> tests passing
```

---

## Hard guards

These guards are **non-negotiable**. Violating any of them is a workflow failure.

1. **Worktree required before any Edit/Write** — Before making any code change, verify the working directory is a git worktree (`git rev-parse --git-dir` contains `worktrees/`). If not, STOP and run Phase 4 first.
2. **Review required before verify** — Do not enter Phase 6 unless mx-team-review and mx-review-triage have run on the current branch diff at least once in this session. If unsure, check for a review report in `.mx/<name>/tmp/`.

---

## Phase 5 — Convergent loop

### 5a — Task execution (mode selection)

Read `.mx/<name>/scope.yaml`. Partition the still-`[ ]` tasks in `plan.md`:

1. **Ready-set**: tasks whose `depends_on` are all marked `[x]`.
2. **Parallel batch**: ready-set ∩ `parallelizable: true`. If this batch has **≥ 2** tasks, dispatch them concurrently via **5a-parallel**. If it has 0 or 1 tasks, fold the lone task (if any) into the sequential queue — a one-task batch has no parallelism to exploit.
3. **Sequential queue**: everything else in the ready-set, processed one at a time via **5a-sequential**.

When both a parallel batch and a sequential queue exist, drain the **parallel batch first** so independent work overlaps with subsequent batches' planning. After each batch (parallel or sequential), recompute the ready-set — completing tasks unblocks new ones.

The **Iron Law** (no production code without a failing test first) and the **vertical-slice TDD philosophy** apply in both modes. Parallel mode parallelizes *across* tasks, never *within* a task's RED→GREEN→REFACTOR cycle.

If `scope.yaml` is missing or every task is marked `parallelizable: false` (fallback path from Phase 3.5), skip 5a-parallel entirely — drive every task through 5a-sequential.

---

### 5a-parallel — Parallel batch execution

Each task in the batch runs in its **own isolated git worktree**. Sub-agents work freely — full TDD cycle, commits via `/mx-commit`, full test suite — with no shared state to race against. The parent reconciles by cherry-picking each sub-branch back onto the feature branch in `task_id` order.

#### Pre-flight

```bash
git status --porcelain          # must be empty — abort otherwise
BATCH_BASE=$(git rev-parse HEAD)
```

Record `BATCH_BASE` in conversation context. It is the rollback anchor and the merge base for every cherry-pick in this batch.

#### Dispatch

Issue one `Agent` call **per task in a single message** so all sub-agents run concurrently. For each task:

- **subagent_type**: omit (default catch-all) — sub-agents need Edit/Write/Bash.
- **isolation**: `"worktree"` — the harness creates a temporary worktree branched from the parent's current HEAD (= `BATCH_BASE`) and surfaces the branch name + path on completion.
- **Brief contents:**
  - "You are running one task of a parallel TDD batch in mx-flow. You are isolated in your own git worktree — work freely; you cannot collide with sibling sub-agents."
  - Task ID and full task body copied from `plan.md` (What, Test, Files).
  - `predicted_files` and `predicted_touches` for this task — **advisory only**, not a constraint. Touch whatever the implementation actually needs.
  - One-line summaries of sibling tasks in the batch (awareness only — "if you find yourself doing a sibling's work, stop and return `status: failed` with reason").
  - Iron Law, vertical-slice TDD philosophy, comment policy — copy the same wording 5a-sequential uses, do not paraphrase.
  - **Sub-agent workflow (verbatim in the brief):**
    1. Read existing code relevant to your task.
    2. Iron Law: write a failing test before any production code.
    3. RED → GREEN → REFACTOR, one slice at a time.
    4. Honor the comment policy.
    5. Run the full project test suite — your worktree is isolated, this is safe.
    6. Run `/mx-commit` to commit your changes (one or more commits). Do not push.
    7. Return the YAML block below as the final content of your last message.
  - **Required return shape:**
    ```yaml
    status: success | failed
    task_id: task-<N>
    branch: <result of `git rev-parse --abbrev-ref HEAD`; the harness also surfaces this>
    worktree_path: <result of `git rev-parse --show-toplevel`>
    commits: [<commit hashes you created, oldest first>]
    files_changed: [<repo-relative paths>]
    test_summary: "<all tests passed | N failed — details>"
    failure_reason: "<populated when status: failed; empty otherwise>"
    ```

#### Reconcile (parent runs serially after **all** sub-agents return)

1. **Status triage:**
   - `status: failed` → leave the sub-worktree intact for inspection, enqueue this task into the sequential queue. Do not cherry-pick anything for failed tasks.
   - `status: success` → proceed to cherry-pick.

2. **Cherry-pick successful tasks in `task_id` ascending order.** For each task:
   ```bash
   git cherry-pick <BATCH_BASE>..<sub-branch>
   ```
   - **Clean apply** → continue with next task.
   - **Conflict** → conflict triage (step 3).

3. **Conflict triage** — parent judges each conflict:
   - **Trivial conflict** — both sides added independent, non-overlapping content to the same region (e.g., two new imports in the same import block, two appended test cases at the end of a file, two new entries in a registry slice). Parent resolves by combining both sides preserving order, then:
     ```bash
     git add <resolved files>
     git cherry-pick --continue
     ```
   - **Non-trivial conflict** — both sides semantically modified the same region, or it is unclear how to combine. Parent aborts the in-flight cherry-pick:
     ```bash
     git cherry-pick --abort
     ```
     Enqueue this task into the sequential queue. Continue with the **next** task in cherry-pick order — already-applied tasks stay on the feature branch (incremental progress; no full rollback).

   Calibration:
   - "Two imports added to the same import group" → trivial.
   - "Two new test cases appended to the same test file" → trivial.
   - "Both sides renamed the same function" → non-trivial.
   - "Both sides changed the signature of the same function" → non-trivial.
   - "Side A renamed X, Side B added a call site for X" → non-trivial (semantic — cherry-pick won't catch the broken call).

4. **Integration test:** after all cherry-picks complete (clean or aborted), run the full project test suite on the feature branch (priority order from 5a-sequential — Makefile → package.json → language default).
   - **Pass** → batch done; proceed to step 5.
   - **Fail** → batch-scoped rollback (Abort path below). An integration failure that wasn't seen in any sub-agent's isolated full-suite run means the tasks were not truly independent. Enqueue **all** in-flight batch tasks (including the cleanly cherry-picked ones) back into the sequential queue.

5. **Update `plan.md`:** mark each successfully cherry-picked + integration-passing task `[x]`. Single writer (parent) — no race.

6. **Cleanup** sub-worktrees and sub-branches for tasks that landed cleanly (per Agent-tool docs, worktrees with changes are not auto-cleaned):
   ```bash
   git worktree remove <worktree_path>
   git branch -D <branch>
   ```
   **Keep** the sub-worktree and sub-branch intact when the task was bounced to sequential — the user (or sequential-mode rerun) may want to inspect what the sub-agent produced before discarding.

7. **Announce:** `Parallel batch B<n>: <K> cherry-picked, <C> bounced to sequential, <wall-time>s.`

#### Abort path (batch-scoped rollback — fires only on integration-test failure after merge)

```bash
# Safety: only reset if every commit between BATCH_BASE and HEAD was made by the parent's cherry-picks.
EXPECTED_PICKS=<count of successful cherry-picks the parent ran>
ACTUAL_AHEAD=$(git rev-list --count $BATCH_BASE..HEAD)
if [ "$ACTUAL_AHEAD" -ne "$EXPECTED_PICKS" ]; then
  STOP and ask the user. Do not run git reset.
fi

git reset --hard $BATCH_BASE
```

Then push all batch tasks (cherry-picked and not) back to the sequential queue. Cleanup sub-worktrees as in step 6 above.

Report:
```
Parallel batch B<n> aborted at integration test: <failure summary>. Re-running <K> tasks sequentially.
```

#### When to skip 5a-parallel entirely

Drain everything via 5a-sequential when **any** of:
- The user has uncommitted work in the worktree before the batch starts.
- A prior batch in this flow was aborted at the integration-test step — fall back to sequential for the remainder; do not re-attempt parallel in the same flow.

---

### 5a-sequential — Sequential TDD cycle (per task)

This is the original single-threaded TDD loop. Use it for every task in the sequential queue, plus all tasks bounced from a failed parallel batch.

#### Iron Law

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.**

No exceptions. If you find yourself writing implementation before a test exists,
stop and write the test first. Code written before a test must be deleted and
reimplemented from scratch after the test is in place.

#### Philosophy: Vertical Slices Only

```
WRONG (horizontal slicing):
  RED:   test1, test2, test3
  GREEN: impl1, impl2, impl3   ← never do this

RIGHT (vertical slices):
  RED → GREEN: test1 → impl1
  RED → GREEN: test2 → impl2
  RED → GREEN: test3 → impl3
```

Writing tests in bulk produces tests that verify imagined behavior, not actual behavior.
Each test must respond to what you learned from the previous cycle.

#### For each `[ ]` task in the plan:

**Read the task** — Read `LOCAL_MX/plan.md` and identify the next `[ ]` task.
Read its full specification (What, Test, Files).
Read the relevant existing code before writing anything.

**Tracer bullet (first task only)** — For the first task of a new feature, write one minimal
test that proves the end-to-end path works — even if it only touches a stub. This confirms
the test infrastructure is wired correctly before building out.

**Red: write the failing test** — Write the test as specified in the task.

Test quality rules:
- Tests verify **behavior through public interfaces**, not implementation details
- A good test reads like a specification: "user can do X given Y"
- The test must **fail** before any production code is written
- Run the test and **observe the failure** — if it passes immediately, the test is wrong

```bash
# Auto-detect test runner (priority order):
# 1. Makefile: make check → make test → make lint
# 2. package.json: npm/yarn/pnpm test
# 3. Language: go test ./... | cargo test | pytest | dotnet test | swift test
```

Confirm the test fails with the expected error (missing symbol, assertion failure, etc.).
A test that passes without implementation proves nothing.

**Green: minimal implementation** — Write the **simplest code** that makes the test pass.

Rules:
- Only enough code to pass the current test
- Do not anticipate future tests
- Do not add features not required by the current test
- Speculative code is forbidden

**Comment policy (enforced while writing, not only at review)** — Canonical source:
`mx-team-review/references/principles.md` → *P2 — Comment (Why)*. Essentials:

- **Default: no comment.** Add one only when WHY is non-obvious to a future reader.
- **Forbidden:** comments that restate WHAT the code does, empty doc summaries (`/// Creates an order.`), vague pronouns (`this`, `the above`, `as mentioned`).
- **Required for:** magic numbers, framework-default overrides, business-rule enforcement, external workarounds (link the issue), TODO/FIXME (link or explain why and when).
- **Style:** lead with WHY, name the concrete subject + triggering scenario, hard limit **3 lines**. If it needs more, the code probably needs to change instead.

If you find yourself writing a "WHAT" comment, delete it and improve the identifier name instead.

Run the test again — confirm it passes.
Run the full suite — confirm nothing else broke.

**Refactor** — Only after GREEN, look for improvements:

- Extract duplication
- Improve naming
- Simplify logic
- Apply existing patterns from the codebase

Rules:
- **Never refactor while RED**
- Run tests after each refactor step — if anything breaks, revert immediately
- Refactor is optional; skip if the code is already clean

**Exit condition checklist** — Before marking the task done, verify all five conditions:

```
□ RED observed: test failure was seen with actual output (not assumed)
□ GREEN confirmed: test passes after implementation
□ Full suite clean: no new failures introduced by this change
□ Comment policy: no WHAT-comments, no vague pronouns, magic numbers/workarounds explain WHY, every comment ≤3 lines
□ Plan updated: task marked [x] in .mx/<name>/plan.md
□ Committed: /mx-commit --auto completed for this task
```

If any item is unchecked, do not advance to the next task.

After each task completes, return to **5a (Task execution)** to recompute the ready-set — a finished task may have unblocked a parallel batch. Exit the loop when all tasks are done or a milestone is reached.

### 5b. Review (at milestone)

Run /mx-team-review on the diff since the branch was created:
```bash
git diff $(git merge-base HEAD main)..HEAD
```

Run /mx-review-triage with `--source review` directly (no auto-detect).

**GATE 3**: Show the triage summary, auto-approve all "fix" items, execute immediately. Announce: `Triage auto-approved — executing <N> fixes.`

After fixes are applied:
- If fixes were made → run the test suite → back to 5a for any new tasks, increment iteration counter
- If clean (no fixes needed) → exit the loop

### Loop safety limit

The convergent loop has a maximum of **3 iterations** (one iteration = one full tdd → review → triage cycle).

If the loop reaches 3 iterations without converging to clean:

```
[ESCALATE] Convergent loop has not resolved after 3 iterations.

Current state:
  Iteration: 3/3
  Remaining findings: <list>

Options:
  [A] Continue — extend the loop (you take responsibility)
  [B] Redesign — the findings suggest a design issue; revisit ~/.mx/<project>/<name>/spec.md (design spec)
  [C] Abort — discard this branch and start fresh

Three iterations without convergence usually indicates a design problem, not a code problem.
```

Do not continue automatically. Wait for the user to choose.

---

## Phase 6 — Verify and commit

Final verification gate. No partial checks accepted.

### 6.1 — Run full test suite

Run the complete test suite. No partial runs.

Auto-detect runner (same priority as Phase 5a):
1. Makefile: `make check` → `make test`
2. `package.json`: `npm test` / `yarn test` / `pnpm test`
3. Language: `go test ./...` / `cargo test` / `pytest` / `dotnet test` / `swift test`

Read the full output. Count failures.

**If any test fails:** report the failures with output, stop. Do not proceed.
**If all pass:** state the count explicitly: `N tests passing, 0 failures`.

### 6.2 — Check plan completion

Read `LOCAL_MX/plan.md`.

For every task line, verify its status:
- `[x]` — completed
- `[ ]` — pending

If any task is still `[ ]`, list them and stop. Do not claim completion with open tasks.
If all tasks are `[x]`, report: `All N tasks complete.`

### 6.3 — Remind ai-learning

Show this reminder:

```
Update ~/.mx/<project>/ai-learning.md before closing this session.

Format:
| Date       | Issue or Learning | Root Cause | Prevention Rule |
| ---------- | ----------------- | ---------- | --------------- |
| YYYY-MM-DD | <what happened>   | <why>      | <how to avoid>  |

Record at least one entry — even if no mistakes were made.
Acceptable entries: techniques confirmed, observations, rules verified.
```

### 6.4 — Gate result

Only if 5.1 and 5.2 both pass:

```
Verification passed.
  Tests: N passing, 0 failures
  Plan:  N/N tasks complete

Ready to commit and push.
```

If verification passes, run /mx-commit --auto for any remaining staged changes.

### 6.5 — Content check (autonomous cleanup)

Multiple TDD → review → triage iterations leave behind two kinds of history noise:

1. **Net-zero churn** — changes that get reverted on the same branch. Full: `++A` in commit 1, `--A` in commit 4 → both commits drop. Partial: `++A,++B` in commit 1, `--B,++C` in commit 5 → effective net is `++A,++C`, so the `B`-related hunks come out of both commits.
2. **Squash-able fixups** — small touch-ups that logically belong inside an earlier commit.

**Both passes run autonomously — no user prompt.** Safety comes from a tree-invariant check, not user confirmation: the working-tree hash before and after each pass MUST match. If they differ for any reason, revert that pass to its starting HEAD and continue. Each pass is its own transaction.

#### 6.5.0 — Capture pre-state

```bash
PRE_HEAD=$(git rev-parse HEAD)
PRE_TREE=$(git rev-parse HEAD^{tree})
BASE=$(git merge-base HEAD <base-branch>)
```

`<base-branch>` is the same one resolved in Phase 4.2.

#### 6.5.1 — Pass 1: cancellation cleanup

Read every commit's diff in `BASE..HEAD` (`git show --format= <sha>`). Look for hunks that mutually cancel and remove them so they leave no trace in the PR.

##### Level 1 — Whole-commit inverse pairs (rule-based)

A pair (X, Y) with X earlier than Y qualifies if Y's diff is the exact reverse of X's diff — every `+line` in X appears as `-line` in Y in the same file and identical content, and vice versa, with the same hunk locations. No semantic judgment needed; this is mechanical.

For each qualifying pair, schedule both commits for **removal in entirety**. Multiple pairs can be processed together.

##### Level 2 — Partial cancellation (semantic judgment)

For cancelling hunks that are **not** part of a whole-commit inverse pair, the agent must judge content relatedness before acting. Textual cancellation alone is not sufficient — the cancelling lines might be two independent decisions that coincidentally touched the same code.

Identify candidate hunk groups: a `+lines` segment in commit X with a matching `-lines` segment (identical content) in a later commit Y on the branch.

For each candidate group, the agent reads the diffs, the surrounding code, and the commits in between, then judges relatedness. **All** of the following gates must hold; if any is uncertain, skip the group (default to keeping history fidelity):

- **File proximity**: cancelling hunks are in the same file, or in files that are clearly part of the same logical change (e.g., a struct and its test file).
- **Iteration continuity**: the commits between X and Y are part of the same iteration on this branch (e.g., review-triage adjustments), not work in an unrelated feature area.
- **Subject signals**: commit subjects on the iteration path suggest refinement (`fix`, `address review`, `adjust`, `refactor`, follow-up wording) rather than two independent decisions.
- **Local semantic relatedness**: the `+A` and `-A` occur in semantically related positions — same function, same block, related logic. Incidental coincidences (e.g., two unrelated commits both adding then removing a blank line) → reject.

If all gates pass, schedule the cancelling hunks for removal from X and from Y. Commits that become empty after hunk removal are dropped; commits with remaining content are rewritten with the cancelling hunks gone.

##### Execute Pass 1

If nothing was scheduled, log `Pass 1: no cancellation candidates` and skip to Pass 2.

Otherwise rewrite the branch. The mechanism is the agent's choice — `git format-patch` + edit + `git am`, or `git rebase --interactive` with per-commit edits, or `git commit-tree` reconstruction are all acceptable. The contract: produce a branch where the scheduled commits/hunks are gone and everything else is byte-identical.

A reference recipe using format-patch:

```bash
PATCHDIR=$(mktemp -d)
git format-patch "$BASE..HEAD" -o "$PATCHDIR"
# Drop fully-cancelled commits: rm "$PATCHDIR"/<seq>-*.patch
# For partial cancellation: edit the patch file to delete the cancelling hunks (keep the header)
git reset --hard "$BASE"
git am "$PATCHDIR"/*.patch    # empty patches are skipped automatically
rm -rf "$PATCHDIR"
```

##### Verify Pass 1 tree invariant

```bash
POST_TREE=$(git rev-parse HEAD^{tree})
```

`POST_TREE` MUST equal `PRE_TREE`. If they differ, the cleanup changed the working tree — revert:

```bash
git reset --hard "$PRE_HEAD"
```

If `git am` or rebase fails mid-flight (conflict, empty commit refusal, etc.), abort and revert:

```bash
git am --abort 2>/dev/null || git rebase --abort 2>/dev/null
git reset --hard "$PRE_HEAD"
```

Either failure mode → log `Pass 1 aborted (tree/rebase mismatch), cancellations kept as-is`. Continue to Pass 2 from `$PRE_HEAD`.

On success → update the baseline for Pass 2:

```bash
PRE_HEAD=$(git rev-parse HEAD)
PRE_TREE=$(git rev-parse HEAD^{tree})    # must still equal the original PRE_TREE
```

#### 6.5.2 — Pass 2: squash-into-parent

List commits with `git log $BASE..HEAD --pretty=format:'%h %s'` and inspect each diff with `git show --stat <sha>`.

Flag a commit as a squash candidate only if it meets **one** of these high-confidence signals AND points to exactly one parent commit on the branch. Ambiguous candidates are skipped silently.

**Subject signals**:
- Starts with `fixup!` or `squash!`
- Mentions `wip`, `tmp`, `temp`, `debug`, `nit`, `typo`, `oops`
- Mentions `address review`, `address feedback`, `PR feedback`, `code review`, `review comments`

**Diff signals**:
- Changed-files set is a subset of exactly one earlier commit's files AND the diff is small (≤ 20 lines added+removed combined)
- Touches the same function or hunk range as exactly one earlier commit on the branch (overlapping line ranges in the same file)

If a candidate matches multiple potential parents, skip it. Better to leave a noisy commit than to merge into the wrong parent.

If no candidates are found, log `Pass 2: no squash candidates` and skip to the report.

Otherwise rewrite each candidate's subject to `fixup! <parent-subject>` and run autosquash:

```bash
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash $BASE
```

Verify the tree invariant the same way as Pass 1. On any failure: `git rebase --abort 2>/dev/null && git reset --hard "$PRE_HEAD"`, log `Pass 2 aborted (tree/rebase mismatch), squashes kept as-is`, proceed.

#### 6.5.3 — Report

```
Content check:
  Pass 1 (cancellation): <K1> commit(s) removed, <H1> hunk(s) trimmed   (or "no candidates" / "aborted")
  Pass 2 (squash):       <K2> commit(s) folded into <P> parent(s)        (or "no candidates" / "aborted")
  Tree unchanged. <N before> → <N after> commits on branch.
```

Phase 6 ends here. Proceed to Phase 7.

### Abort path

When verification fails, present three recovery options:

```
[VERIFICATION FAILED]
  <specific failure: test output / open tasks>

Recovery options:
  [A] Investigate — return to Phase 5a to fix the failing test or task
        Re-entry: specify which task or failing test to address first
  [B] Adjust plan — the failure reveals that a task definition was wrong
        Re-entry: edit .mx/<name>/plan.md, then re-run Phase 5a for that task
  [C] Abort branch — this branch is not recoverable
        Will preserve: ~/.mx/<project>/<name>/spec.md and adr.md (design spec)
        Will discard:  .mx/<name>/plan.md
        Reminder:      git worktree remove .mx/<name>/worktree
```

Wait for the user to choose. Do not attempt to fix anything automatically.

---

## Phase 7 — PR

Run /mx-pr. It will:
- Draft the PR description from the spec and git log
- Present the draft for review (**GATE 4**)
- Offer options: publish to a platform, skip, or hand off

Auto-proceed — draft the PR and publish directly. Show the draft for visibility but do not wait for confirmation. Only pause and ask the user if:
- No git remote is configured
- Multiple remotes exist and the target is ambiguous
- Platform credentials are missing or authentication fails
- Any other situation where the agent cannot determine the correct action

Announce: `PR auto-published.`

After /mx-pr completes (published or skipped), announce:

```
mx-flow complete.
After merge: /mx-flow finish <name>
```

---

## Phase 8 — Finish (post-merge cleanup)

Triggered by `/mx-flow finish <name>`. This phase runs independently from the main pipeline.

### 8.1 — Confirm the PR is merged

Ask the user to confirm the PR is merged before proceeding.
If running from within a worktree, remind the user to switch back to the main branch first — worktree removal must be run from outside the worktree.

### 8.2 — Delete the plan and scope files

```bash
rm -f .mx/<name>/plan.md .mx/<name>/scope.yaml
```

Both files describe in-flight work — they have no value after all tasks are done. Report: `Deleted .mx/<name>/plan.md and scope.yaml`

### 8.3 — Preserve design spec and ADRs

Do **not** delete `~/.mx/<project>/<name>/spec.md` or `~/.mx/<project>/<name>/adr.md`.
The design spec records what was built, the ADRs record why — both have lasting documentation value.

Report: `Kept ~/.mx/<project>/<name>/spec.md and adr.md (preserved)`

### 8.4 — Clean up temp files

List all files in `.mx/<name>/tmp/` with timestamps:

```bash
ls -lt .mx/<name>/tmp/ 2>/dev/null
```

Show the list to the user and ask which to delete. Delete the selected ones.
If `.mx/<name>/tmp/` is empty after deletion, remove the directory.

### 8.5 — Remove the worktree

```bash
git worktree remove .mx/<name>/worktree
```

**If the command succeeds:** report `Worktree removed.`

**If git refuses** (uncommitted changes detected):

```
git worktree remove failed — the worktree has uncommitted changes.

Either:
  1. Go into .mx/<name>/worktree, commit or discard changes, then re-run /mx-flow finish
  2. Force remove (loses uncommitted changes):
     git worktree remove --force .mx/<name>/worktree
```

Do not force-remove automatically. Wait for the user to decide.

### 8.6 — Delete the branch

```bash
git branch -d <branch-name>
```

`-d` (not `-D`) is intentional — git refuses to delete an unmerged branch, which acts as a safety net.

**If git refuses** (branch not fully merged):

```
Branch deletion failed — git reports the branch is not fully merged.

If the PR was squash-merged or rebased, the branch may look unmerged to git.
To force delete:
  git branch -D <branch-name>
```

Do not force-delete automatically. Wait for the user to confirm.

### 8.7 — Clean up local .mx directory

If `.mx/<name>/` is now empty, remove it:
```bash
rmdir .mx/<name>/ 2>/dev/null
```

### 8.8 — Summary

```
Finished <name>:
  ✓ Plan and scope deleted (.mx/<name>/plan.md, scope.yaml)
  ✓ Design spec and ADRs preserved at ~/.mx/<project>/<name>/
  ✓ Temp files cleared (.mx/<name>/tmp/)
  ✓ Worktree removed
  ✓ Branch deleted
```

If any step was skipped due to a safety refusal, mark it with `○` and note what remains.
