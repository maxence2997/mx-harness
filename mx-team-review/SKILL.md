---
name: mx-team-review
description: >
  Multi-perspective code review for local changes or entire files.
  Reviews git diffs (staged, commit ranges, branch comparisons) or whole files/directories.
  Three parallel review perspectives (Senior Engineer, SRE Guardian, Future Maintainer)
  feed into a Tech Lead who synthesizes the final report with noise filtering and conflict resolution.
  Auto-detects language from file extensions and loads language-specific review standards.
  Supports parallel subagents (Claude Code) or single-pass fallback (Copilot, Cursor, etc.).
  Usage: /team-review [diff-spec] or /team-review --repo <path>
  Supported languages: Go (.go), C# .NET 8 (.cs)
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
/team-review [diff-spec]
/team-review --repo <path>
```

---

## Step 1: Parse Arguments and Determine Mode

Parse the user's argument to determine the review mode:

| Invocation | Mode | Action |
|---|---|---|
| `/team-review` (no args) | diff | `git diff --cached` (staged changes) |
| `/team-review HEAD~3` | diff | `git diff HEAD~3..HEAD` |
| `/team-review main..HEAD` | diff | `git diff main..HEAD` |
| `/team-review abc..def` | diff | `git diff abc..def` |
| `/team-review --repo src/service/` | repo | Read all code files in directory |
| `/team-review --repo src/service/order.go` | repo | Read specific file(s) |

**Argument parsing:**
1. If argument starts with `--repo` → repo mode. The path(s) follow.
2. Otherwise → diff mode. If no argument, default to `--cached`.

**Validation:**
- Diff mode: run the git diff command. If output is empty, print `No changes to review.` and stop.
- Repo mode: check if path exists. If not, print error and stop.

Display: `📋 Reviewing: {description of what is being reviewed}`

---

## Step 2: Language Detection

Scan file extensions from the diff output (file paths in diff headers) or the target file paths:

| Extension | Language Spec |
|-----------|--------------|
| `.go` | `references/golang.md` |
| `.cs` | `references/dotnet.md` |
| other | skip (no language spec loaded) |

**Always load** `references/principles.md` (cross-language core principles).
Then load the matched language-specific spec file(s).
If multiple languages detected, load all matched specs.

Reference files are located relative to this SKILL.md file (sibling `references/` directory).

Display: `🔍 Detected: {language list}`

---

## Step 3: Gather Code Context

### Diff Mode

Run the git diff command determined in Step 1. The diff output is the review material.

### Repo Mode

Use Glob to list files matching the path. Use Read to load each file's content.

**Skip these files/directories:**
- Binary files (images, compiled assets)
- Lock files (`go.sum`, `package-lock.json`, `yarn.lock`)
- Vendor directories (`vendor/`, `node_modules/`)
- Generated files (`*.pb.go`, `*.generated.cs`)
- Config/data files (`.json`, `.yaml`, `.yml`, `.toml`, `.xml`) unless explicitly targeted

---

## Step 4: Multi-Perspective Review

This step has two execution modes. **Choose based on available capabilities:**

- **Step 4A** — If the **Agent tool** (or **Task tool**) is available (e.g., Claude Code): dispatch four subagents (three reviewers in parallel, then one synthesizer).
- **Step 4B** — If neither tool is available (e.g., Copilot, Cursor, or other platforms): perform all four perspectives sequentially in a single pass.

Both modes produce the **same final output**, so Step 5 works identically.

---

### Shared: Reviewer Output Schema (Agents 1-3)

Each reviewer must produce a JSON object with this structure:

```json
{
  "agent": "<agent-id>",
  "issues": [
    {
      "file": "relative/path/to/File.go",
      "line": 42,
      "severity": "error | warning | suggestion",
      "category": "logging | race-condition | testing | comment | exception | performance | async | di | architecture",
      "message": "Description of the issue",
      "suggestion": "Concrete improvement, may include a code snippet"
    }
  ],
  "highlights": [
    {
      "message": "What was done well — design decision, pattern, or implementation worth noting"
    }
  ]
}
```

`highlights` are positive observations only. They are informational and will **not** be triaged.

### Shared: Line Number Rules

**Diff mode:**
- The `line` field must be the **new-side line number** from the diff hunk header.
- A diff hunk like `@@ -10,5 +12,8 @@` means new-side lines start at 12.
- Only lines prefixed with `+` or ` ` (context) in the diff have valid new-side line numbers.
- Parse the diff hunk headers (`@@ ... +N,M @@`) to determine valid line ranges.
- Count lines from the `+N` start: context lines (` `) and added lines (`+`) increment the new-side counter; removed lines (`-`) do not.

**Repo mode:**
- The `line` field is the actual line number in the file.

**Both modes:**
- If the issue is about a **missing** element (e.g., missing logging, missing test) that cannot be pinpointed to a specific line, use `0`.
- Never guess line numbers. If you cannot determine the exact line, use `0`.

---

### Shared: Three Reviewer Perspectives

#### Agent 1 — Senior Engineer

```
You are a Senior Engineer conducting a code review.
You focus on design quality and implementation correctness.

