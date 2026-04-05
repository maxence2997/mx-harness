# mx-pr

Draft a pull/merge request from the feature spec and git log, review it, then publish — or skip.

## Usage

```
/mx-pr <name>   # draft PR for named feature
/mx-pr          # infer from active spec or ask
```

## What it does

1. Reads `~/.mx/<project>/<name>/spec.md` and the git log since branch creation
2. Drafts a structured PR description
3. Saves draft to `~/.mx/<project>/<name>/tmp/pr-draft-<timestamp>.md` (timestamp prevents collisions)
4. Shows you the draft — you decide to proceed or edit first
5. Asks which platform to publish to
6. Publishes (or lets you handle it manually)
7. Leaves draft in `~/.mx/<project>/<name>/tmp/` — cleaned up by `/mx-finish`

## Platforms supported

| Platform | CLI used |
|----------|----------|
| GitHub | `gh pr create` |
| GitLab | `glab mr create` |
| Bitbucket | `bb pr create` |
| Other / Manual | Shows draft, you handle it |
| Skip | Don't publish now |

## PR draft format

| Section | Source |
|---------|--------|
| Summary | Spec — What and How |
| Motivation | Spec — Why |
| Changes | Git log since branch start |
| Test plan | `~/.mx/<project>/<name>/plan.md` tasks |
| Notes | Optional follow-ups or trade-offs |

## Notes

- Run after `/mx-verify` passes and the branch is pushed
- Draft is never deleted on failure — you can recover and retry
- After merge: run `/mx-finish <name>` to clean up
