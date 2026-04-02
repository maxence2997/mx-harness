# review-pr-comments

Systematic triage and response workflow for unresponded PR review comments.

1. Fetches all unresponded comments on a PR
2. Classifies each by severity (P0-P3), category, and file location
3. Assesses implementation cost, risk, and change scope
4. Sorts into action buckets: fix now / track for later / skip
5. Presents an interactive triage report for approval
6. Executes approved decisions with standardized PR responses

## Notes

- Supports both GitHub (`gh`) and GitLab (`glab`) platforms
- For private repos, authenticate with `gh auth login` or `glab auth login` before use
