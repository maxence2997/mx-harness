# mx-finish

Clean up after a feature branch is merged.

Deletes the plan file, preserves the spec, clears related review reports from `/tmp`, and gives you the exact commands to remove the worktree and branch.

## Usage

```
/mx-finish <name>   # clean up named feature
/mx-finish          # find completed plan or ask
```

## What it does

| Action | Detail |
|--------|--------|
| Delete plan | `.mx/plan/<name>.md` — no value after tasks complete |
| Preserve spec | `.mx/design/<name>.md` — kept permanently |
| Clear reports | `/tmp/review-reports/` related files — asks before deleting |
| Remind worktree | Prints commands, does not auto-delete |

## Notes

- Confirm PR is merged before running
- Worktree and branch cleanup is manual (to avoid accidental deletion)
- Run from the main branch, not from inside the worktree
