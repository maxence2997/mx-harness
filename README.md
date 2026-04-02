# Skills

Reusable prompt-based skills for AI coding agents.

## Skill Format

Each skill lives in `<skill-name>/` with:
- `SKILL.md` — main skill file with YAML frontmatter (`name`, `description`) and prompt body
- `references/` — optional supplementary documents

## Install

```bash
npx skills add https://github.com/maxence2997/skills --skill <skill-name> -g -y
```

## Available Skills

| Skill | Description |
|-------|-------------|
| [review-pr-comments](review-pr-comments/) | Triage and respond to unresponded PR review comments |

## License

MIT
