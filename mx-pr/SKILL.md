---
name: mx-pr
description: >
  Draft a pull request from the feature spec and git log, run an autonomous
  commit-history cleanup (content check), then publish to GitHub, GitLab, or
  Bitbucket — or hand off. Use when a feature branch is ready for PR, standalone
  or from mx-flow. Usage: /mx-pr [name]
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-pr
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# mx-pr

## Trigger

```
/mx-pr <name>   ← draft PR for named feature
/mx-pr          ← infer from active spec or ask
```

## Orchestrated mode

This skill has interactive pauses (Steps 4 and 5). **When invoked from an
orchestrator that declares auto-proceed for its PR gate (e.g. mx-flow
GATE 4), the orchestrator's gate table overrides those pauses**: still
display everything you would have shown, but proceed without waiting —
pause only if you cannot determine how to proceed (no remote, ambiguous
platform, missing credentials). When invoked directly by the user, the
pauses apply as written.

Because auto-proceed removes the human review of the draft, add one check
in its place: if a subagent tool (Agent/Task) is available, spawn a fresh
read-back agent on the draft before Step 6 — criteria: every factual claim
traces to spec.md or the git log; every referenced issue number exists.
Fix findings before pushing. If no subagent tool exists, re-check the
draft yourself against those criteria and label the result "self-checked,
single-context" in the output.

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

## Step 1 — Gather context

Read `GLOBAL_MX/spec.md` (`~/.mx/<project>/<name>/spec.md`) for the
What/Why/How summary.

Resolve the base branch once — every later step uses this value (the log
below, the content check in Step 2, and the PR target in Step 6):

```bash
if git rev-parse --verify --quiet develop >/dev/null || git rev-parse --verify --quiet origin/develop >/dev/null; then
  BASE_BRANCH=develop
elif git rev-parse --verify --quiet main >/dev/null || git rev-parse --verify --quiet origin/main >/dev/null; then
  BASE_BRANCH=main
else
  BASE_BRANCH=""   # neither exists — ask the user, do not guess
fi
```

If invoked from an orchestrator that already resolved a base branch (e.g.
mx-flow Phase 4.2), use that value instead.

Get the git log since the branch diverged from the base branch:

```bash
git log $(git merge-base HEAD "$BASE_BRANCH")..HEAD --oneline
```

Get the diff summary:

```bash
git diff $(git merge-base HEAD "$BASE_BRANCH")..HEAD --stat
```

Find related issues by checking in this order:
1. Branch name — extract any issue number (e.g. `fix/123-timeout` → `#123`)
2. Commit messages since branch start — look for `#<number>`, `closes`,
   `fixes`, `resolves`
3. Open issues list — match by title keywords against the feature name:
```bash
gh issue list --state open --limit 20 2>/dev/null || true
```

Collect all candidate issue references. If ambiguous, include all
candidates and let the user trim during review.

---

## Step 2 — Autonomous content check (mandatory)

This check is **required** — never skip it. It runs every time before
drafting the PR, so the cleaned-up commit history feeds the PR body and
lands cleanly on the remote. mx-flow's Phase 6.5 may have already run it,
but mx-pr can be invoked standalone, so it runs unconditionally here; after
a prior run the typical outcome is a no-op.

In brief: two autonomous passes — **Pass 1** removes net-zero churn
(commits/hunks that cancel each other out on the branch), **Pass 2** folds
small fixup commits into their logical parent. Each pass is guarded by a
tree-hash invariant: if the working tree changes at all, that pass reverts
itself. No user prompt.

**Execute the full canonical procedure**: read and follow
`${CLAUDE_SKILL_DIR}/references/content-check.md` (the `references/`
directory sits next to this SKILL.md). If that file is missing, tell the
user the content check is unavailable in this install and continue to
Step 3 **without** rewriting any history — never improvise a history
rewrite from the summary above.

Use `$BASE_BRANCH` from Step 1 as the procedure's `<base-branch>`.

---

## Step 3 — Write draft to temp file

Read `references/pr-template.md` (located in the same directory as this
SKILL.md). It defines the PR sections and how each placeholder maps to a
source.

Fill each placeholder using the context gathered in Step 1:

| Placeholder | Source |
|-------------|--------|
| `{{summary}}` | spec.md — What and How (2-4 bullet points) |
| `{{motivation}}` | spec.md — Why (one paragraph) |
| `{{changes}}` | git log, grouped by commit type |
| `{{test_plan}}` | completed tasks from plan.md |
| `{{notes}}` | spec.md — Out of scope, known trade-offs; omit if empty |
| `{{issues}}` | Related issues found in Step 1 — use `Closes #N` if this PR resolves the issue, `Relates to #N` if partial; omit section if none found |

If spec.md does not exist, derive `{{summary}}`, `{{motivation}}`, and
`{{notes}}` from the git log only.
Remove any section whose content is empty and marked optional in the
template.

Create `LOCAL_MX/tmp/` (`.mx/<name>/tmp/`) if it does not exist.
Generate draft path: `.mx/<name>/tmp/pr-draft-<YYYYMMDD-HHmmss>.md` using
the current timestamp.
Write the filled template to the draft file.

---

## Step 4 — Show draft and ask for review

Display the full draft content inline.

Then present two options (subject to Orchestrated mode above):

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

If the user runs /mx-pr again and a draft file exists under
`.mx/<name>/tmp/` (within 24h), offer to reuse it instead of regenerating.

---

## Step 5 — Select platform

Ask the user which platform to publish to (subject to Orchestrated mode —
an orchestrator picks from the repo's remote automatically):

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

Before invoking the platform CLI, make sure the (possibly rewritten)
branch is on the remote:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
  # branch exists on remote — force-with-lease only if Step 2 rewrote history
  git push --force-with-lease origin "$BRANCH"
else
  git push -u origin "$BRANCH"
fi
```

Use `--force-with-lease` (never plain `--force`) so a concurrent update on
the remote aborts the push instead of clobbering someone else's work. If
push fails, surface the error and stop — do not retry blindly.

### GitHub

```bash
gh pr create \
  --title "<title from first Summary bullet>" \
  --body "$(cat $DRAFT)" \
  --base "$BASE_BRANCH"
```

### GitLab

```bash
glab mr create \
  --title "<title>" \
  --description "$(cat $DRAFT)" \
  --target-branch "$BASE_BRANCH"
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

Do not delete the draft file here. `/mx-flow finish` handles all
`.mx/<name>/tmp/` cleanup.

---

## Notes

- PR format is defined in `references/pr-template.md` — customize it to
  match your team's conventions
- Title is derived from the first bullet of `{{summary}}` — keep it under
  72 characters
- If spec.md does not exist, all content is derived from the git log
- Draft files live in `.mx/<name>/tmp/` — project-local, gitignored
- The timestamp suffix prevents collisions if mx-pr is run multiple times
  for the same feature
