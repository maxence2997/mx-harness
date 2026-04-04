---
name: mx-finish
description: >
  Clean up after a feature branch is merged. Deletes the plan file, preserves the spec,
  clears related review reports, and reminds you to manually remove the worktree and branch.
  Use after the PR is merged.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
---

# mx-finish

## Trigger

```
/mx-finish <name>   ← clean up named feature
/mx-finish          ← find completed plan or ask
```

---

## Step 1 — Confirm the PR is merged

Ask the user to confirm the PR is merged before proceeding.
If running from within a worktree, note that and remind the user to switch back to the main branch first.

---

## Step 2 — Delete the plan file

```bash
rm .mx/plan/<name>.md
```

The plan has no value after all tasks are done. Report: `Deleted .mx/plan/<name>.md`

---

## Step 3 — Preserve the spec

Do **not** delete `.mx/design/<name>.md`.
The spec records what was built and why — it has lasting documentation value.

Report: `Kept .mx/design/<name>.md (spec preserved)`

---

## Step 4 — Clean up review reports

Find and remove review reports related to this feature from `/tmp/review-reports/`:

```bash
ls -t /tmp/review-reports/
```

Ask the user which reports to delete (show the list with timestamps).
Delete the selected ones.

---

## Step 5 — Remind: worktree and branch cleanup

Do **not** auto-delete the worktree or branch. Print the commands for the user to run:

```
Run these manually to complete cleanup:

  git worktree remove .worktrees/<branch-name>
  git branch -d <branch-name>

If the branch was force-merged or needs force-delete:
  git branch -D <branch-name>
```

---

## Step 6 — Summary

```
Cleanup complete for <name>:
  ✓ Plan deleted
  ✓ Spec preserved at .mx/design/<name>.md
  ✓ Review reports cleared
  ○ Worktree and branch: run the commands above manually
```
