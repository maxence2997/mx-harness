# mx-adr

Record the *why* behind a design decision — options considered, trade-offs evaluated, and the rationale for the chosen approach.

The spec (`.mx/<name>/spec.md`) records what was built. The ADR (`.mx/<name>/adr.md`) records why this design over the alternatives. Months later, when you wonder "why did we do it this way?", the ADR answers that question.

## Usage

```
/mx-adr <name>   # record ADR for named feature
/mx-adr          # infer from active spec or ask
```

Also runs automatically at the end of `/mx-brainstorm` — no need to invoke manually in the normal flow.

## Output

```
.mx/<name>/adr.md
```

Multiple decisions append to the same file with date section headers.

## What it records

| Section | Content |
|---------|---------|
| Context | The problem and constraints that drove the decision |
| Options considered | Each alternative with pros and cons |
| Decision | Which option was chosen and the primary reason |
| Consequences | What becomes easier or harder as a result |
| Rejected alternatives | Why each non-chosen option was set aside |

## Notes

- ADRs are permanent — not deleted by `/mx-finish`
- Populated automatically from the brainstorm conversation; no extra questions asked
- Use `/mx-adr` standalone to record decisions made outside of brainstorm
- All files for a feature live under `.mx/<name>/` — spec, plan, and ADRs together
