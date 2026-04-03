---
name: mx-commit
description: >
  Commit staged changes following the project's commit message convention.
  Enforces: one logical change per commit, type prefix, 50-char subject limit,
  numbered body items in "reason → change" format, English only.
  Usage: /commit
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Commit

## Trigger

```
/commit
```

---

## Step 1 — Load commit message rules

Read `references/commit-message.md` (located in the same directory as this SKILL.md).
This file contains the format, type definitions, rules, and examples to follow when drafting the commit message.

---

## Step 2 — Inspect staged changes

```bash
git diff --staged
git status
```

If nothing is staged, tell the user and stop. Do not `git add` files without explicit instruction.

---

## Step 3 — Classify the change

Determine the correct `type` from the type table in `references/commit-message.md` based on what is staged. When in doubt between two types, pick the one that most accurately describes the primary intent.

---

## Step 4 — Draft the commit message

Following the format in `references/commit-message.md`:

1. Write the subject line: `<type>: <subject>` — must be ≤ 50 characters.
2. If the change needs explanation, write up to 3 body items in `reason → change` format, each ≤ 50 characters.
3. Present the draft to the user for review before committing.

---

## Step 5 — Commit

After the user approves (or if the context makes approval implicit), commit using a HEREDOC to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<type>: <subject>

1.<reason> → <change>
EOF
)"
```

---

## Step 6 — Verify

```bash
git log --oneline -3
```

Show the result to the user.

---

## Hard Rules (never violate)

- Never use `--no-verify` or `--no-gpg-sign` unless the user explicitly requests it.
- Never amend a commit that has already been pushed.
- Never commit files that likely contain secrets (`.env`, credentials, private keys).
- Never stage additional files beyond what the user has already staged.
- One logical change per commit — if staged changes span multiple concerns, tell the user and ask them to split.
