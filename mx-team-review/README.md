# mx-team-review

Multi-perspective code review using three AI review agents (Senior Engineer, SRE Guardian, Future Maintainer) synthesized by a Tech Lead into one final report.

## How it works

1. Parses git diff or reads files directly
2. Detects programming languages from file extensions
3. Runs three independent review perspectives (parallel when possible)
4. Tech Lead synthesizes findings — deduplicates, resolves conflicts, filters noise
5. Presents interactive report for review
6. Saves report to `.mx/<name>/tmp/` (or `/tmp/review-reports/` if no active feature)

## Modes

**Diff mode** (default):
```
/mx-team-review                    # staged changes
/mx-team-review HEAD~3             # last 3 commits
/mx-team-review main..HEAD         # branch diff
/mx-team-review abc..def           # commit range
```

**Repo mode**:
```
/mx-team-review --repo src/service/          # entire directory
/mx-team-review --repo src/service/order.go  # specific file
```

## Supported languages

- Go (`.go`)
- C# .NET 8 (`.cs`)

Extensible via `references/_template.md`.

## In the workflow

Use after completing a milestone in the TDD phase, before `/mx-review-triage`:

```
TDD (tasks done) → mx-team-review → mx-review-triage --source review
```

The report is saved to `.mx/<name>/tmp/` and automatically picked up by `/mx-review-triage --source review`.
