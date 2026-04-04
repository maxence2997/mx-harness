---
name: mx-worktree
description: >
  Create an isolated git worktree for a feature branch before implementation begins.
  Handles directory setup, gitignore verification, branch naming, dependency setup,
  and baseline test verification. Use before mx-tdd when starting new work.
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

If no branch name given, derive it from the active plan in `.mx/plan/` or ask the user.

---

## Step 1 — Verify .mx/ is gitignored

Check whether `.mx/` is ignored:

```bash
git check-ignore -q .mx 2>/dev/null
```

If **not ignored**, add it to `.gitignore` immediately:

```bash
echo '.mx/' >> .gitignore
git add .gitignore
git commit -m "chore: add .mx/ to .gitignore"
```

Inform the user this was done automatically.

---

## Step 2 — Verify .worktrees/ is gitignored

```bash
git check-ignore -q .worktrees 2>/dev/null
```

If **not ignored**, add it and commit:

```bash
echo '.worktrees/' >> .gitignore
git add .gitignore
git commit -m "chore: add .worktrees/ to .gitignore"
```

---

## Step 3 — Determine branch name

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

## Step 4 — Create the worktree

```bash
git worktree add .worktrees/<branch-name> -b <branch-name>
```

Verify it was created:

```bash
git worktree list
```

---

## Step 5 — Run project setup

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

## Step 6 — Verify baseline

Run the full test suite to confirm the worktree starts clean.

Use the same auto-detect priority as mx-tdd:
1. `Makefile` with a `check` or `test` target → `make check` or `make test`
2. `package.json` with a `test` script → `npm test` / `yarn test` / `pnpm test`
3. Language detection: `.go` → `go test ./...`, `.rs` → `cargo test`, `.py` → `pytest`, `.cs` → `dotnet test`

**If baseline fails:**
Report the failures and ask the user whether to proceed or investigate first.
Do not proceed silently with a failing baseline.

---

## Step 7 — Report

```
Worktree ready at .worktrees/<branch-name>
Branch: <branch-name>
Baseline: <N> tests passing

Ready for /mx-tdd — work from .worktrees/<branch-name>/
```
