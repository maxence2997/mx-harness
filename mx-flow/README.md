# mx-flow

Full development workflow orchestrator. One command to run the entire process from idea to verified, committable code.

## Usage

```
/mx-flow <topic>
/mx-flow
```

## What it runs

```
mx-brainstorm  →  [GATE: spec approval]
mx-plan        →  [GATE: task list approval]
mx-worktree
  loop:
    mx-tdd → mx-commit (per task)
    mx-team-review → mx-review-triage  →  [GATE: triage approval]
    → fixes? back to loop
    → clean? exit loop
mx-verify → mx-commit
```

## Three human gates

| Gate | When | What you do |
|------|------|-------------|
| Spec approval | After brainstorm | Review and confirm the design |
| Task list approval | After planning | Add, remove, or reorder tasks |
| Triage approval | After each review cycle | Approve fix/track/skip decisions |

Between gates, mx-flow runs automatically.

## Convergent loop safety limit

The tdd → review → triage cycle runs a maximum of **3 iterations**. If findings are still unresolved after 3 rounds, mx-flow escalates and presents three options:

- **Continue** — extend the loop manually
- **Redesign** — return to the spec; the findings indicate a design problem
- **Abort** — discard the branch and start fresh

Three unresolved iterations almost always signal a design issue, not a code issue.

## Individual skills

Each skill in the flow can also be used standalone:

| Skill | Use when |
|-------|----------|
| `/mx-brainstorm` | Just need a spec, not the full flow |
| `/mx-plan` | Already have a spec, need tasks |
| `/mx-worktree` | Need an isolated workspace |
| `/mx-tdd` | Already planned, working task by task |
| `/mx-team-review` | Want a code review at any point |
| `/mx-review-triage` | Have review findings to triage |
| `/mx-verify` | Final check before commit |
| `/mx-commit` | Structured commit message |
| `/mx-finish` | Clean up after PR is merged |

## Notes

- Does not push automatically — you control when to push and open the PR
- After merge: run `/mx-finish <name>` to clean up
