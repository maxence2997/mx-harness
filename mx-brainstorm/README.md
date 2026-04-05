# mx-brainstorm

Turn a rough idea into an approved design spec before any code is written.

Asks one focused question at a time, proposes 2-3 approaches with trade-offs, and saves the agreed design spec to `~/.mx/<project>/<name>/spec.md`. Automatically records an ADR capturing the options and rationale. Nothing gets built until the design spec is approved.

## Usage

```
/mx-brainstorm <topic>
/mx-brainstorm
```

## Output

`~/.mx/<project>/<name>/spec.md` — a design spec with four sections:

- **What** — what is being built or changed
- **Why** — the problem it solves
- **How** — the chosen approach and design decisions
- **Out of scope** — what this change explicitly does not cover

`~/.mx/<project>/<name>/adr.md` — the decision rationale and rejected alternatives (written automatically, no extra questions asked).

Both files have lasting value after implementation is done.

## Notes

- Never asks multiple questions at once
- Hard gate: no code is written until the user approves the design spec
- Creates `~/.mx/<project>/<name>/` and adds `~/.mx/<project>/` to `.gitignore` if needed
- Hand-off: after approval, use `/mx-plan` to decompose into tasks
