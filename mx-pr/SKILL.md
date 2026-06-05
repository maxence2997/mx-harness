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

## Step 2 — Autonomous content check (mandatory)

This check is **required** — never skip it. It runs every time before drafting the PR, so the cleaned-up commit history feeds the PR body and lands cleanly on the remote. It is also the final safety net: mx-flow's Phase 6 may have already done this check, but mx-pr can be invoked standalone, so this still runs unconditionally. After a prior Phase 6 run, the typical outcome here is a no-op.

Two passes run autonomously — no user prompt:

1. **Pass 1 — Cancellation cleanup**: net-zero churn on the branch. Full pair (`++A` in commit 1, `--A` in commit 4 → both drop). Partial (`++A,++B` in commit 1, `--B,++C` in commit 5 → net is `++A,++C`, so the `B`-related hunks come out of both commits).
2. **Pass 2 — Squash-into-parent**: small touch-ups that logically belong inside an earlier commit.

Safety comes from a tree-invariant check, not user confirmation: the working-tree hash before and after each pass MUST match. If they differ for any reason, revert that pass to its starting HEAD and continue. Each pass is its own transaction.

### 2.0 — Capture pre-state

```bash
PRE_HEAD=$(git rev-parse HEAD)
PRE_TREE=$(git rev-parse HEAD^{tree})
BASE=$(git merge-base HEAD <base-branch>)
```

`<base-branch>` is the PR's target branch — `develop` if it exists, otherwise `main`. Resolve with the same logic as mx-flow Phase 4.2.

### 2.1 — Pass 1: cancellation cleanup

Read every commit's diff in `BASE..HEAD` (`git show --format= <sha>`). Look for hunks that mutually cancel and remove them so they leave no trace in the PR.

#### Level 1 — Whole-commit inverse pairs (rule-based)

A pair (X, Y) with X earlier than Y qualifies if Y's diff is the exact reverse of X's diff — every `+line` in X appears as `-line` in Y in the same file and identical content, and vice versa, with the same hunk locations. No semantic judgment needed; this is mechanical.

For each qualifying pair, schedule both commits for **removal in entirety**. Multiple pairs can be processed together.

#### Level 2 — Partial cancellation (semantic judgment)

For cancelling hunks that are **not** part of a whole-commit inverse pair, the agent must judge content relatedness before acting. Textual cancellation alone is not sufficient — the cancelling lines might be two independent decisions that coincidentally touched the same code.

Identify candidate hunk groups: a `+lines` segment in commit X with a matching `-lines` segment (identical content) in a later commit Y on the branch.

For each candidate group, the agent reads the diffs, the surrounding code, and the commits in between, then judges relatedness. **All** of the following gates must hold; if any is uncertain, skip the group (default to keeping history fidelity):

- **File proximity**: cancelling hunks are in the same file, or in files that are clearly part of the same logical change (e.g., a struct and its test file).
- **Iteration continuity**: the commits between X and Y are part of the same iteration on this branch (e.g., review-triage adjustments), not work in an unrelated feature area.
- **Subject signals**: commit subjects on the iteration path suggest refinement (`fix`, `address review`, `adjust`, `refactor`, follow-up wording) rather than two independent decisions.
- **Local semantic relatedness**: the `+A` and `-A` occur in semantically related positions — same function, same block, related logic. Incidental coincidences (e.g., two unrelated commits both adding then removing a blank line) → reject.

If all gates pass, schedule the cancelling hunks for removal from X and from Y. Commits that become empty after hunk removal are dropped; commits with remaining content are rewritten with the cancelling hunks gone.

#### Execute Pass 1

If nothing was scheduled, log `Pass 1: no cancellation candidates` and skip to Pass 2.

Otherwise rewrite the branch. The mechanism is the agent's choice — `git format-patch` + edit + `git am`, or `git rebase --interactive` with per-commit edits, or `git commit-tree` reconstruction are all acceptable. The contract: produce a branch where the scheduled commits/hunks are gone and everything else is byte-identical.

A reference recipe using format-patch:

```bash
PATCHDIR=$(mktemp -d)
git format-patch "$BASE..HEAD" -o "$PATCHDIR"
# Drop fully-cancelled commits: rm "$PATCHDIR"/<seq>-*.patch
# For partial cancellation: edit the patch file to delete the cancelling hunks (keep the header)
git reset --hard "$BASE"
git am "$PATCHDIR"/*.patch    # empty patches are skipped automatically
rm -rf "$PATCHDIR"
```

#### Verify Pass 1 tree invariant

```bash
POST_TREE=$(git rev-parse HEAD^{tree})
```

`POST_TREE` MUST equal `PRE_TREE`. If they differ, the cleanup changed the working tree — revert:

```bash
git reset --hard "$PRE_HEAD"
```

If `git am` or rebase fails mid-flight (conflict, empty commit refusal, etc.), abort and revert:

```bash
git am --abort 2>/dev/null || git rebase --abort 2>/dev/null
git reset --hard "$PRE_HEAD"
```

Either failure mode → log `Pass 1 aborted (tree/rebase mismatch), cancellations kept as-is`. Continue to Pass 2 from `$PRE_HEAD`.

On success → update the baseline for Pass 2:

```bash
PRE_HEAD=$(git rev-parse HEAD)
# PRE_TREE must remain equal to the original PRE_TREE
```

### 2.2 — Pass 2: squash-into-parent

List commits with `git log $BASE..HEAD --pretty=format:'%h %s'` and inspect each diff with `git show --stat <sha>`.

Flag a commit as a squash candidate only if it meets **one** of these high-confidence signals AND points to exactly one parent commit on the branch. Ambiguous candidates are skipped silently.

**Subject signals**:
- Starts with `fixup!` or `squash!` (autosquash markers)
- Mentions `wip`, `tmp`, `temp`, `debug`, `nit`, `typo`, `oops`
- Mentions `address review`, `address feedback`, `PR feedback`, `code review`, `review comments`

**Diff signals**:
- Changed-files set is a subset of exactly one earlier commit's files AND the diff is small (≤ 20 lines added+removed combined)
- Touches the same function or hunk range as exactly one earlier commit on the branch (overlapping line ranges in the same file)

If a candidate matches multiple potential parents, skip it. Better to leave a noisy commit than to merge into the wrong parent.

If no candidates are found, log `Pass 2: no squash candidates` and skip to the report.

Otherwise rewrite each candidate's subject to `fixup! <parent-subject>` and run autosquash:

```bash
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash $BASE
```

Verify the tree invariant the same way as Pass 1. On any failure: `git rebase --abort 2>/dev/null && git reset --hard "$PRE_HEAD"`, log `Pass 2 aborted (tree/rebase mismatch), squashes kept as-is`, proceed.

### 2.3 — Report

```
Content check:
  Pass 1 (cancellation): <K1> commit(s) removed, <H1> hunk(s) trimmed   (or "no candidates" / "aborted")
  Pass 2 (squash):       <K2> commit(s) folded into <P> parent(s)        (or "no candidates" / "aborted")
  Tree unchanged. <N before> → <N after> commits on branch.
```

Proceed to Step 3.

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
