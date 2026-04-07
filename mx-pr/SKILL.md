---
name: mx-pr
description: >
  Draft a pull request from the feature spec and git log, let the user review and edit,
  then publish to the chosen platform (GitHub, GitLab, Bitbucket) — or skip publishing.
  Draft is written to a timestamped temp file to avoid filename collisions.
  Use after mx-verify passes and the branch is pushed.
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
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

Find related issues by checking in this order:
1. Branch name — extract any issue number (e.g. `fix/123-timeout` → `#123`)
2. Commit messages since branch start — look for `#<number>`, `closes`, `fixes`, `resolves`
3. Open issues list — match by title keywords against the feature name:
```bash
gh issue list --state open --limit 20 2>/dev/null || true
```

Collect all candidate issue references. If ambiguous, include all candidates and let the user trim during review.

---

## Step 2 — Write draft to temp file

Read `references/pr-template.md` (located in the same directory as this SKILL.md).
It defines the PR sections and how each placeholder maps to a source.

Fill each placeholder using the context gathered in Step 1:

| Placeholder | Source |
|-------------|--------|
| `{{summary}}` | spec.md — What and How (2-4 bullet points) |
| `{{motivation}}` | spec.md — Why (one paragraph) |
| `{{changes}}` | git log, grouped by commit type |
| `{{test_plan}}` | completed tasks from plan.md |
| `{{notes}}` | spec.md — Out of scope, known trade-offs; omit if empty |
| `{{issues}}` | Related issues found in Step 1 — use `Closes #N` if this PR resolves the issue, `Relates to #N` if partial; omit section if none found |

If spec.md does not exist, derive `{{summary}}`, `{{motivation}}`, and `{{notes}}` from the git log only.
Remove any section whose content is empty and marked optional in the template.

Create `MX/<name>/tmp/` if it does not exist.
Generate draft path: `MX/<name>/tmp/pr-draft-<YYYYMMDD-HHmmss>.md` using the current timestamp.
Write the filled template to the draft file.

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
  [1] GitHub      (gh pr create)
  [2] GitLab      (glab mr create)
  [3] Bitbucket   (bb pr create — requires bb CLI)
  [4] Hand off    (show draft path, you push and open the PR yourself)
  [5] Skip        (do nothing — branch stays local, come back later)
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

- PR format is defined in `references/pr-template.md` — customize it to match your team's conventions
- Title is derived from the first bullet of `{{summary}}` — keep it under 72 characters
- If spec.md does not exist, all content is derived from the git log
- Draft files live in `MX/<name>/tmp/` — under home directory, no repo permissions or gitignore needed
- The timestamp suffix prevents collisions if mx-pr is run multiple times for the same feature
