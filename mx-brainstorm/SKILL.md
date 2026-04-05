---
name: mx-brainstorm
description: >
  Turn a rough idea into an approved design spec before any code is written.
  Asks one focused question at a time, proposes 2-3 approaches with trade-offs,
  writes the approved design spec to .mx/<name>/spec.md, and automatically records
  an ADR at .mx/<name>/adr.md.
  Hard gate: no implementation skill may be invoked until the user approves the design spec.
  Use at the start of any new feature, change, or non-trivial fix.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-brainstorm

## Trigger

```
/mx-brainstorm <topic>
/mx-brainstorm
```

---

## Step 1 — Understand the idea

Read existing code relevant to the topic (if any) using Glob and Read.
Then ask the user **one question at a time** to clarify:

- What problem does this solve?
- Who is affected and how?
- Are there constraints (performance, compatibility, deadlines)?
- What does success look like?

Rules:
- One question per message — never bundle multiple questions
- Prefer multiple-choice over open-ended where possible
- Stop asking when you have enough to propose approaches

---

## Step 2 — Propose approaches

Present **2 or 3 distinct approaches**. For each:

```
### Option A — <short name>
What: <one sentence>
Trade-offs: <pros and cons>
Best when: <the condition that makes this the right choice>
```

Do not recommend one option as "best" — let the user decide.
If you have a strong preference based on the context, state the reason once, briefly.

---

## Step 3 — Refine

Ask follow-up questions one at a time if the user's choice reveals new ambiguities.
Iterate until the design is unambiguous.

**Hard gate: do not proceed to Step 4 until the user explicitly approves the design spec.**

---

## Step 4 — Write the design spec

Resolve the MX directory:
- Get the repo root name: final path component of `git rev-parse --show-toplevel`
- MX = `~/.mx/<project>/` (Unix) or `%USERPROFILE%\.mx\<project>\` (Windows)
- Create `MX/<name>/` if it does not exist

Create `MX/<name>/spec.md`.

Spec format:

```markdown
# <feature-name> — Spec

## What
<What is being built or changed — one paragraph>

## Why
<The problem it solves and why it matters>

## How
<The chosen approach, key design decisions, trade-offs accepted>

## Out of scope
<Explicitly list what this change does NOT cover>
```

Show the design spec to the user for final review. Allow adjustments.

---

## Step 5 — Record ADR

After the spec is confirmed, automatically write the ADR without asking:

Create `MX/<name>/adr.md` capturing:
- The options that were proposed (from Step 2)
- The trade-offs discussed
- The user's choice and reasoning

Report: `ADR saved to ~/.mx/<project>/<name>/adr.md`

---

## Step 6 — Hand off

Once the design spec and ADR are saved, announce:

```
Design spec saved to ~/.mx/<project>/<name>/spec.md
ADR saved to ~/.mx/<project>/<name>/adr.md
Ready for /mx-plan — this will decompose the design spec into tasks.
```

Do not invoke mx-plan automatically. The user invokes it.
