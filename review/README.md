# review

Multi-perspective code review using three AI review agents (Senior Engineer, SRE Guardian, Future Maintainer) synthesized by a Tech Lead into one final report.

## How it works

1. Parses git diff or reads files directly
2. Detects programming languages from file extensions
3. Runs three independent review perspectives (parallel when possible)
4. Tech Lead synthesizes findings — deduplicates, resolves conflicts, filters noise
5. Presents interactive report for review
6. Saves report to `/tmp/review-reports/`

## Modes

**Diff mode** (default):
```
/review                    # staged changes
/review HEAD~3             # last 3 commits
/review main..HEAD         # branch diff
/review abc..def           # commit range
```

**Repo mode**:
```
/review --repo src/service/          # entire directory
/review --repo src/service/order.go  # specific file
```

## Supported languages

- Go (`.go`)
- C# .NET 8 (`.cs`)

Extensible via `references/_template.md`.
