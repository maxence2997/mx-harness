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
