# mx-brainstorm

Turn a rough idea into an approved design spec before any code is written.

Asks one focused question at a time, proposes 2-3 approaches with trade-offs, and saves the agreed design to `.mx/design/<name>.md`. Nothing gets built until the spec is approved.

## Usage

```
/mx-brainstorm <topic>
/mx-brainstorm
```

## Output

`.mx/design/<name>.md` — a spec with four sections:

- **What** — what is being built or changed
- **Why** — the problem it solves
- **How** — the chosen approach and design decisions
- **Out of scope** — what this change explicitly does not cover

The spec has lasting value after implementation is done.

## Notes

- Never asks multiple questions at once
- Hard gate: no code is written until the user approves the spec
- Creates `.mx/` and adds it to `.gitignore` if needed
- Hand-off: after approval, use `/mx-plan` to decompose into tasks
