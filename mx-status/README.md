# mx-status

Show the current stage, progress, and next action for features in the current project's `~/.mx/<project>/` directory. Use whenever you lose track of where you are in the mx-flow workflow.

## Usage

```
/mx-status              # show all features in current project
/mx-status <name>       # show one specific feature
```

## Output

```
mx-status — <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ● write-timeout-error-propagation  [ACTIVE] Stage 3 — TDD  4/7 tasks
  ✓ close-transport-drop-nil         PR created — /mx-finish to clean up
  ○ done-priority-check              Stage 1 — awaiting plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active: write-timeout-error-propagation
Next  : /mx-tdd  (task 5: wire handler into router)
```

## Stages

| Stage | Condition | Next action |
|-------|-----------|-------------|
| 0 — Nothing | No `spec.md` | `/mx-brainstorm <topic>` |
| 1 — Spec | `spec.md` exists, no `plan.md` | `/mx-plan` |
| 2 — Plan | `plan.md` exists, no `worktree/` | `/mx-worktree` |
| 3 — TDD | `worktree/` exists, tasks pending | `/mx-tdd` (names the next `[ ]` task) |
| 4 — Review | All tasks `[x]`, no review report | `/mx-team-review` |
| 5 — Triage | Review report exists, no PR | `/mx-review-triage --source review` then `/mx-verify` + `/mx-pr` |
| 6 — PR | PR URL found in `plan.md` | `/mx-finish <name>` (after merge) |

## Broken state detection

mx-status checks for three anomalies and gives recovery instructions when found:

| Anomaly | Likely cause | Recovery |
|---------|-------------|----------|
| Worktree dir referenced in plan but missing on disk | Worktree was removed or moved | Recreate with `/mx-worktree`, or proceed in main repo |
| All tasks `[x]` but worktree never existed | Work done directly in main repo | Fine if intentional — continue to `/mx-team-review` |
| Multiple features in progress | Parallel work or stale entries | Run `/mx-status <name>` to focus on one |

## Notes

- Resolves project name from `git rev-parse --show-toplevel`
- If run outside a git repo, lists all projects under `~/.mx/` and asks which to inspect
- Does not modify any files — read-only
