---
name: mx-finish
description: >
  Complete the lifecycle of a merged feature branch. Deletes the plan file, preserves
  the spec, clears related review reports, removes the worktree, and deletes the branch.
  Git's own safety checks prevent accidental deletion of dirty worktrees.
  Use after the PR is merged.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
---

# mx-finish

## Path resolution

Resolve MX base directory before any file operation:
- Final path component of `git rev-parse --show-toplevel` = `<project>`
- MX = `~/.mx/<project>/` (Unix/macOS) or `%USERPROFILE%\.mx\<project>\` (Windows)

---

## Trigger

```
/mx-finish <name>   ← finish named feature
/mx-finish          ← find completed plan or ask
```

---

## Step 1 — Confirm the PR is merged

Ask the user to confirm the PR is merged before proceeding.
If running from within a worktree, remind the user to switch back to the main branch first — worktree removal must be run from outside the worktree.

---

## Step 2 — Delete the plan file

```bash
rm ~/.mx/<project>/<name>/plan.md
```

The plan has no value after all tasks are done. Report: `Deleted ~/.mx/<project>/<name>/plan.md`

---

## Step 3 — Preserve design spec and ADRs

Do **not** delete `~/.mx/<project>/<name>/spec.md` or anything in `~/.mx/<project>/<name>/adr.md`.
The design spec records what was built, the ADRs record why — both have lasting documentation value.

Report: `Kept ~/.mx/<project>/<name>/spec.md (design spec) and ~/.mx/<project>/<name>/adr.md (preserved)`

---

## Step 4 — Clean up temp files

List all files in `~/.mx/<project>/<name>/tmp/` with timestamps:

```bash
ls -lt ~/.mx/<project>/<name>/tmp/ 2>/dev/null
```

Show the list to the user and ask which to delete. Delete the selected ones.
If `~/.mx/<project>/<name>/tmp/` is empty after deletion, remove the directory.

---

## Step 5 — Remove the worktree

```bash
git worktree remove .worktrees/<branch-name>
```

**If the command succeeds:** report `Worktree removed.`

**If git refuses** (uncommitted changes detected):

```
git worktree remove failed — the worktree has uncommitted changes.

Either:
  1. Go into .worktrees/<branch-name>, commit or discard changes, then re-run /mx-finish
  2. Force remove (loses uncommitted changes):
     git worktree remove --force .worktrees/<branch-name>
```

Do not force-remove automatically. Wait for the user to decide.

---

## Step 6 — Delete the branch

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

---

## Step 7 — Summary

```
Finished <name>:
  ✓ Plan deleted (~/.mx/<project>/<name>/plan.md)
  ✓ Design spec and ADRs preserved at ~/.mx/<project>/<name>/
  ✓ Temp files cleared (~/.mx/<project>/<name>/tmp/)
  ✓ Worktree removed
  ✓ Branch deleted
```

If any step was skipped due to a safety refusal, mark it with `○` and note what remains.