Focus areas (issues):
- SRP: constructor only does dependency injection — no logic, no I/O, no side effects
- Is business logic leaking into the infrastructure layer? Are dependency directions correct (infrastructure → application → domain)?
- Is there a simpler, more direct implementation? Is this over-engineered?
- Are error handling design choices correct (wrap with context, sentinel errors, custom types)?
- Does this follow the language's idiomatic patterns and existing codebase conventions?
- Are there unnecessary abstractions or premature generalizations?

Focus areas (highlights):
- Clean separation of concerns or layering done well
- Idiomatic patterns applied correctly
- Good abstraction that makes the code easier to extend or test
- Error handling that is explicit and well-structured
- Any design decision that shows clear thinking

Core principles:
{PRINCIPLES_CONTENT}

Language-specific spec:
{LANGUAGE_SPEC_CONTENT}

Review material:
{CODE_CONTENT}

Output your findings as a JSON object matching the required schema.
Set "agent" to "senior-engineer".
Output JSON only. No prose, no markdown, no explanation outside the JSON.
```

#### Agent 2 — SRE Guardian

```
You are an SRE responsible for production stability, conducting a code review.
Your only concern: what will go wrong when this hits production?

Focus areas (issues):
- Is there enough logging to debug an incident? Are logs structured with context?
- Can errors propagate silently? Are all catch/error paths explicitly handled?
- Are there race conditions under concurrent load?
- Are resources (connections, streams, goroutines) properly released?
- Is there an obvious performance hazard (N+1, missing cache, blocking async)?

Focus areas (highlights):
- Logging that provides genuinely useful incident context
- Defensive patterns that prevent silent failures
- Proper resource cleanup or lifecycle management
- Timeout and retry logic that is well-reasoned
- Any operational detail that makes this safer to run in production

Core principles:
{PRINCIPLES_CONTENT}

Language-specific spec:
{LANGUAGE_SPEC_CONTENT}

Review material:
{CODE_CONTENT}

Output your findings as a JSON object matching the required schema.
Set "agent" to "sre-guardian".
Output JSON only. No prose, no markdown, no explanation outside the JSON.
```

#### Agent 3 — Future Maintainer

```
You are an engineer who will inherit this code in 6 months, conducting a code review.
You have no context beyond what is written.

Focus areas (issues):
- Do comments explain WHY, not just what? (What is already in the code.)
- Do log messages carry enough context to understand what happened without reading the code?
- Are business rules documented where they are enforced?
- Are test scenarios comprehensive enough to understand expected behavior?
- Is naming semantically clear without requiring internal knowledge?

Focus areas (highlights):
- Comments that explain non-obvious decisions or trade-offs clearly
- Naming that communicates intent without requiring internal knowledge
- Tests that double as documentation of expected behaviour
- Any structure or pattern that makes the code easy to navigate for someone new

Core principles:
{PRINCIPLES_CONTENT}

Language-specific spec:
{LANGUAGE_SPEC_CONTENT}

Review material:
{CODE_CONTENT}

Output your findings as a JSON object matching the required schema.
Set "agent" to "future-maintainer".
Output JSON only. No prose, no markdown, no explanation outside the JSON.
```

---

### Agent 4 — Tech Lead (Synthesizer)

The Tech Lead receives all three reviewers' outputs and produces the **final review**.

```
You are a Tech Lead. You just received independent code review findings from three senior engineers, each reviewing from a different perspective (design quality, production stability, maintainability).

Your job is to synthesize ONE final review — not to relay their opinions.

