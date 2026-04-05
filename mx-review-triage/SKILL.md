---
name: mx-review-triage
description: >
  Triage review findings from two sources: local mx-team-review reports (--source review)
  or GitHub/GitLab PR comments (--source pr <id|url>). Classifies each finding by
  validity, severity (P0-P3), and implementation cost, then sorts into fix / track / skip
  buckets. Presents report for user approval before executing any changes.
  When invoked without arguments, auto-detects the source or asks the user.
  Use after mx-team-review, or when handling PR feedback before merge.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-review-triage

## Trigger

```
/mx-review-triage                       ← auto-detect source
/mx-review-triage --source review       ← local mx-team-review report
/mx-review-triage --source pr <id|url>  ← GitHub / GitLab PR comments
```

---

## Step 1 — Determine source

### If `--source review`
Find the most recent review report:
1. Resolve MX directory, then check `MX/*/tmp/review-*.md` (active feature path)
2. Fall back to `/tmp/review-reports/` (Unix) or `%TEMP%\review-reports\` (Windows)

Pick the file with the latest modification time across both locations.
If no report exists in either location, report the error and stop.

### If `--source pr <id|url>`
Detect the platform from the repo's remote URL:
- **GitHub**: `gh api` to fetch review comments and issue comments
- **GitLab**: `glab api` to fetch MR discussions and notes

Filter out:
- Comments already replied to by the PR author
- Bot-generated summary comments (e.g. Copilot review overview)
- Individual line comments from bots MUST still be evaluated

If zero unresponded comments remain, report "No unresponded comments." and stop.

### If no argument (direct invocation only)

Auto-detect in this order:
1. `MX/*/tmp/review-*.md` or the OS temp review-reports directory has a file modified within the last hour → suggest `--source review`
2. Current branch has an open PR (`gh pr view` or `glab mr view` succeeds) → suggest `--source pr`
3. Both available → ask user which source to use
4. Neither available → ask user

> When invoked by mx-flow, always use `--source review` directly — skip this step.

---

## Step 2 — Parse findings

For each finding, extract:
- **Location**: file and line (or `—` if not applicable)
- **Category**: bug, correctness, design, security, performance, style/nitpick, question, suggestion
- **Severity**: classify using `references/SEVERITY.md`

---

## Step 3 — Triage each finding

Read the referenced code and assess every finding on three dimensions:

| Dimension | Evaluate |
|-----------|----------|
| **Validity** | Is the observation factually correct? Does it apply to the current code? |
| **Implementation cost** | Low (< 10 lines, single file) / Medium (multiple files, needs testing) / High (architectural, risky) |
| **Risk of not fixing** | What breaks or degrades if ignored? P0 items cannot be skipped. |

---

## Step 4 — Classify into action buckets

| Bucket | Criteria |
|--------|----------|
| **Fix now** | High risk + low/medium cost. P0 always here. Bug, security, correctness, data loss. |
| **Track** | Medium risk + needs design, or medium cost + not blocking. Add to `TODOS.md`. |
| **Skip** | Low risk + high cost, false positive, nitpick, or already handled elsewhere. |

---

## Step 5 — Present report

Show the full triage table, sorted by bucket then severity:

```
| # | Bucket   | Sev | Location        | Finding (summary)             | Cost | Recommended action        |
|---|----------|-----|-----------------|-------------------------------|------|---------------------------|
| 1 | Fix now  | P0  | client.go:42    | nil check missing             | Low  | Add nil guard             |
| 2 | Fix now  | P1  | handler.go:118  | error swallowed silently      | Low  | Propagate error           |
| 3 | Track    | P1  | options.go:88   | timeout should be configurable| Med  | Track in TODOS.md         |
| 4 | Skip     | P3  | client.go:15    | rename variable               | Low  | Won't fix: name idiomatic |
```

Briefly explain any non-obvious triage decisions after the table.

**Do not make any code changes yet.** Wait for user approval.

---

## Step 6 — Execute approved decisions

After user reviews and approves (adjusting bucket assignments as needed):

**Fix now** — make the code change, then:
- `--source review`: commit with `/mx-commit`
- `--source pr`: commit then reply on the PR/MR:
  `Fixed in {hash}. {what changed and why}`

**Track** — add entry to repo root `TODOS.md` with context, then:
- `--source pr`: reply `Tracked in TODOS.md — {reason}`

**Skip (won't fix)**:
- `--source pr`: reply `Won't fix. {clear reasoning}`

**Skip (not applicable)**:
- `--source pr`: reply `Not applicable — {explanation}`

Duplicate or related findings may reference each other: `Same reasoning as #{N} above — {brief}`.

---

## Step 7 — Final check

- `--source review`: report findings resolved. If fixes were made, note which commits.
- `--source pr`: verify zero unresponded comments remain. This is a hard gate before merge.
