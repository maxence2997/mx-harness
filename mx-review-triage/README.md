# mx-review-triage

Triage review findings and decide what to fix, track, or skip.

Works with two sources:
- **Local review** — output from `/mx-team-review` (use after a local code review)
- **PR comments** — unresponded comments on a GitHub or GitLab PR/MR

The triage logic is identical for both sources: assess validity, severity, and cost, then classify into fix / track / skip buckets. Present the report for approval before executing anything.

## Usage

```
/mx-review-triage                       # auto-detect source
/mx-review-triage --source review       # local mx-team-review report
/mx-review-triage --source pr 42        # GitHub/GitLab PR by number
/mx-review-triage --source pr <url>     # PR by URL
```

## Action buckets

| Bucket | When |
|--------|------|
| **Fix now** | P0 always; high risk + low/medium cost |
| **Track** | Medium risk, deferred; added to `TODOS.md` |
| **Skip** | Low risk, false positive, or nitpick |

## Severity levels

Defined in `references/SEVERITY.md` — customize to match your team's priorities.

## Notes

- Never makes code changes or posts PR replies without user approval
- `--source pr` mode: zero unaddressed comments is a hard gate before merge
- Auto-detect only runs when invoked directly — mx-flow always uses `--source review`
- Supports both GitHub (`gh`) and GitLab (`glab`) — authenticate before use
