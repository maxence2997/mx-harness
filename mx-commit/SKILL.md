---
name: mx-commit
description: >
  Commit all pending changes as one commit per logical concern, following the
  project's message convention (default: type prefix, 50-char subject,
  English). Use when the working tree may hold several changes or the
  convention must be enforced; a single trivial change can use plain git commit.
  Usage: /mx-commit [--auto]
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-commit
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-commit

## Auto-update

Unless another mx-* skill invoked this one, run
`bash "$HOME/.mx/.mx-harness-install.sh" --auto-update` before anything else,
if that file exists. It always exits 0 and prints nothing when there is no
news. Show the user anything it prints. If the output starts with
`mx-harness updated`, re-read this SKILL.md. Then continue with the skill; do
not run the command again during this skill run, even if it reported a failure.

## Trigger

```
/mx-commit          # interactive — shows the drafts and waits for approval
/mx-commit --auto   # non-interactive — commits all units immediately
```

Use `--auto` when invoked from an orchestrating skill (e.g. mx-flow). Use the default when invoked directly by the user.

---

## Hard Rules (never violate)

- Never use `--no-verify` or `--no-gpg-sign` unless the user explicitly requests it.
- Never amend a commit that has already been pushed.
- Never commit files that likely contain secrets (`.env`, credentials, private keys).

---

## Step 1 — Load commit message rules

Read `references/commit-message.md` (located in the same directory as this SKILL.md).
This file contains the default format, type definitions, rules, and examples to follow when drafting the commit message.

Then check whether the repository documents its own commit convention: a section on commit messages in `CLAUDE.md`, `AGENTS.md` or `CONTRIBUTING.md` at the repo root, or in `.github/CONTRIBUTING.md`. Where it differs from the defaults (subject format or length, body style, types, language), follow the repository, and keep the defaults for anything it leaves unsaid. Say which file you followed.

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

If all pending changes are one coherent change (single concern, one type), say so in one line and go straight to Step 4 with a single unit — no grouping analysis. Subject only, no body, when the change is trivial (typo, bump, comment); the subject format and length limit from Step 1 still apply.

Rules:
- A logical unit maps to exactly one commit type (`feat`, `fix`, `refactor`, `doc`, `test`, `chore`, …)
- Files that belong to the same behaviour change belong in the same unit
- Test files and their corresponding implementation belong in the same unit
- Unrelated changes must be split into separate units

If changes span multiple logical units, plan the commit order (dependencies first).

---

## Step 4 — Draft commit messages

For each logical unit, draft a commit message following the convention from Step 1 — the repository's where it documents one, the defaults everywhere else:

1. Subject line in the convention's format and within its length limit (default: `<type>: <subject>`, ≤ 50 characters).
2. Optional body in the convention's body style (default: at most 3 numbered items, each ≤ 50 characters).

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
<subject line>

<body, if any>
EOF
)"
```

If `git commit` exits non-zero (hook rejection, empty commit, signing failure), stop the
run — that unit is not committed. Report the hook output verbatim, list which units were
committed and which were not yet attempted, and leave the working tree as it is.
Never retry with `--no-verify` (see Hard Rules above).

If `--auto` was passed, proceed through all units without pausing.

---

## Step 6 — Verify

Run exactly one command and render the summary from its output — nothing else:

```bash
git log -3 --oneline --stat
```

(use `-<n+2>` when this run made n > 1 commits, so the two preceding commits are still in range).

For each commit just made, show the full block:
```
✔ <hash-short>  <type>: <subject>
  <file1>  +{n} -{n}
  <file2>  +{n} -{n}
```

Then show the two commits before those, hash and subject only:
```
  <hash-short>  <type>: <subject>
  <hash-short>  <type>: <subject>
```

If multiple commits were made in this run, all of them get the full block. The two trailing entries are always the ones immediately preceding this run.

Never print `✔` for a unit whose `git commit` exited non-zero — no commit exists for it. Report that unit as failed with the hook output, as required in Step 5.
