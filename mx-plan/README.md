# mx-plan

Decompose an approved design spec into a concrete, ordered task list.

Reads the design spec at `~/.mx/<project>/<name>/spec.md` and produces `~/.mx/<project>/<name>/plan.md`. Each task maps to one `mx-commit` type and specifies the exact test and expected outcome. No vague placeholders.

## Usage

```
/mx-plan <name>    # use the named spec
/mx-plan           # pick from available features in .mx/
```

## Task format

Each task in the plan has:
- A single behavior to implement
- A `mx-commit` type: `feat`, `fix`, `refactor`, `test`, `chore`, `doc`
- A concrete expected test (file, scenario, expected result)
- The files that will change

## Output

`~/.mx/<project>/<name>/plan.md` — a checklist of tasks. `mx-tdd` marks tasks `[x]` after each commit. The plan has no lasting value once all tasks are done — `mx-finish` deletes it.

## Notes

- Hard gate: no code is written until the user approves the task list
- Forbidden: TBD, "similar to Task N", "add error handling" without specifics
- Hand-off: after approval, use `/mx-worktree` to set up the isolated workspace
