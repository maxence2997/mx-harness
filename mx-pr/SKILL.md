---
name: mx-pr
description: >
  Draft a pull request from the feature spec and git log, let the user review and edit,
  then publish to the chosen platform (GitHub, GitLab, Bitbucket) — or skip publishing.
  Draft is written to a timestamped temp file to avoid filename collisions.
  Before pushing, runs a mandatory squash check on local commits to reduce PR noise.
  Use after mx-verify passes — branch does not need to be pushed yet.
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-pr
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-pr

## Path resolution

Resolve two base directories before any file operation:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$REPO_ROOT")
```

| Variable | Path | Used for |
|----------|------|----------|
| `GLOBAL_MX` | `~/.mx/<project>/<name>/` | Reading spec.md (permanent) |
| `LOCAL_MX` | `<repo-root>/.mx/<name>/` | Writing PR drafts to tmp/ (ephemeral) |

---

## Trigger

```
/mx-pr <name>   ← draft PR for named feature
/mx-pr          ← infer from active spec or ask
```

---

## Step 1 — Gather context

Read `GLOBAL_MX/spec.md` (`~/.mx/<project>/<name>/spec.md`) for the What/Why/How summary.

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

## Step 2 — Check for squashable commits (mandatory)

This check is **required** — never skip it. It runs every time before drafting the PR,
so the cleaned-up commit history feeds into the PR body and lands cleanly on the remote.

List every commit since the branch diverged from base:

```bash
git log $(git merge-base HEAD main)..HEAD --pretty=format:'%h %s'
```

Flag a commit as a squash candidate if its subject matches any of these patterns:

- Starts with `fixup!` or `squash!` (autosquash markers)
- Mentions `wip`, `tmp`, `temp`, `debug`, `nit`, `typo`, `oops`
- Mentions `address review`, `address feedback`, `PR feedback`, `code review`, `review comments`
- Is a near-duplicate of an earlier commit's subject (same scope + verb)
- Touches only files already changed in an earlier commit on the branch AND has a vague subject (`update`, `fix`, `more changes`)

Group candidates with the parent commit they logically belong to. Present the plan:

```
Squash check — found <N> candidate(s):

  abc123 feat: add cache layer
    ↳ def456 fix typo          ← squash into abc123
    ↳ 789abc address review    ← squash into abc123

  ghi012 refactor: extract handler
    ↳ jkl345 wip               ← squash into ghi012

Options:
  [A] Squash as proposed         (runs git rebase with autosquash)
  [B] Let me edit the plan       (opens interactive rebase — you decide)
  [C] Keep all commits as-is     (confirm: these commits add signal, not noise)
```

If **no candidates** are detected, still report the check ran and proceed:

```
Squash check — no candidates detected across <N> commits. Proceeding.
```

Wait for the user to choose before continuing. Never rewrite history without explicit approval.

### If [A] — perform the squash

For each candidate, amend its subject to `fixup! <parent-subject>` (or `squash!` if the body matters),
then run autosquash:

```bash
git commit --fixup=<parent-sha> ...    # only needed if creating new fixup commits
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash $(git merge-base HEAD main)
```

In practice, since the candidates already exist as regular commits, rewrite their subjects in place
via `git rebase -i` with a non-interactive sequence editor that reorders and marks them as `fixup`.
Confirm the rewrite succeeded with `git log --oneline` before moving on. If the rebase fails (conflicts,
detached HEAD, etc.), abort with `git rebase --abort` and fall back to option [B].

### If [B] — hand off to interactive rebase

```bash
git rebase -i $(git merge-base HEAD main)
```

Tell the user to finish the rebase, then re-run `/mx-pr`.

### If [C] — record the override

Note in the conversation that the user confirmed all commits add signal. Proceed to Step 3.

---

## Step 3 — Write draft to temp file

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

Create `LOCAL_MX/tmp/` (`.mx/<name>/tmp/`) if it does not exist.
Generate draft path: `.mx/<name>/tmp/pr-draft-<YYYYMMDD-HHmmss>.md` using the current timestamp.
Write the filled template to the draft file.

---

## Step 4 — Show draft and ask for review

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

If the user runs /mx-pr again and a draft file exists under `.mx/<name>/tmp/`
(within 24h), offer to reuse it instead of regenerating.

---

## Step 5 — Select platform

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

## Step 6 — Push and publish

Before invoking the platform CLI, make sure the (possibly rewritten) branch is on the remote:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
  # branch exists on remote — force-with-lease only if Step 2 rewrote history
  git push --force-with-lease origin "$BRANCH"
else
  git push -u origin "$BRANCH"
fi
```

Use `--force-with-lease` (never plain `--force`) so a concurrent update on the remote aborts the push
instead of clobbering someone else's work. If push fails, surface the error and stop — do not retry blindly.

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

## Step 7 — Report

```
PR created: <url>          ← if published
Draft kept at: $DRAFT

Next: after merge, run /mx-flow finish <name> (will clean up .mx/<name>/tmp/)
```

Do not delete the draft file here. `/mx-flow finish` handles all `.mx/<name>/tmp/` cleanup.

---

## Notes

- PR format is defined in `references/pr-template.md` — customize it to match your team's conventions
- Title is derived from the first bullet of `{{summary}}` — keep it under 72 characters
- If spec.md does not exist, all content is derived from the git log
- Draft files live in `.mx/<name>/tmp/` — project-local, gitignored
- The timestamp suffix prevents collisions if mx-pr is run multiple times for the same feature
