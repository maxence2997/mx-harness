# mx-verify

Final verification gate before committing or pushing.

Runs the full test suite, confirms every task in `.mx/plan/<name>.md` is marked complete, and reminds you to update `.mx/ai-learning.md` for cross-session memory. No partial checks accepted — evidence before claims.

## Usage

```
/mx-verify <name>   # verify against named plan
/mx-verify          # find active plan or ask
```

## Gates

1. **Full test suite** — must pass completely (no partial runs)
2. **Plan checklist** — every `[ ]` task must be `[x]`
3. **ai-learning reminder** — prompts to record session learnings

All three must pass before the final commit and push.

## Notes

- Auto-detects test runner: Makefile → package.json → language toolchain
- If any test fails, stops immediately with the failure output
- If any task is still `[ ]`, lists them and stops
- The ai-learning reminder is a prompt, not a gate — but skipping it defeats cross-session memory
