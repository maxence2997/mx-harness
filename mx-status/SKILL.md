---
name: mx-status
description: >
  Show the current stage, progress, and next action for all features in the
  current project. Scans ~/.mx/<project>/ for specs/ADRs and .mx/ (project-local)
  for plans, worktrees, and temp files. Detects broken states and gives
  concrete recovery instructions. Use whenever you lose track of where
  you are in the mx-flow workflow.
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-status
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
---

# mx-status

## Trigger

```
/mx-status              ← show all features in current project
/mx-status <name>       ← show one specific feature
```

---

## Path resolution

Resolve two base directories before any file operation:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$REPO_ROOT")
```

| Variable | Path | Contains |
|----------|------|----------|
| `GLOBAL_MX` | `~/.mx/<project>/` | `<name>/spec.md`, `<name>/adr.md`, `ai-learning.md` |
| `LOCAL_MX` | `<repo-root>/.mx/` | `<name>/plan.md`, `<name>/worktree/`, `<name>/tmp/` |

On Windows: `GLOBAL_MX` = `%USERPROFILE%\.mx\<project>\`

If the current directory is not inside a git repo, show all projects under `~/.mx/` and ask the user which one to inspect.

---

## Step 1 — Collect features

A feature is any `<name>` that appears as a subdirectory in **either** GLOBAL_MX or LOCAL_MX.

1. List all subdirectories under `~/.mx/<project>/` (excluding `ai-learning.md`)
2. List all subdirectories under `.mx/`
3. Union the two lists — a feature may appear in one or both locations

For each feature, collect:

| File / path | Location | Meaning |
|---|---|---|
| `spec.md` | `~/.mx/<project>/<name>/spec.md` (GLOBAL) | Brainstorm complete |
| `adr.md` | `~/.mx/<project>/<name>/adr.md` (GLOBAL) | Architecture decision recorded |
| `plan.md` | `.mx/<name>/plan.md` (LOCAL) | Plan written |
| `worktree/` directory | `.mx/<name>/worktree/` (LOCAL) | Worktree created |
| Task lines `[x]` / `[ ]` in `plan.md` | `.mx/<name>/plan.md` (LOCAL) | TDD progress |
| `tmp/review-*.md` | `.mx/<name>/tmp/review-*.md` (LOCAL) | Review report exists |
| PR URL in `plan.md` | `.mx/<name>/plan.md` (LOCAL) | PR created |

If `<name>` is given, collect only that feature.

---

## Step 2 — Classify each feature into a stage

Apply this decision tree in order:

| Stage | Condition | Label |
|---|---|---|
| **0 — Nothing** | No `spec.md` | `not started` |
| **1 — Spec** | `spec.md` exists, no `plan.md` | `awaiting plan` |
| **2 — Plan** | `plan.md` exists, no `worktree/` dir | `awaiting worktree` |
| **3 — TDD** | `worktree/` exists AND at least one `[ ]` task | `in progress` |
| **4 — Review** | All tasks `[x]`, no `tmp/review-*.md` | `awaiting review` |
| **5 — Triage** | `tmp/review-*.md` exists, no PR URL in `plan.md` | `awaiting triage / verify` |
| **6 — PR** | PR URL found in `plan.md` | `PR created` |

An "active" feature is any feature at Stage 1–5 (not yet at PR stage).

---

## Step 3 — Detect broken states

Before showing normal status, check for these anomalies:

**Broken worktree** — `plan.md` references a worktree path but `.mx/<name>/worktree/` does not exist on disk:
```
[!] Worktree missing: .mx/<name>/worktree/
    The plan references a worktree but it no longer exists on disk.
    Recovery:
      Option A — Recreate: /mx-flow (worktree phase, from the main repo directory)
      Option B — Proceed without worktree: work directly in the main repo
```

**Tasks done but no worktree** — `plan.md` has all `[x]` tasks but `worktree/` never existed:
```
[!] State inconsistency: all tasks marked done but worktree was never created.
    Likely cause: tasks were completed in the main repo, not a worktree.
    This is fine if intentional — continue to /mx-team-review.
```

**Multiple active features** — more than one feature at Stage 1–5:
```
[!] Multiple features in progress. Specify which one to continue:
    /mx-status <name>
```
List them all so the user can choose.

---

## Step 4 — Determine next action

For the focused feature (or the single active one if only one exists), output the concrete next command:

| Stage | Next action |
|---|---|
| 0 | `/mx-brainstorm <topic>` or `/mx-flow <topic>` |
| 1 | `/mx-flow <topic>` (plan phase) |
| 2 | `/mx-flow <topic>` (worktree phase) |
| 3 | `/mx-flow <topic>` (TDD phase) — name the first `[ ]` task |
| 4 | `/mx-team-review` |
| 5 — review exists, no triage | `/mx-review-triage --source review` |
| 5 — triage done, no PR | `/mx-pr` |
| 6 | `/mx-flow finish <name>` (after merge) |

---

## Step 5 — Output

Print the status block. Keep it dense and scannable — no prose.

### Single feature focus

```
mx-status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project  : <project>
Feature  : <name>
Stage    : <N> — <label>
Progress : <done>/<total> tasks  (or "no plan" if Stage 0–1)
Spec     : ~/.mx/<project>/<name>/spec.md [exists | missing]
Plan     : .mx/<name>/plan.md [exists | missing]
Worktree : .mx/<name>/worktree/ [exists | missing | none]
Review   : <report filename, or "none">

Next     : <command>
           <one-line explanation if non-obvious>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### All features in project

```
mx-status — <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ● <name>   [ACTIVE] Stage 3 — TDD  4/7 tasks
  ✓ <name>   PR created — /mx-flow finish to clean up
  ○ <name>   Stage 1 — awaiting plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active: <name>
Next  : /mx-flow  (TDD phase, task 5: <description>)
```

Symbols:
- `●` active (Stages 1–5)
- `✓` done (Stage 6)
- `○` not started (Stage 0)

If there are broken state warnings (Step 3), show them above the status block with `[!]` prefix.

---

## Step 6 — Ask if recovery is needed

If any broken state was detected, after showing the status ask:

```
Do you want help recovering this state?
```

Wait for the user's response. If yes, provide step-by-step recovery instructions based on the specific anomaly detected.

If no broken states, do not ask — just show the status and stop.
