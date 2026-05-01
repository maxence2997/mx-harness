---
name: mx-flow
description: >
  Full development workflow orchestrator. Brainstorm → plan → worktree → convergent loop
  (TDD → commit → review → triage) → verify → PR → finish.
  Plan, worktree, TDD, verify, and finish are built-in phases.
  Pauses at one human gate (spec approval), all others auto-proceed.
  Use when starting a new feature or significant change from scratch.
  After merge, use /mx-flow finish <name> to clean up.
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
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
/mx-flow finish <name>    ← post-merge cleanup (skip to Phase 7)
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
Phase 3  Worktree    →  Isolated branch + baseline (built-in)

── convergent loop (max 3 iterations) ──────────────
  Phase 4a  TDD (per task) → Commit              (built-in + /mx-commit)
  Phase 4b  Review → Triage                      (/mx-team-review + /mx-review-triage)
  → if fixes: back to TDD
  → if clean: exit loop
────────────────────────────────────────────────────

Phase 5  Verify      →  Full suite + plan check   (built-in)
Phase 6  PR          →  Draft → publish            (/mx-pr)
Phase 7  Finish      →  Clean up branch + worktree (built-in, post-merge)
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
| `LOCAL_MX` | `<repo-root>/.mx/<name>/` | plan.md, worktree/, tmp/ (ephemeral) |

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

## Phase 3 — Worktree

Create an isolated git worktree for the feature branch.

### 3.1 — Determine branch name

Apply branch naming convention:

| Change type | Prefix |
|---|---|
| New feature | `feat/<name>` |
| Bug fix | `bugfix/<name>` |
| Quick fix (config, docs, CI) | `fix/<name>` |
| Maintenance, deps, tooling | `chore/<name>` |

If the user provided a name without a prefix, ask which prefix applies.
If the name already has a correct prefix, proceed.

### 3.2 — Create the worktree

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

### 3.3 — Run project setup

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

### 3.4 — Verify baseline

Run the full test suite to confirm the worktree starts clean.

Auto-detect priority:
1. `Makefile` with a `check` or `test` target → `make check` or `make test`
2. `package.json` with a `test` script → `npm test` / `yarn test` / `pnpm test`
3. Language detection: `.go` → `go test ./...`, `.rs` → `cargo test`, `.py` → `pytest`, `.cs` → `dotnet test`

**If baseline fails:**
Report the failures and ask the user whether to proceed or investigate first.
Do not proceed silently with a failing baseline.

### 3.5 — Report

```
Worktree ready at .mx/<name>/worktree/
Branch  : <branch-name>
Baseline: <N> tests passing
```

---

## Hard guards

These guards are **non-negotiable**. Violating any of them is a workflow failure.

1. **Worktree required before any Edit/Write** — Before making any code change, verify the working directory is a git worktree (`git rev-parse --git-dir` contains `worktrees/`). If not, STOP and run Phase 3 first.
2. **Review required before verify** — Do not enter Phase 5 unless mx-team-review and mx-review-triage have run on the current branch diff at least once in this session. If unsure, check for a review report in `.mx/<name>/tmp/`.

---

## Phase 4 — Convergent loop

