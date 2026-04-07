---
name: mx-flow
description: >
  Full development workflow orchestrator. Runs mx-brainstorm → mx-plan → mx-worktree →
  convergent loop (mx-tdd → mx-commit → mx-team-review → mx-review-triage) → mx-verify.
  Pauses at human decision gates. Normal mode: 4 gates. Fast mode (--fast): 1 hard gate
  (spec approval only), all others auto-proceed. Use when starting a new feature or significant change from scratch.
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
/mx-flow <topic>
/mx-flow --fast <topic>
/mx-flow
```

### Fast mode

When `--fast` is passed (or the user says "fast mode", "快速模式", etc.), mx-flow reduces
to **one hard human gate**:

| Gate | Fast mode behaviour |
|------|---------------------|
| **GATE 1 — Spec** | **Human** — still requires explicit approval |
| **GATE 2 — Task list** | Auto-approved — show for visibility, proceed immediately |
| **GATE 3 — Triage** | Auto-approved — show triage report for visibility, execute all "fix" items immediately |
| **GATE 4 — PR** | Auto-proceed — agent drafts and publishes the PR autonomously. Only pause if the agent cannot determine how to proceed (e.g. no remote configured, ambiguous platform, missing credentials) |

The convergent loop safety limit (3 iterations) still applies in fast mode — escalation
always requires human input regardless of mode.

---

## Overview

mx-flow runs the full development workflow automatically, pausing only at human gates.
Between gates, each skill is invoked in sequence without interruption.

### Normal mode (4 gates)

```
mx-brainstorm
  [GATE 1] Spec approval
mx-plan
  [GATE 2] Task list approval
mx-worktree

── convergent loop ──────────────────────────────────────
  mx-tdd (per task) → mx-commit
  [milestone: all tasks done or checkpoint reached]
  mx-team-review
  mx-review-triage --source review
  [GATE 3] Triage approval → execute fixes
  → if fixes made: back to mx-tdd
  → if clean: exit loop
─────────────────────────────────────────────────────────

mx-verify
mx-commit (if final changes)
mx-pr
  [GATE 4] PR review
```

### Fast mode (1 hard gate)

```
mx-brainstorm
  [GATE 1] Spec approval          ← human (only hard gate)
mx-plan                            ← auto-approve task list
mx-worktree

── convergent loop ──────────────────────────────────────
  mx-tdd (per task) → mx-commit
  mx-team-review
  mx-review-triage --source review ← show report, auto-approve fixes
  → if fixes made: back to mx-tdd
  → if clean: exit loop
─────────────────────────────────────────────────────────

mx-verify
mx-commit (if final changes)
mx-pr                              ← auto-proceed (pause only if stuck)
```

---

## Gate behaviour

Gates are not "y/n continue" prompts. They are real review and discussion opportunities:

| Gate | Normal mode | Fast mode |
|------|-------------|-----------|
| **GATE 1 — Spec** | Show the draft spec. Discuss and adjust until user confirms. | Same — always requires human approval. |
| **GATE 2 — Tasks** | Show the full task breakdown. Add, remove, reorder freely. | **Skipped** — show the task list for visibility, then proceed immediately. |
| **GATE 3 — Triage** | Show the triage report. Adjust bucket assignments. Approve before executing fixes. | Show the triage report for visibility, auto-approve all "fix" items, proceed. |
| **GATE 4 — PR** | Present PR draft. User reviews and chooses platform or skips. | Auto-proceed — agent drafts and publishes autonomously. Pause only if agent cannot determine how to proceed. |

---

## Phase 0 — Initialize

Before anything else:

1. **Detect fast mode** — if `--fast` flag is present, or the user said "fast mode" / "快速模式", set `FAST_MODE=true`. Strip the flag from the topic string.
2. Derive the feature name from the topic (kebab-case, ≤ 4 words). Example: `write-timeout-error-propagation`
3. Resolve the MX directory (same rules as mx-brainstorm: `git rev-parse --show-toplevel` → project name → `~/.mx/<project>/<name>/`)
4. Create the directory if it does not exist
5. **Read relevant context** — based on the topic, use Glob and Read to collect information the brainstorm will need:
   - Files, modules, or packages mentioned explicitly in the topic
   - Related code that is likely in scope (e.g. if topic mentions a component, read adjacent files)
   - Any design docs, behaviour specs, or CLAUDE.md files that apply
   - Read broadly enough that the first brainstorm question is grounded in actual code
6. Announce clearly:

```
mx-flow started
Mode    : fast | normal
Feature : <feature-name>
Spec    : ~/.mx/<project>/<name>/spec.md (will be written after GATE 1)
Phase   : 1 — Brainstorm
```

Do this before asking any questions or writing any files.

---

## Phase 1 — Brainstorm

Run mx-brainstorm with the following context:
- The MX directory has already been created in Phase 0 (`~/.mx/<project>/<name>/`)
- The topic is already provided — begin asking clarifying questions immediately, do not ask if the user wants to start

Follow mx-brainstorm's full procedure. It owns the spec and ADR output.

**GATE 1**: Present the draft spec. Do not proceed until the user explicitly confirms.

---

## Phase 2 — Plan

Run mx-plan for the confirmed spec.
Follow its full procedure (decompose into tasks, no placeholders).

**GATE 2**: Present the full task breakdown.
- **Normal mode**: Do not proceed until the user explicitly confirms.
- **Fast mode**: Show the task list for visibility, then proceed immediately. Announce: `[fast mode] Task list auto-approved.`

---

## Phase 3 — Worktree

Run mx-worktree with the branch name derived from the feature name.
Follow its full procedure (gitignore checks, setup, baseline).

If baseline fails, pause and resolve before continuing.

---

## Phase 4 — Convergent loop

### 4a. TDD cycle (repeat per task)

For each `[ ]` task in the plan:
1. Run mx-tdd for that task (full red → green → refactor cycle)
2. Run mx-commit --auto for the completed task
3. Mark `[x]` in the plan

Continue until all tasks are done or a milestone is reached.

### 4b. Review (at milestone)

Run mx-team-review on the diff since the branch was created:
```bash
git diff $(git merge-base HEAD main)..HEAD
```

Run mx-review-triage with `--source review` directly (no auto-detect).

**GATE 3**: Present the triage report.
- **Normal mode**: Discuss adjustments. Approve before executing.
- **Fast mode**: Show the triage summary, auto-approve all "fix" items, execute immediately. Announce: `[fast mode] Triage auto-approved — executing <N> fixes.`

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

Run mx-verify.
If verification passes, run mx-commit --auto for any remaining staged changes.

---

## Phase 6 — PR

Run mx-pr. It will:
- Draft the PR description from the spec and git log
- Present the draft for review (**GATE 4**)
- Offer three options:
  - Publish to a platform (GitHub / GitLab / Bitbucket) — mx-pr handles push + PR creation
  - Skip — branch stays local, user handles push and PR manually
  - Exit — hand off entirely, no further action taken

**Fast mode**: Auto-proceed — draft the PR and publish directly. Show the draft for visibility but do not wait for confirmation. Only pause and ask the user if:
- No git remote is configured
- Multiple remotes exist and the target is ambiguous
- Platform credentials are missing or authentication fails
- Any other situation where the agent cannot determine the correct action

Announce: `[fast mode] PR auto-published.`

After mx-pr completes (published or skipped), announce:

```
mx-flow complete.
After merge: /mx-finish <name>
```
