# mx-verify

Final verification gate before committing or pushing.

Runs the full test suite, confirms every task in `~/.mx/<project>/<name>/plan.md` is marked complete, and reminds you to update `~/.mx/<project>/ai-learning.md` for cross-session memory. No partial checks accepted — evidence before claims.

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

## Abort path

When verification fails, three recovery options are presented:

| Option | When to use |
|--------|-------------|
| **[A] Investigate** | Failing test or incomplete task — return to `mx-tdd` at the specific point |
| **[B] Adjust plan** | Task definition was wrong — edit `~/.mx/<project>/<name>/plan.md` then re-run `mx-tdd` |
| **[C] Abort branch** | Branch is not recoverable — design spec and ADRs preserved, plan and worktree discarded |

Nothing executes automatically — the user chooses the path.

## Notes

- Auto-detects test runner: Makefile → package.json → language toolchain
- If any test fails, stops immediately with the failure output
- If any task is still `[ ]`, lists them and stops
- The ai-learning reminder is a prompt, not a gate — but skipping it defeats cross-session memory
