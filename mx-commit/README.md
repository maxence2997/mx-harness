# mx-commit

Commit all pending changes following a structured commit message convention.

## What it does

1. Reads all pending changes — staged *and* unstaged (`git status`, `git diff`, `git diff --staged`)
2. Groups them into logical units — one coherent change with one type per unit
3. Drafts a commit message per unit following the repository's own commit convention when it documents one (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md` or `.github/CONTRIBUTING.md`), and the defaults in `references/commit-message.md` for anything it leaves unsaid
4. Presents the drafts for review before committing (skipped with `--auto`)
5. Stages and commits each unit separately, then shows the resulting commits

## Commit message format

The default, used wherever the repository documents nothing else:

```
<type>: <subject>                    ← max 50 characters

1.<change> → <scenario + reason>     ← optional body, max 3 items, 50 chars each
```

Types: `feat`, `fix`, `refactor`, `doc`, `style`, `test`, `chore`, `revert`, `merge`, `sync`

## Usage

```
/mx-commit          # interactive — shows the drafts and waits for approval
/mx-commit --auto   # non-interactive — commits all units immediately
```

No need to stage anything first — the skill stages each unit itself. Use `--auto` when invoked from an orchestrating skill (e.g. mx-flow); use the default when invoking it yourself.

## Customizing the rules

Edit `references/commit-message.md` to change the defaults for every repository. A repository that documents its own convention needs no edit — mx-commit follows it there.

## Notes

- Stages only the files belonging to the unit being committed
- Never uses `--no-verify`
- Refuses to commit files that likely contain secrets (`.env`, `*.pem`, `*.key`)
- Stops the run if a commit hook rejects a unit — reports the hook output instead of working around it
