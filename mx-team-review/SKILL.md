---
name: mx-team-review
description: >
  Multi-perspective code review for git diffs or whole files: three parallel
  reviewers (Senior Engineer, SRE Guardian, Future Maintainer) synthesized by a
  Tech Lead, with language-specific standards (Go, C#). Use to review local
  changes before commit/merge. Usage: /mx-team-review [diff-spec] or
  /mx-team-review --repo <path>
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-team-review
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - Task
---

# Code Review Orchestrator

## Trigger

```
/mx-team-review [diff-spec]
/mx-team-review --repo <path>
```

## Orchestrated mode

Step 6 (interactive review of the report) pauses for the user. **When
invoked from an orchestrator that declares auto-proceed (e.g. mx-flow
Phase 5b), skip the pause**: save and display the report, then return
control — triage happens in the orchestrator's next step. When invoked
directly by the user, Step 6 applies as written.

---

## Step 1: Parse Arguments and Determine Mode

Parse the user's argument to determine the review mode:

| Invocation | Mode | Action |
|---|---|---|
| `/mx-team-review` (no args) | diff | `git diff --cached` (staged changes) |
| `/mx-team-review HEAD~3` | diff | `git diff HEAD~3..HEAD` |
| `/mx-team-review main..HEAD` | diff | `git diff main..HEAD` |
| `/mx-team-review abc..def` | diff | `git diff abc..def` |
| `/mx-team-review --repo src/service/` | repo | Read all code files in directory |
| `/mx-team-review --repo src/service/order.go` | repo | Read specific file(s) |

**Argument parsing:**
1. If argument starts with `--repo` → repo mode. The path(s) follow.
2. Otherwise → diff mode. If no argument, default to `--cached`.

**Validation:**
- Diff mode: run the git diff command. If output is empty, print
  `No changes to review.` and stop.
- Repo mode: check if path exists. If not, print error and stop.

Display: `📋 Reviewing: {description of what is being reviewed}`

---

## Step 2: Language Detection

Scan file extensions from the diff output (file paths in diff headers) or
the target file paths:

| Extension | Language Spec |
|-----------|--------------|
| `.go` | `references/golang.md` |
| `.cs` | `references/dotnet.md` |
| other | skip (no language spec loaded) |

**Always load** `references/principles.md` (cross-language core
principles). Then load the matched language-specific spec file(s).
If multiple languages detected, load all matched specs.

Reference files are located relative to this SKILL.md file (sibling
`references/` directory).

Display: `🔍 Detected: {language list}`

---

## Step 3: Gather Code Context

### Diff Mode

Run the git diff command determined in Step 1. The diff output is the
review material.

### Repo Mode

Use Glob to list files matching the path. Use Read to load each file's
content.

**Skip these files/directories:**
- Binary files (images, compiled assets)
- Lock files (`go.sum`, `package-lock.json`, `yarn.lock`)
- Vendor directories (`vendor/`, `node_modules/`)
- Generated files (`*.pb.go`, `*.generated.cs`)
- Config/data files (`.json`, `.yaml`, `.yml`, `.toml`, `.xml`) unless
  explicitly targeted

---

## Step 4: Multi-Perspective Review

**First, read `references/prompts.md`** (sibling `references/` directory).
It contains the reviewer output schema, the line-number rules, the three
reviewer prompts, and the Tech Lead synthesizer prompt used below.

This step has two execution modes. **Choose based on available
capabilities:**

- **Step 4A** — If the **Agent tool** (or its legacy alias **Task**) is
  available (e.g., Claude Code): dispatch four subagents (three reviewers
  in parallel, then one synthesizer).
- **Step 4B** — If neither is available (e.g., Copilot, Cursor, or other
  platforms): perform all four perspectives sequentially in a single pass.

Both modes produce the **same final output**, so Step 5 works identically.

### Step 4A: Parallel Dispatch (Agent/Task tool available)

**Phase 1 — Three Reviewers (parallel):**

Dispatch Agent 1 (Senior Engineer), Agent 2 (SRE Guardian), and Agent 3
(Future Maintainer) simultaneously — all three Agent calls in a single
message.

Each subagent receives:
- Full diff or file content from Step 3
- Full content of `references/principles.md`
- Full content of matched language spec files
- Its own perspective prompt plus the shared schema and line-number rules
  (all from `references/prompts.md`)

Model: set `model: "sonnet"` (mid tier) for the three reviewers.

Wait for all three to complete. Collect their JSON outputs.

**Phase 2 — Tech Lead (sequential):**

Dispatch Agent 4 (Tech Lead) with:
- All three JSON outputs from Phase 1
- The original diff/code content (for cross-verification)
- The `references/principles.md` content (for severity calibration)

Model: `model: "sonnet"` by default. **Escalate the Tech Lead to the
strongest available tier** (e.g. `opus`) when the diff touches any of:
concurrency primitives, auth/security, data migration, or a public API
surface — synthesis quality there is worth the cost (see
`../mx-doctrine/references/model-dispatch.md` §4; if missing, apply this
sentence as written).

Collect the final merged JSON.

### Step 4B: Single-Pass Fallback (no Agent/Task tool)

Perform all four perspectives yourself, sequentially, using the prompts
from `references/prompts.md`:

1. Adopt the **Senior Engineer** perspective. Analyze the entire code.
   Produce its JSON output (`"agent": "senior-engineer"`).
2. Adopt the **SRE Guardian** perspective. Analyze independently — do not
   skip areas already covered. Produce its JSON output
   (`"agent": "sre-guardian"`).
3. Adopt the **Future Maintainer** perspective. Analyze independently.
   Produce its JSON output (`"agent": "future-maintainer"`).
4. Adopt the **Tech Lead** perspective. Take all three JSON outputs and
   synthesize the final merged JSON.

**Important:** Each perspective must be treated as an independent review.
Do not let findings from one perspective influence another. Duplicates are
expected — the Tech Lead handles merging.

Single-pass reviews share one context — genuinely useful, but weaker than
independent reviewers. Note `(single-pass mode)` in the report header so
readers calibrate their trust.

---

## Step 5: Report Generation

Take the Tech Lead's final JSON and format the report.

**Report format:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Review: {description of scope}
   {n} files reviewed  |  {language list}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 {file_path}

🔴 error  L{line}  [{category}]
   {message}
   💡 {suggestion}

🟡 warning  L{line}  [{category}]
   {message}
   💡 {suggestion}

🔵 suggestion  L{line}  [{category}]
   {message}
   💡 {suggestion}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 {e} errors  {w} warnings  {s} suggestions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ Highlights
{- {message}}
{- {message}}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Severity emoji: 🔴 error, 🟡 warning, 🔵 suggestion

For issues with `line: 0`, display `L-` instead of `L0`.

If there are no highlights, omit the ✨ Highlights section entirely.

**Output actions:**

1. Detect active feature:
   - Resolve repo root: `REPO_ROOT=$(git rev-parse --show-toplevel)`
   - If running inside a linked worktree, `.mx/` lives in the MAIN
     repository, not the worktree — resolve it too:
     `MAIN_ROOT=$(dirname "$(git rev-parse --git-common-dir)")`
     (in a normal checkout `MAIN_ROOT` equals `REPO_ROOT`)
   - Look for any `.mx/*/plan.md` under `$REPO_ROOT`, then under
     `$MAIN_ROOT` — take the first match as the active feature
   - If found → report directory is `.mx/<name>/tmp/` (create if needed)
   - If not found → report directory is `/tmp/review-reports/` on Unix or
     `%TEMP%\review-reports\` on Windows (create if needed)
2. Save the report as `{report-dir}/review-{YYYYMMDD-HHmmss}.md`
3. Display the full report in the terminal

---

## Step 6: Interactive Review

(Skipped in orchestrated mode — see "Orchestrated mode" above.)

After displaying the report, ask:

```
Please review the report. Any changes needed?
```

**If the user requests changes:**

1. Discuss the issue with the user
2. Modify the report and update the saved file accordingly
3. Display the updated report
4. Ask again: `Any other changes?`
5. Repeat until the user confirms

**If the user confirms (e.g., "no", "OK", "looks good"):**

Done. Display the saved report path with a reminder:

```
📄 Report saved: {report-dir}/review-{timestamp}.md
```

If saved to `/tmp/review-reports/`, add a note:
```
⚠️  No active feature detected — report saved to /tmp (cleared on reboot). Run from within a feature workflow to save under .mx/<name>/tmp/ instead.
```

---

## Extending to a New Language

To add a new language spec:
1. Create `references/{lang}.md` using `references/_template.md` as a base
2. Only include language-specific patterns — cross-language principles are
   in `references/principles.md`
3. Add a row to the language detection table in Step 2:
   ```
   | `.ext` | `references/{lang}.md` |
   ```
No other changes required.
