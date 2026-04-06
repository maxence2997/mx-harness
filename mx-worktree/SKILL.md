---
name: mx-worktree
description: >
  Create an isolated git worktree for a feature branch before implementation begins.
  Worktree is placed under ~/.mx/<project>/<name>/worktree/ alongside the spec and plan.
  Handles branch naming, base branch resolution, dependency setup, and baseline verification.
  Use before mx-tdd when starting new work.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-worktree

## Trigger

```
/mx-worktree <branch-name>
/mx-worktree
```

If no branch name given, resolve the MX directory (see Path resolution below) and look for any `MX/*/plan.md` to find the active feature name. Derive the branch name from it, or ask the user.

---

## Path resolution

At the start of any file operation, resolve the MX base directory:

- Run `git rev-parse --show-toplevel` to get the repo root path
- Take the final path component as `<project>`
- MX = user home + `.mx/<project>/`
  - Unix/macOS: `~/.mx/<project>/`
  - Windows: `%USERPROFILE%\.mx\<project>\`
- Create the directory if it does not exist

All feature paths are then `MX/<name>/`.

---

## Step 1 — Determine branch name

Apply branch naming convention:

| Change type | Prefix |
|---|---|
| New feature | `feat/<name>` |
| Bug fix | `bugfix/<name>` |
| Quick fix (config, docs, CI) | `fix/<name>` |
| Maintenance, deps, tooling | `chore/<name>` |

If the user provided a name without a prefix, ask which prefix applies.
If the name already has a correct prefix, proceed.

---

## Step 2 — Create the worktree

First, resolve the base branch in this order:

1. Check if `develop` exists (local or remote):
```bash
git rev-parse --verify develop 2>/dev/null || git rev-parse --verify origin/develop 2>/dev/null
```
2. If found → use `develop` as base
3. Otherwise, check if `main` exists:
```bash
git rev-parse --verify main 2>/dev/null || git rev-parse --verify origin/main 2>/dev/null
```
4. If found → use `main` as base
5. If neither exists → ask the user which branch to base from

Then create the worktree under `MX/<name>/worktree/`:

```bash
git worktree add ~/.mx/<project>/<name>/worktree -b <branch-name> <base-branch>
```

Verify it was created:

```bash
git worktree list
```

---

## Step 3 — Run project setup

From within the worktree directory, auto-detect and run setup:

```bash
# Go
if [ -f go.mod ]; then go mod download; fi

# Node.js
if [ -f package.json ]; then
  if [ -f pnpm-lock.yaml ]; then pnpm install
  elif [ -f yarn.lock ]; then yarn install
  else npm install; fi
fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi
```

---

## Step 4 — Verify baseline

Run the full test suite to confirm the worktree starts clean.

Use the same auto-detect priority as mx-tdd:
1. `Makefile` with a `check` or `test` target → `make check` or `make test`
2. `package.json` with a `test` script → `npm test` / `yarn test` / `pnpm test`
3. Language detection: `.go` → `go test ./...`, `.rs` → `cargo test`, `.py` → `pytest`, `.cs` → `dotnet test`

**If baseline fails:**
Report the failures and ask the user whether to proceed or investigate first.
Do not proceed silently with a failing baseline.

---

## Step 5 — Report

```
Worktree ready at ~/.mx/<project>/<name>/worktree/
Branch  : <branch-name>
Baseline: <N> tests passing

Ready for /mx-tdd — work from ~/.mx/<project>/<name>/worktree/
```
