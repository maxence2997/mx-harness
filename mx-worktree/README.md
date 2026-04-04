# mx-worktree

Create an isolated git worktree for a feature branch before implementation begins.

Sets up `.worktrees/<branch-name>` in the project root, verifies gitignore rules, runs dependency setup, and confirms a clean baseline before any code is written.

## Usage

```
/mx-worktree feat/my-feature
/mx-worktree                   # derives name from active plan or asks
```

## Branch naming

| Prefix | Use for |
|--------|---------|
| `feat/` | New feature |
| `bugfix/` | Bug fix |
| `fix/` | Quick fix (config, docs, CI) |
| `chore/` | Maintenance, deps, tooling |

## What it does

1. Verifies `.mx/` and `.worktrees/` are in `.gitignore` (adds + commits if not)
2. Creates the worktree at `.worktrees/<branch-name>`
3. Runs project setup (go mod download / npm install / pip install / etc.)
4. Verifies a clean test baseline — stops if tests fail

## Notes

- Worktree lives in `.worktrees/` (gitignored, survives reboots unlike `/tmp`)
- If baseline is failing, reports and asks before proceeding
- After setup, work from inside `.worktrees/<branch-name>/`
- Clean up later with `/mx-finish` (which will remind you to run `git worktree remove`)
