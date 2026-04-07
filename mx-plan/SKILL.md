---
name: mx-plan
description: >
  Decompose an approved design spec into a concrete, ordered task list.
  Reads ~/.mx/<project>/<name>/spec.md and produces ~/.mx/<project>/<name>/plan.md.
  Each task maps to exactly one mx-commit type and specifies the expected
  test and outcome. No vague placeholders allowed.
  Hard gate: no implementation begins until the user approves the task list.
  Use after mx-brainstorm approves the design spec.
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-plan

## Path resolution

Resolve MX base directory before any file operation:
- Final path component of `git rev-parse --show-toplevel` = `<project>`
- MX = `~/.mx/<project>/` (Unix/macOS) or `%USERPROFILE%\.mx\<project>\` (Windows)
- Create directories as needed using the OS-appropriate command

---

## Trigger

```
/mx-plan <name>
/mx-plan
```

If no name given, list available feature directories in `~/.mx/<project>/` (those containing a `spec.md`) and ask the user to choose.

---

## Step 1 — Read the design spec

Read `~/.mx/<project>/<name>/spec.md` in full.
Also read relevant existing code (entry points, interfaces, test files) to understand
the current structure before decomposing.

---

## Step 2 — Decompose into tasks

Break the spec into the smallest tasks where each task:

- Implements **one behavior** (not a file, not a layer)
- Maps to **one `mx-commit` type** (`feat`, `fix`, `refactor`, `test`, `chore`, `doc`)
- Has a **concrete expected test**: what to write, what it verifies, expected output
- Can be committed independently without breaking the build

**Forbidden content in any task:**
- `TBD` or `TODO`
- "similar to Task N"
- "add error handling" (without specifying what error and how)
- "update tests" (without specifying which behavior)
- Pseudo-code or vague descriptions

Task format:

```markdown
### Task N — <type>: <subject (≤ 50 chars)>

**What**: <one sentence describing the behavior added or changed>
**Test**: <what test to write — file, scenario, expected result>
**Files**: <which files will change>
```

---

## Step 3 — Order the tasks

Order tasks so that:
1. Infrastructure / scaffolding comes first
2. Each task builds on previous ones without requiring future tasks
3. Tests for a behavior come in the same task as the implementation (not before, not after)

---

## Step 4 — Write the plan

Write `~/.mx/<project>/<name>/plan.md`:

```markdown
# <name> — Plan

> Design spec: ~/.mx/<project>/<name>/spec.md

## Tasks

- [ ] Task 1 — feat: <subject>
- [ ] Task 2 — test: <subject>
- [ ] Task 3 — fix: <subject>
```

Show the full task breakdown (with Task N details) to the user for review.

**Hard gate: do not proceed until the user approves the task list.**
Allow the user to add, remove, reorder, or rewrite tasks.

---

## Step 5 — Hand off

Once approved:

```
Plan saved to ~/.mx/<project>/<name>/plan.md
Ready for /mx-worktree — this will create an isolated workspace and run the baseline.
```

Do not invoke mx-worktree automatically.
