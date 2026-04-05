---
name: mx-pr
description: >
  Draft a pull request from the feature spec and git log, let the user review and edit,
  then publish to the chosen platform (GitHub, GitLab, Bitbucket) — or skip publishing.
  Draft is written to a timestamped temp file to avoid filename collisions.
  Use after mx-verify passes and the branch is pushed.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-pr

## Path resolution

Resolve MX base directory before any file operation:
- Final path component of `git rev-parse --show-toplevel` = `<project>`
- MX = `~/.mx/<project>/` (Unix/macOS) or `%USERPROFILE%\.mx\<project>\` (Windows)

---

## Trigger

```
/mx-pr <name>   ← draft PR for named feature
/mx-pr          ← infer from active spec or ask
```

---

## Step 1 — Gather context

Read `~/.mx/<project>/<name>/spec.md` for the What/Why/How summary.

Get the git log since the branch diverged from the base branch:

```bash
git log $(git merge-base HEAD main)..HEAD --oneline
```

Get the diff summary:

```bash
git diff $(git merge-base HEAD main)..HEAD --stat
```

Check for open issues that may be referenced:

```bash
gh issue list --state open --limit 10 2>/dev/null || true
```

---

## Step 2 — Write draft to temp file

Create `MX/<name>/tmp/` if it does not exist.
Generate draft path: `MX/<name>/tmp/pr-draft-<YYYYMMDD-HHmmss>.md` using the current timestamp.

Write the draft PR in this format:

```markdown
## Summary

<2-4 bullet points drawn from the spec's What and How sections>

## Motivation

<One paragraph from the spec's Why section>

## Changes

<Bullet list derived from the git log — group by commit type if helpful>

## Test plan

<What was tested, based on the tasks in ~/.mx/<project>/<name>/plan.md>

## Notes

<Optional: migration steps, config changes, follow-ups, known trade-offs>
```

Save to `$DRAFT`.

---

## Step 3 — Show draft and ask for review

Display the full draft content inline.

Then present two options:

```
Draft saved to: $DRAFT

Options:
  [A] Looks good — proceed to platform selection
  [B] Edit first — open the draft file, make changes, then re-run /mx-pr
```

Wait for the user to choose. Do not proceed automatically.

If the user chooses [B], remind them:
```
Edit $DRAFT, then run /mx-pr again — it will detect the existing draft.
```

If the user runs /mx-pr again and a draft file exists under `~/.mx/<project>/<name>/tmp/`
(within 24h), offer to reuse it instead of regenerating.

---

## Step 4 — Select platform

Ask the user which platform to publish to:

```
Publish to:
  [1] GitHub   (gh pr create)
  [2] GitLab   (glab mr create)
  [3] Bitbucket (bb pr create — requires bb CLI)
  [4] Other    (show the draft, you handle it manually)
  [5] Skip     (don't publish now)
```

Wait for the user to choose.

---

## Step 5 — Publish

### GitHub

```bash
gh pr create \
  --title "<title from first Summary bullet>" \
  --body "$(cat $DRAFT)" \
  --base main
```

### GitLab

```bash
glab mr create \
  --title "<title>" \
  --description "$(cat $DRAFT)" \
  --target-branch main
```

### Bitbucket

```bash
bb pr create \
  --title "<title>" \
  --description "$(cat $DRAFT)"
```

### Other / Skip

Display the draft path and content for the user to use manually.

---

## Step 6 — Report

```
PR created: <url>          ← if published
Draft kept at: $DRAFT

Next: after merge, run /mx-finish <name> (will clean up ~/.mx/<project>/<name>/tmp/)
```

Do not delete the draft file here. mx-finish handles all `~/.mx/<project>/<name>/tmp/` cleanup.

---

## Notes

- Title is derived from the first Summary bullet — keep it under 72 characters
- If `~/.mx/<project>/<name>/spec.md` does not exist, derive content from git log only
- Draft files live in `~/.mx/<project>/<name>/tmp/` — under home directory, no repo permissions or gitignore needed
- The timestamp suffix prevents collisions if mx-pr is run multiple times for the same feature
