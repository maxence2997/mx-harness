---
name: mx-pr-triage
description: Triage and respond to unresponded PR review comments. Fetches comments, classifies severity (P0-P3), assesses implementation cost and risk, sorts into action buckets (fix now / track / skip), presents interactive report for approval, then executes approved decisions with standardized responses. Use when handling PR feedback, reviewing comments, or preparing to merge a PR with unresolved comments.
---

# Review PR Comments

Systematic triage and response workflow for unresponded pull request (or merge request) comments. Takes a PR/MR number or URL as argument. Works with both GitHub and GitLab.

## 1. Fetch comments

Detect the platform from the repo's remote URL. Use the appropriate CLI to pull all comments:
- **GitHub**: `gh api` to fetch review comments and issue comments
- **GitLab**: `glab api` to fetch MR discussions and notes

Filter out:
- Comments already replied to by the PR author
- Bot-generated summary comments (e.g. Copilot review overview, dependency bot summaries)
- Individual line comments from bots MUST still be evaluated

If zero unresponded comments remain, report "No unresponded comments." and stop.

## 2. Parse each comment

For each unresponded comment, extract:
- **Author** and timestamp
- **File and line** (for review comments)
- **Category**: bug, correctness, design, security, performance, style/nitpick, question, suggestion
- **Severity**: classify according to the definitions in `references/SEVERITY.md`

## 3. Triage each comment

For every comment, read the referenced code and assess:

| Dimension | Evaluate |
|-----------|----------|
| **Validity** | Is the observation factually correct? Does it apply to the current code? |
| **Implementation cost** | Low (< 10 lines, single file), Medium (multiple files, needs testing), High (architectural change, risky) |
| **Risk of not fixing** | What breaks or degrades if ignored? P0 items cannot be skipped. |
| **Change scope** | Which files, how many lines, does it require new tests? |

## 4. Classify into action buckets

Based on the triage, assign each comment to one of three buckets:

### Fix now
High risk + low/medium cost. **P0 items always go here.**
- Bug fixes, security issues, correctness problems, data loss risks
- Quick wins that improve quality with minimal effort

### Track for later
Medium risk + needs design, or medium cost + not blocking release.
- Design improvements, refactoring suggestions, non-critical enhancements
- Will be added to `TODOS.md` with context and link to the comment

### Skip
Low risk + high cost, false positive, or stylistic preference.
- Nitpicks that don't improve correctness or readability
- Suggestions based on incorrect assumptions about the code
- Already handled elsewhere or duplicates of other comments

## 5. Present report

Show the full triage report as a table, sorted by bucket then severity:

```
| # | Bucket    | Sev | File:Line          | Comment (summary)            | Cost | Risk    | Recommended action          |
|---|-----------|-----|--------------------|------------------------------|------|---------|-----------------------------|
| 1 | Fix now   | P0  | client.go:42       | nil check missing            | Low  | crash   | Fix: add nil guard          |
| 2 | Fix now   | P1  | handler.go:118     | error swallowed silently     | Low  | corrupt | Fix: propagate error        |
| 3 | Track     | P1  | options.go:88      | timeout should be configurable| Med | usability| Track in TODOS.md          |
| 4 | Skip      | P3  | client.go:15       | rename variable              | Low  | none    | Won't fix: name is idiomatic|
```

After the table, briefly explain any non-obvious triage decisions.

**Do not make any code changes or reply to comments yet.** Wait for user approval.

## 6. Execute approved decisions

After user reviews and approves (possibly adjusting bucket assignments), execute each:

- **Fix now**: make the code change, commit, then reply on the PR/MR:
  `Fixed in {commit-hash}. {what changed and why}`

- **Track**: add entry to repo root `TODOS.md` with context and comment link, then reply:
  `Tracked in TODOS.md — {reason for deferring}`

- **Skip (won't fix)**: reply on the PR/MR:
  `Won't fix. {clear reasoning}`

- **Skip (not applicable)**: reply on the PR/MR:
  `Not applicable — {explanation}`

Duplicate or related comments may reference each other: `Same reasoning as #{N} above — {brief}`.

## 7. Final check

After all comments are addressed, verify zero unresponded comments remain on the PR/MR. Report the final count. The PR/MR must have zero unaddressed comments before merge — this is a hard gate.
