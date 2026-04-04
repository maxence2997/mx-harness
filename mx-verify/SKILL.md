---
name: mx-verify
description: >
  Final verification gate before committing or pushing. Runs the full test suite,
  checks every task in the plan is marked complete, and reminds to update
  .mx/ai-learning.md. No partial checks accepted. Use after the convergent
  review loop is clean and before the final commit and push.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-verify

## Trigger

```
/mx-verify <name>   ← verify against named plan
/mx-verify          ← find active plan in .mx/plan/ or ask
```

---

## Iron Law

**NO COMPLETION CLAIM WITHOUT FRESH VERIFICATION EVIDENCE.**

Do not claim tests pass without having just run them.
Do not claim tasks are done without reading the plan file.
Evidence first, then assertion.

---

## Step 1 — Run full test suite

Run the complete test suite. No partial runs.

Auto-detect runner (same priority as mx-tdd):
1. Makefile: `make check` → `make test`
2. `package.json`: `npm test` / `yarn test` / `pnpm test`
3. Language: `go test ./...` / `cargo test` / `pytest` / `dotnet test` / `swift test`

Read the full output. Count failures.

**If any test fails:** report the failures with output, stop. Do not proceed.
**If all pass:** state the count explicitly: `N tests passing, 0 failures`.

---

## Step 2 — Check plan completion

Read `.mx/plan/<name>.md`.

For every task line, verify its status:
- `[x]` — completed
- `[ ]` — pending

If any task is still `[ ]`, list them and stop. Do not claim completion with open tasks.

If all tasks are `[x]`, report: `All N tasks complete.`

---

## Step 3 — Remind ai-learning

Show this reminder:

```
Update .mx/ai-learning.md before closing this session.

Format:
| Date       | Issue or Learning | Root Cause | Prevention Rule |
| ---------- | ----------------- | ---------- | --------------- |
| YYYY-MM-DD | <what happened>   | <why>      | <how to avoid>  |

Record at least one entry — even if no mistakes were made.
Acceptable entries: techniques confirmed, observations, rules verified.
```

---

## Step 4 — Gate result

Only if Step 1 and Step 2 both pass:

```
Verification passed.
  Tests: N passing, 0 failures
  Plan:  N/N tasks complete

Ready to commit and push.
```

If either step fails, do not output the above. Fix the issue first.
