---
name: mx-flow
description: >
  Full development workflow orchestrator. Runs mx-brainstorm → mx-plan → mx-worktree →
  convergent loop (mx-tdd → mx-commit → mx-team-review → mx-review-triage) → mx-verify.
  Pauses at three human decision gates: spec approval, task list approval, and triage approval.
  Use when starting a new feature or significant change from scratch.
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
/mx-flow
```

---

## Overview

mx-flow runs the full development workflow automatically, pausing only at three gates
where human judgement is required. Between gates, each skill is invoked in sequence
without interruption.

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
```

---

## Gate behaviour

Gates are not "y/n continue" prompts. They are real review and discussion opportunities:

| Gate | What happens |
|------|-------------|
| **GATE 1 — Spec** | Show the draft spec. Discuss and adjust until user confirms. |
| **GATE 2 — Tasks** | Show the full task breakdown. Add, remove, reorder freely. |
| **GATE 3 — Triage** | Show the triage report. Adjust bucket assignments. Approve before executing fixes. |

---

## Phase 1 — Brainstorm

Run mx-brainstorm for the given topic.
Follow its full procedure (one question at a time, 2-3 approaches).

**GATE 1**: Present the draft spec. Do not proceed until the user explicitly confirms.

---

## Phase 2 — Plan

Run mx-plan for the confirmed spec.
Follow its full procedure (decompose into tasks, no placeholders).

**GATE 2**: Present the full task breakdown. Do not proceed until the user explicitly confirms.

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
2. Run mx-commit for the completed task
3. Mark `[x]` in the plan

Continue until all tasks are done or a milestone is reached.

### 4b. Review (at milestone)

Run mx-team-review on the diff since the branch was created:
```bash
git diff $(git merge-base HEAD main)..HEAD
```

Run mx-review-triage with `--source review` directly (no auto-detect).

**GATE 3**: Present the triage report. Discuss adjustments. Approve before executing.

After approved fixes are applied:
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
If verification passes, run mx-commit for any remaining staged changes.

---

## Phase 6 — Hand off

```
mx-flow complete.

Next steps:
  git push
  Open PR following your team's PR template
  After merge: /mx-finish <name>
```

Do not push automatically.
