---
name: mx-tdd
description: >
  Implement one task from the plan using test-driven development.
  Reads the next pending task from .mx/plan/<name>.md, writes a failing test first,
  implements the minimal code to pass it, refactors, then commits with /mx-commit.
  Uses vertical slices (one test → one impl), never horizontal slicing.
  Use for each task in the plan after /mx-worktree is ready.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-tdd

## Trigger

```
/mx-tdd          ← pick next pending task from .mx/plan/
/mx-tdd <task>   ← specify task number or description
```

---

## Iron Law

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.**

No exceptions. If you find yourself writing implementation before a test exists,
stop and write the test first. Code written before a test must be deleted and
reimplemented from scratch after the test is in place.

---

## Philosophy: Vertical Slices Only

```
WRONG (horizontal slicing):
  RED:   test1, test2, test3
  GREEN: impl1, impl2, impl3   ← never do this

RIGHT (vertical slices):
  RED → GREEN: test1 → impl1
  RED → GREEN: test2 → impl2
  RED → GREEN: test3 → impl3
```

Writing tests in bulk produces tests that verify imagined behavior, not actual behavior.
Each test must respond to what you learned from the previous cycle.

---

## Step 1 — Read the task

Read `.mx/plan/<name>.md` and identify the next `[ ]` task.
Read its full specification (What, Test, Files).
Read the relevant existing code before writing anything.

---

## Step 2 — Tracer bullet (first task only)

For the first task of a new feature, write one minimal test that proves the
end-to-end path works — even if it only touches a stub. This confirms the
test infrastructure is wired correctly before building out.

---

## Step 3 — Red: write the failing test

Write the test as specified in the task.

Test quality rules:
- Tests verify **behavior through public interfaces**, not implementation details
- A good test reads like a specification: "user can do X given Y"
- The test must **fail** before any production code is written
- Run the test and **observe the failure** — if it passes immediately, the test is wrong

```bash
# Auto-detect test runner (priority order):
# 1. Makefile: make check → make test → make lint
# 2. package.json: npm/yarn/pnpm test
# 3. Language: go test ./... | cargo test | pytest | dotnet test | swift test
```

Confirm the test fails with the expected error (missing symbol, assertion failure, etc.).
A test that passes without implementation proves nothing.

---

## Step 4 — Green: minimal implementation

Write the **simplest code** that makes the test pass.

Rules:
- Only enough code to pass the current test
- Do not anticipate future tests
- Do not add features not required by the current test
- Speculative code is forbidden

Run the test again — confirm it passes.
Run the full suite — confirm nothing else broke.

---

## Step 5 — Refactor

Only after GREEN, look for improvements:

- Extract duplication
- Improve naming
- Simplify logic
- Apply existing patterns from the codebase

Rules:
- **Never refactor while RED**
- Run tests after each refactor step — if anything breaks, revert immediately
- Refactor is optional; skip if the code is already clean

---

## Step 6 — Exit condition checklist

Before marking the task done, verify all five conditions are met — every one is required:

```
□ RED observed: test failure was seen with actual output (not assumed)
□ GREEN confirmed: test passes after implementation
□ Full suite clean: no new failures introduced by this change
□ Plan updated: task marked [x] in .mx/plan/<name>.md
□ Committed: /mx-commit completed for this task
```

If any item is unchecked, do not advance to the next task.

---

## Step 7 — Continue or stop

If more `[ ]` tasks remain in the plan, ask the user whether to continue to the next task.
Do not auto-advance without asking.

If this was a milestone task (last task before a review checkpoint), announce:
```
Task <N> complete. All tasks to milestone done.
Ready for /mx-team-review → /mx-review-triage
```
