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

**bash / zsh**
```bash
for skill in mx-flow mx-brainstorm mx-plan mx-worktree mx-tdd mx-verify mx-finish mx-commit mx-team-review mx-review-triage; do
  npx skills add https://github.com/maxence2997/skills --skill $skill -g -y
done
```

**PowerShell**
```powershell
@("mx-flow","mx-brainstorm","mx-plan","mx-worktree","mx-tdd","mx-verify","mx-finish","mx-commit","mx-team-review","mx-review-triage") | ForEach-Object {
  npx skills add https://github.com/maxence2997/skills --skill $_ -g -y
}
```

## Workflow

The skills are designed to work together in a sequence. Use `/mx-flow` to run the full pipeline, or invoke each skill individually:

```
/mx-brainstorm   idea → spec (.mx/design/)
/mx-plan         spec → task list (.mx/plan/)
/mx-worktree     isolated worktree + baseline test

loop:
  /mx-tdd              one task: red → green → refactor → commit
  (milestone reached)
  /mx-team-review      multi-perspective code review
  /mx-review-triage    triage findings → fix / track / skip
  → fixes? back to mx-tdd
  → clean? continue

/mx-verify       full test suite + plan checklist + ai-learning reminder
/mx-commit       structured commit

(after PR merge)
/mx-review-triage --source pr   triage PR comments before merge
/mx-finish                      clean up plan, reports, remind worktree removal
```

## Available Skills

### Workflow

| Skill | Description |
|-------|-------------|
| [mx-flow](mx-flow/) | Full workflow orchestrator — brainstorm to verified commit |
| [mx-brainstorm](mx-brainstorm/) | Turn a rough idea into an approved design spec |
| [mx-plan](mx-plan/) | Decompose a spec into a concrete task list |
| [mx-worktree](mx-worktree/) | Create an isolated git worktree with baseline verification |
| [mx-tdd](mx-tdd/) | Implement one task using red-green-refactor (vertical slices) |
| [mx-verify](mx-verify/) | Final verification gate before commit and push |
| [mx-finish](mx-finish/) | Clean up after PR is merged |

### Review

| Skill | Description |
|-------|-------------|
| [mx-team-review](mx-team-review/) | Multi-perspective code review — Senior Engineer, SRE, Future Maintainer |
| [mx-review-triage](mx-review-triage/) | Triage review findings from local report or PR comments |

### Commit

| Skill | Description |
|-------|-------------|
| [mx-commit](mx-commit/) | Commit staged changes with structured commit message convention |

## License

MIT
