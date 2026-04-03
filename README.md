# Skills

Reusable prompt-based skills for AI coding agents.

## Skill Format

Each skill lives in `<skill-name>/` with:
- `SKILL.md` — main skill file with YAML frontmatter (`name`, `description`) and prompt body
- `references/` — optional supplementary documents

## Install

Install a specific skill:

```bash
npx skills add https://github.com/maxence2997/skills --skill <skill-name> -g -y
```

Install all skills at once:

```bash
for skill in mx-commit mx-team-review mx-pr-triage; do
  npx skills add https://github.com/maxence2997/skills --skill $skill -g -y
done
```

## Available Skills

| Skill | Description |
|-------|-------------|
| [mx-commit](mx-commit/) | Commit staged changes with structured commit message convention |
| [mx-team-review](mx-team-review/) | Multi-perspective code review with three AI agents and Tech Lead synthesis |
| [mx-pr-triage](mx-pr-triage/) | Triage and respond to unresponded PR review comments |

## License

MIT
