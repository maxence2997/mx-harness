# mx-harness

A collection of user-invocable agent skills (slash commands) that wrap the engineering lifecycle: spec → plan → TDD → review → commit → PR. Not an app. Nothing to build, nothing to test in the runtime sense.

## Repo layout

Each top-level directory is **one skill**. The contract per skill:

```
<skill>/
  SKILL.md           # required — the prompt the agent loads
  README.md          # required — human-facing docs
  references/        # optional — supporting files referenced from SKILL.md
```

`SKILL.md` frontmatter schema (all current skills follow this):

```yaml
name: <slug>                                    # must match dir name
description: >                                  # multi-line, used for skill discovery
  ...
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/<slug>
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
```

The `source:` field is load-bearing — `install.sh` and downstream tooling read it. Don't drop it when editing frontmatter.

## When you change a skill

Three places must stay in sync — change them together or the repo lies:

1. **`<skill>/SKILL.md`** — the actual change
2. **`<skill>/README.md`** — user-facing "what it does" list
3. **`README.md`** (root) — skills table, if the one-liner changed

When **adding** a new skill, also append it to `install.sh`'s `SKILLS=(...)` array (line ~25) or it won't ship.

## `install.sh` behavior — don't break the lock

`install.sh` uses a hash-based lock at `~/.mx/.mx-harness.lock` so re-running it preserves user customizations:

- `SKILL.md` and `README.md` → **always overwritten** (treat as canonical from the repo)
- `references/*` → only overwritten if the file's current hash matches the recorded hash (i.e. the user hasn't edited it locally)

This means: **never put user-tunable content in SKILL.md or README.md**. Templates, prompts, and anything the user might customize go under `references/`. Putting user-editable content in the top two files will silently clobber their changes on next install.

## Path conventions used inside skills

Skills coordinate via two parallel directory trees. If you're editing a skill that touches the filesystem, follow this convention rather than inventing a new path:

| Variable | Path | Lifetime |
|---|---|---|
| `GLOBAL_MX` | `~/.mx/<project>/<name>/` | Permanent — specs, ADRs, brag entries |
| `LOCAL_MX` | `<repo-root>/.mx/<name>/` | Ephemeral — plans, tmp drafts, gitignored |

Resolve them with:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$REPO_ROOT")
```

## Commit style

Match the existing log (`git log --oneline`). Format: `type(scope): subject` or `type: subject`. Types in use: `feat`, `fix`, `doc`, `refactor`. Subject is lowercase, no trailing period, under ~60 chars. Body (when needed) explains *why* in prose, not bullet points.

## What this repo is NOT

- Not a Go/TS/Python project — no `go test`, no `npm test`, no CI gates to satisfy beyond the install script staying runnable
- Not a place for code reviews of application code — the skills *do* code review; the repo itself is prompts and docs
- Not auto-versioned — there's no `VERSION` file or release pipeline; users install from `main` via `install.sh`
