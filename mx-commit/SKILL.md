---
name: mx-commit
description: >
  Commit all pending changes following the project's commit message convention.
  Inspects both staged and unstaged changes, groups them by logical concern,
  stages and commits each group separately. Enforces: one logical change per
  commit, type prefix, 50-char subject limit, numbered body items in
  "reason → change" format, English only.
  Usage: /mx-commit
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-commit

## Trigger

```
/mx-commit          # interactive — shows draft and waits for approval per commit
/mx-commit --auto   # non-interactive — commits all groups immediately without confirmation
```

Use `--auto` when invoked from an orchestrating skill (mx-tdd, mx-flow). Use the default when invoked directly by the user.

---

## Step 1 — Load commit message rules

Read `references/commit-message.md` (located in the same directory as this SKILL.md).
This file contains the format, type definitions, rules, and examples to follow when drafting the commit message.

---

## Step 2 — Inspect all pending changes

```bash
git status
git diff          # unstaged
git diff --staged # staged
```

If there are no changes at all (nothing staged, nothing modified), tell the user and stop.

---

## Step 3 — Group by logical concern

Analyse all pending changes (staged and unstaged together) and group them into one or more **logical units**. A logical unit is a set of files that together represent exactly one coherent change with a single `type`.

Rules:
- A logical unit maps to exactly one commit type (`feat`, `fix`, `refactor`, `doc`, `test`, `chore`, …)
- Files that belong to the same behaviour change belong in the same unit
- Test files and their corresponding implementation belong in the same unit
- Unrelated changes must be split into separate units

If changes span multiple logical units, plan the commit order (dependencies first).

---

## Step 4 — Draft commit messages

For each logical unit, draft a commit message following the format in `references/commit-message.md`:

1. Subject line: `<type>: <subject>` — must be ≤ 50 characters.
2. Optional body: up to 3 items in `reason → change` format, each ≤ 50 characters.

If `--auto` was **not** passed, present all drafts to the user grouped by unit before committing any of them. Wait for approval.

---

## Step 5 — Commit each unit

For each logical unit in order:

1. Stage only the files in that unit:
```bash
git add <file1> <file2> ...
```

2. Commit using a HEREDOC:
```bash
git commit -m "$(cat <<'EOF'
<type>: <subject>

1.<reason> → <change>
EOF
)"
```

If `--auto` was passed, proceed through all units without pausing.

---

## Step 6 — Verify

Do not run additional bash commands. Using information already known from Step 5, output a formatted summary directly:

```
✔ <hash-short>  <type>: <subject>
  <file1>  +{n} -{n}
  <file2>  +{n} -{n}
```

If multiple commits were made, repeat the block for each one in order.

---

## Hard Rules (never violate)

- Never use `--no-verify` or `--no-gpg-sign` unless the user explicitly requests it.
- Never amend a commit that has already been pushed.
- Never commit files that likely contain secrets (`.env`, credentials, private keys).
