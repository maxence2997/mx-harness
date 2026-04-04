# mx-tdd

Implement one task from the plan using test-driven development.

Red → Green → Refactor, one behavior at a time. Reads the next pending task from `.mx/plan/<name>.md`, enforces the Iron Law (no production code without a failing test), and commits each completed behavior with `/mx-commit`.

## Usage

```
/mx-tdd          # pick next pending task
/mx-tdd <task>   # specify task number or description
```

## The cycle

```
RED   → write failing test, observe failure
GREEN → minimal code to pass, run full suite
REFACTOR → clean up while staying green
COMMIT → /mx-commit, mark [x] in plan
```

## Key rules

- **Iron Law**: no production code without a failing test first
- **Vertical slices only**: one test → one impl → repeat (never write all tests then all code)
- **Tracer bullet**: first task of a new feature proves the end-to-end path works
- Tests verify behavior through public interfaces, not implementation details
- Never refactor while RED — get to GREEN first

## Test runner detection

Auto-detects in priority order: Makefile (`check`/`test`) → `package.json` scripts → language toolchain (`go test`, `cargo test`, `pytest`, `dotnet test`, `swift test`).

## Notes

- After each task: marks `[x]` in `.mx/plan/<name>.md` then calls `/mx-commit`
- Asks before advancing to the next task
- At milestone: announces readiness for `/mx-team-review`
