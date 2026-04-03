# mx-commit

Commit staged changes following a structured commit message convention.

## What it does

1. Reads staged changes (`git diff --staged`)
2. Classifies the change type from the staged content
3. Drafts a commit message following the format in `references/commit-message.md`
4. Presents the draft for review before committing
5. Commits and shows the result

## Commit message format

```
<type>: <subject>          ← max 50 characters

1.<reason> → <change>      ← optional body, max 3 items, 50 chars each
```

Types: `feat`, `fix`, `refactor`, `doc`, `style`, `test`, `chore`, `revert`, `merge`, `sync`

## Usage

```
/mx-commit
```

Stage your changes first with `git add`, then invoke the skill.

## Customizing the rules

Edit `references/commit-message.md` to adjust types, format, or examples to match your project conventions.

## Notes

- Never stages additional files — only commits what is already staged
- Never uses `--no-verify`
- Refuses to commit if secrets files (`.env`, `*.pem`, `*.key`) are staged
- Stops and asks if staged changes span multiple unrelated concerns
