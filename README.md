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
```

## Prerequisites for Private Repos

This skill uses `gh api` to fetch and reply to PR comments. If you are working with **private repositories**, ensure the following before use:

### 1. GitHub CLI authentication

```bash
gh auth login
```

Verify access to your target repo:

```bash
gh api repos/<owner>/<repo> --jq '.full_name'
```

### 2. Required scopes

Your GitHub token must have these scopes:
- `repo` — read/write access to private repositories
- `read:org` — if the repo belongs to an organization

Check your current scopes:

```bash
gh auth status
```

If scopes are missing, re-authenticate:

```bash
gh auth login --scopes repo,read:org
```

### 3. Fine-grained PAT (alternative)

If using a fine-grained personal access token instead of `gh auth`:
- **Repository access**: select the target repos
- **Permissions**: Pull requests (Read and write), Contents (Read)

Set it via:

```bash
gh auth login --with-token < my-token.txt
```

## Adding More Skills

Each skill lives in `skills/<skill-name>/` with:
- `SKILL.md` — main skill file with frontmatter (`name`, `description`) and prompt
- `references/` — optional supplementary documents

## License

MIT
