# Phase 8 — Finish (post-merge cleanup, mx-flow)

> Read this when triggered by `/mx-flow finish <name>`. This phase runs
> independently from the main pipeline.

## 8.1 — Confirm the PR is merged

Ask the user to confirm the PR is merged before proceeding.
If running from within a worktree, remind the user to switch back to the
main branch first — worktree removal must be run from outside the worktree.

## 8.2 — Delete the plan and scope files

```bash
rm -f .mx/<name>/plan.md .mx/<name>/scope.yaml
```

Both files describe in-flight work — they have no value after all tasks
are done. Report: `Deleted .mx/<name>/plan.md and scope.yaml`

## 8.3 — Preserve design spec and ADRs

Do **not** delete `~/.mx/<project>/<name>/spec.md` or
`~/.mx/<project>/<name>/adr.md`. The design spec records what was built,
the ADRs record why — both have lasting documentation value.

Report: `Kept ~/.mx/<project>/<name>/spec.md and adr.md (preserved)`

## 8.4 — Clean up temp files

List all files in `.mx/<name>/tmp/` with timestamps:

```bash
ls -lt .mx/<name>/tmp/ 2>/dev/null
```

Show the list to the user and ask which to delete. Delete the selected
ones. If `.mx/<name>/tmp/` is empty after deletion, remove the directory.

## 8.5 — Remove the worktree

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

## 8.6 — Delete the branch

```bash
git branch -d <branch-name>
```

`-d` (not `-D`) is intentional — git refuses to delete an unmerged branch,
which acts as a safety net.

**If git refuses** (branch not fully merged):

```
Branch deletion failed — git reports the branch is not fully merged.

If the PR was squash-merged or rebased, the branch may look unmerged to git.
To force delete:
  git branch -D <branch-name>
```

Do not force-delete automatically. Wait for the user to confirm.

## 8.7 — Clean up local .mx directory

If `.mx/<name>/` is now empty, remove it:
```bash
rmdir .mx/<name>/ 2>/dev/null
```

## 8.8 — Summary

```
Finished <name>:
  ✓ Plan and scope deleted (.mx/<name>/plan.md, scope.yaml)
  ✓ Design spec and ADRs preserved at ~/.mx/<project>/<name>/
  ✓ Temp files cleared (.mx/<name>/tmp/)
  ✓ Worktree removed
  ✓ Branch deleted
```

If any step was skipped due to a safety refusal, mark it with `○` and note
what remains.
