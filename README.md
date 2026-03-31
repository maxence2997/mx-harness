# Skills

Reusable AI coding agent skills for Claude Code, GitHub Copilot, Cursor, and other AI agents.

## Available Skills

### review-pr-comments

Systematic triage and response workflow for unresponded PR review comments.

**What it does:**
1. Fetches all unresponded comments on a PR
2. Classifies each by severity (P0-P3), category, and file location
3. Assesses implementation cost, risk, and change scope
4. Sorts into action buckets: fix now / track for later / skip
5. Presents an interactive triage report for approval
6. Executes approved decisions with standardized PR responses

**Install:**

```bash
npx skills add https://github.com/maxence2997/skills --skill review-pr-comments -g -y
```

**Usage (Claude Code):**

```
/review-pr-comments 42
/review-pr-comments https://github.com/org/repo/pull/42
/review-pr-comments https://gitlab.com/org/repo/-/merge_requests/42
```

## Prerequisites for Private Repos

This skill uses the platform CLI to fetch and reply to comments. For **private repositories**, authenticate before use:

### GitHub

```bash
gh auth login --scopes repo,read:org
gh auth status  # verify scopes
```

### GitLab

```bash
glab auth login
glab auth status  # verify access
```

For either platform, verify repo access:

```bash
# GitHub
gh api repos/<owner>/<repo> --jq '.full_name'

# GitLab
glab api projects/<id> --jq '.path_with_namespace'
```

## Adding More Skills

Each skill lives in `skills/<skill-name>/` with:
- `SKILL.md` — main skill file with frontmatter (`name`, `description`) and prompt
- `references/` — optional supplementary documents

## License

MIT
