# mx-finish

Complete the lifecycle of a merged feature branch in one command.

Deletes the plan, preserves the spec, clears review reports, removes the worktree, and deletes the branch. Git's own safety checks act as the safety net — it refuses to remove dirty worktrees or unmerged branches without explicit confirmation.

## Usage

```
/mx-finish <name>   # finish named feature
/mx-finish          # find completed plan or ask
```

## What it does

| Step | Action |
|------|--------|
| Plan | Deleted — no value after all tasks complete |
| Spec | Preserved — `.mx/design/<name>.md` kept permanently |
| Review reports | Cleared from `/tmp/review-reports/` (asks before deleting) |
| Worktree | `git worktree remove .worktrees/<branch>` — stops if dirty |
| Branch | `git branch -d <branch>` — stops if not fully merged |

## Safety behaviour

- **Dirty worktree**: git refuses to remove — presents force-remove option, waits for user
- **Unmerged branch**: git refuses `-d` — presents `-D` option, waits for user
- Nothing is force-deleted automatically

## Notes

- Run from the main branch, not from inside the worktree
- Confirm the PR is merged before running
- Squash-merge or rebase workflows may require `git branch -D` — mx-finish will prompt if needed