### 4a. TDD cycle (repeat per task)

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
□ Plan updated: task marked [x] in .mx/<name>/plan.md
□ Committed: /mx-commit --auto completed for this task
```

If any item is unchecked, do not advance to the next task.

Continue until all tasks are done or a milestone is reached.

### 4b. Review (at milestone)

Run /mx-team-review on the diff since the branch was created:
```bash
git diff $(git merge-base HEAD main)..HEAD
```

Run /mx-review-triage with `--source review` directly (no auto-detect).

**GATE 3**: Show the triage summary, auto-approve all "fix" items, execute immediately. Announce: `Triage auto-approved — executing <N> fixes.`

After fixes are applied:
- If fixes were made → run the test suite → back to 4a for any new tasks, increment iteration counter
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

## Phase 5 — Verify and commit

Final verification gate. No partial checks accepted.

### 5.1 — Run full test suite

Run the complete test suite. No partial runs.

Auto-detect runner (same priority as Phase 4a):
1. Makefile: `make check` → `make test`
2. `package.json`: `npm test` / `yarn test` / `pnpm test`
3. Language: `go test ./...` / `cargo test` / `pytest` / `dotnet test` / `swift test`

Read the full output. Count failures.

**If any test fails:** report the failures with output, stop. Do not proceed.
**If all pass:** state the count explicitly: `N tests passing, 0 failures`.

### 5.2 — Check plan completion

Read `LOCAL_MX/plan.md`.

For every task line, verify its status:
- `[x]` — completed
- `[ ]` — pending

If any task is still `[ ]`, list them and stop. Do not claim completion with open tasks.
If all tasks are `[x]`, report: `All N tasks complete.`

### 5.3 — Remind ai-learning

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

### 5.4 — Gate result

Only if 5.1 and 5.2 both pass:

```
Verification passed.
  Tests: N passing, 0 failures
  Plan:  N/N tasks complete

Ready to commit and push.
```

If verification passes, run /mx-commit --auto for any remaining staged changes.

### Abort path

When verification fails, present three recovery options:

```
[VERIFICATION FAILED]
  <specific failure: test output / open tasks>

Recovery options:
  [A] Investigate — return to Phase 4a to fix the failing test or task
        Re-entry: specify which task or failing test to address first
  [B] Adjust plan — the failure reveals that a task definition was wrong
        Re-entry: edit .mx/<name>/plan.md, then re-run Phase 4a for that task
  [C] Abort branch — this branch is not recoverable
        Will preserve: ~/.mx/<project>/<name>/spec.md and adr.md (design spec)
        Will discard:  .mx/<name>/plan.md
        Reminder:      git worktree remove .mx/<name>/worktree
```

Wait for the user to choose. Do not attempt to fix anything automatically.

---

## Phase 6 — PR

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

## Phase 7 — Finish (post-merge cleanup)

Triggered by `/mx-flow finish <name>`. This phase runs independently from the main pipeline.

### 7.1 — Confirm the PR is merged

Ask the user to confirm the PR is merged before proceeding.
If running from within a worktree, remind the user to switch back to the main branch first — worktree removal must be run from outside the worktree.

### 7.2 — Delete the plan file

```bash
rm .mx/<name>/plan.md
```

The plan has no value after all tasks are done. Report: `Deleted .mx/<name>/plan.md`

### 7.3 — Preserve design spec and ADRs

Do **not** delete `~/.mx/<project>/<name>/spec.md` or `~/.mx/<project>/<name>/adr.md`.
The design spec records what was built, the ADRs record why — both have lasting documentation value.

Report: `Kept ~/.mx/<project>/<name>/spec.md and adr.md (preserved)`

### 7.4 — Clean up temp files

List all files in `.mx/<name>/tmp/` with timestamps:

```bash
ls -lt .mx/<name>/tmp/ 2>/dev/null
```

Show the list to the user and ask which to delete. Delete the selected ones.
If `.mx/<name>/tmp/` is empty after deletion, remove the directory.

### 7.5 — Remove the worktree

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

### 7.6 — Delete the branch

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

### 7.7 — Clean up local .mx directory

If `.mx/<name>/` is now empty, remove it:
```bash
rmdir .mx/<name>/ 2>/dev/null
```

### 7.8 — Summary

```
Finished <name>:
  ✓ Plan deleted (.mx/<name>/plan.md)
  ✓ Design spec and ADRs preserved at ~/.mx/<project>/<name>/
  ✓ Temp files cleared (.mx/<name>/tmp/)
  ✓ Worktree removed
  ✓ Branch deleted
```

If any step was skipped due to a safety refusal, mark it with `○` and note what remains.
