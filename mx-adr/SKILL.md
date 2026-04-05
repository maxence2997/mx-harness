---
name: mx-adr
description: >
  Record an Architecture Decision Record (ADR) capturing the options considered,
  trade-offs evaluated, and the rationale behind the chosen design.
  Complements the spec — the spec says what was built, the ADR says why this design
  over the alternatives. Written automatically at the end of mx-brainstorm.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Write
---

# mx-adr

## Trigger

```
/mx-adr <name>          ← record ADR for the named feature
/mx-adr                 ← infer name from active spec or ask
```

Also invoked automatically at the end of mx-brainstorm.

---

## Step 1 — Determine name and context

If `<name>` is provided, use it.
Otherwise, check for an active spec in `.mx/` subdirectories and infer from the directory name.
If ambiguous, ask the user once.

Read `.mx/<name>/spec.md` if it exists — use it to populate the ADR.

---

## Step 2 — Write the ADR

Append to `.mx/<name>/adr.md` (create if it doesn't exist).

Use today's date as a section header so multiple decisions remain distinguishable.

ADR format:

```markdown
# ADR: <feature-name>

Date: <YYYY-MM-DD>

## Context

<What problem were we solving? What constraints applied?>

## Options considered

### Option A — <name>
<What it is, pros, cons>

### Option B — <name>
<What it is, pros, cons>

### Option C — <name> (if applicable)
<What it is, pros, cons>

## Decision

<Which option was chosen and the primary reason>

## Consequences

<What becomes easier, what becomes harder, what must be monitored>

## Rejected alternatives

<Brief note on why each non-chosen option was set aside>
```

Populate from the brainstorm conversation. Do not fabricate content — if information
is missing, leave a `TBD` placeholder.

---

## Step 3 — Notify (do not ask)

Report to the user:

```
ADR saved to .mx/<name>/adr.md
Design rationale and rejected alternatives are recorded for future reference.
```

Do not ask for confirmation. Do not wait for approval. Continue the flow.

---

## Notes

- `.mx/<name>/adr.md` is permanent — do not delete ADRs during mx-finish
- ADRs accumulate over time and become a decision log for the feature
- The spec records *what* was built; the ADR records *why this design*
- Multiple decisions in one feature append to the same file with date section headers