Rules for issues:
1. DEDUPLICATE: Multiple findings about the same location and issue → merge into one entry. Pick the clearest message and most actionable suggestion.
2. CONFIDENCE WEIGHTING: If multiple reviewers independently flagged the same issue, you should be more confident it is a real problem. This may justify raising severity. But do NOT tell the reader how many reviewers flagged it.
3. RESOLVE CONFLICTS: If reviewers disagree, make the final call. Give one clear recommendation.
4. FILTER NOISE: Remove false positives, overly speculative suggestions, and findings that don't apply to the actual code context.
5. SEVERITY ASSIGNMENT: Use your judgment. error = will cause bugs/crashes/data loss. warning = creates tech debt or operational risk. suggestion = improvement opportunity.
6. SORT: Group by file, then sort by severity (error → warning → suggestion).

Rules for highlights:
7. DEDUPLICATE: Merge highlights about the same thing into one clear statement.
8. KEEP GENUINE: Only include highlights that reflect a real, specific strength — not generic praise.
9. NO TRIAGE: Highlights are informational only. Do not assign severity or suggest changes.

Input — Reviewer findings:
{AGENT_1_JSON}
{AGENT_2_JSON}
{AGENT_3_JSON}

Original code for cross-verification:
{CODE_CONTENT}

Core principles (for severity calibration):
{PRINCIPLES_CONTENT}

Output a single JSON object:
{
  "issues": [
    {
      "file": "relative/path",
      "line": 42,
      "severity": "error | warning | suggestion",
      "category": "logging | race-condition | testing | comment | exception | performance | async | di | architecture",
      "message": "Clear description of the issue",
      "suggestion": "Concrete improvement, may include a code snippet"
    }
  ],
  "highlights": [
    {
      "message": "What was done well"
    }
  ]
}

Output JSON only. No prose, no markdown, no explanation outside the JSON.
```

---

### Step 4A: Parallel Dispatch (Agent/Task tool available)

**Phase 1 — Three Reviewers (parallel):**

Dispatch Agent 1, Agent 2, and Agent 3 simultaneously as parallel subagents.

Each subagent receives:
- Full diff or file content from Step 3
- Full content of `references/principles.md`
- Full content of matched language spec files
- Its own perspective prompt (from above)

If using Claude Code's Agent tool, set `model: "sonnet"` to optimize token cost.

Wait for all three to complete. Collect their JSON outputs.

**Phase 2 — Tech Lead (sequential):**

Dispatch Agent 4 (Tech Lead) with:
- All three JSON outputs from Phase 1
- The original diff/code content (for cross-verification)
- The `references/principles.md` content (for severity calibration)

If using Claude Code's Agent tool, set `model: "sonnet"` to optimize token cost.

Collect the final merged JSON array.

---

### Step 4B: Single-Pass Fallback (no Agent/Task tool)

Perform all four perspectives yourself, sequentially.

You have access to:
- Full diff or file content from Step 3
- Full content of `references/principles.md`
- Full content of matched language spec files

**Execution:**

1. Adopt the **Senior Engineer** perspective. Analyze the entire code. Produce its JSON output (`"agent": "senior-engineer"`).
2. Adopt the **SRE Guardian** perspective. Analyze independently — do not skip areas already covered. Produce its JSON output (`"agent": "sre-guardian"`).
3. Adopt the **Future Maintainer** perspective. Analyze independently. Produce its JSON output (`"agent": "future-maintainer"`).
4. Adopt the **Tech Lead** perspective. Take all three JSON outputs and synthesize the final merged JSON array.

**Important:** Each perspective must be treated as an independent review. Do not let findings from one perspective influence another. Duplicates are expected — the Tech Lead handles merging.

---

## Step 5: Report Generation

Take the Tech Lead's final JSON array and format the report.

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
   - Resolve MX directory (final component of `git rev-parse --show-toplevel` as `<project>`, then `~/.mx/<project>/` or `%USERPROFILE%\.mx\<project>\`)
   - Look for any `MX/*/plan.md` — take the first match as the active feature
   - If found → report directory is `MX/<name>/tmp/` (create if needed)
   - If not found → report directory is `/tmp/review-reports/` on Unix or `%TEMP%\review-reports\` on Windows (create if needed)
2. Save the report as `{report-dir}/review-{YYYYMMDD-HHmmss}.md`
3. Display the full report in the terminal

---

## Step 6: Interactive Review

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
⚠️  No active feature detected — report saved to /tmp (cleared on reboot). Run from within a feature workflow to save under ~/.mx/<project>/<name>/tmp/ instead.
```

---

## Extending to a New Language

To add a new language spec:
1. Create `references/{lang}.md` using `references/_template.md` as a base
2. Only include language-specific patterns — cross-language principles are in `references/principles.md`
3. Add a row to the language detection table in Step 2:
   ```
   | `.ext` | `references/{lang}.md` |
   ```
No other changes required.
