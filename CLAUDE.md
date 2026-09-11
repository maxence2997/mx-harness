# mx-harness

A collection of user-invocable agent skills (slash commands) that wrap the engineering lifecycle: spec → plan → TDD → review → commit → PR. Not an app. The Bash installer has isolated filesystem regression tests; see the checks below.

## Before editing anything here

Read `mx-doctrine/references/maintenance.md` first — it defines what you may change autonomously vs. what needs the user, the lesson write-back format, and the compaction triggers. `mx-doctrine/references/diagnosis.md` records why the suite is structured this way (2026-07-07 restructure) and includes a 60-second re-audit procedure. Two rules worth restating even here: keep every SKILL.md `description:` ≤ 50 words (it loads into every session on every installed machine), and never state the same rule in two places — point at the canonical copy instead.

## Repo layout

Each top-level `mx-*` directory is **one skill**; `tests/` holds installer regression fixtures. The contract per skill:

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

When **adding** a new skill, also append it to `install.sh`'s `SKILLS=(...)` array or it won't ship. When **removing** one, drop it from that array and delete its directory; installed copies are reported as "no longer shipped" on the next `install.sh` run and handled by `install.sh --prune` under the [migration and removal contract](README.md#updates-and-migration).

## `install.sh` behavior — don't break the lock

The canonical installation and update contract is [README.md — Updates and migration](README.md#updates-and-migration), updated 2026-09-11. Read it before changing the installer. It covers the shared copy, agent links, custom reference reconciliation, checkout protection, legacy path migration, and prune failures.

Keep user-tunable templates and prompts under `references/`; the contract treats `SKILL.md` and `README.md` as repository-owned files. Source selection and supported destinations are documented in [Installation and updates](README.md#installation-and-updates).

Installer changes must pass `bash -n install.sh` and `python3 -m unittest discover -s tests -v`. Python 3 is test-only; keep the installer runnable with Bash 3.2 and standard Unix utilities.

## Path conventions used inside skills

Skills coordinate via two parallel directory trees. If you're editing a skill that touches the filesystem, follow this convention rather than inventing a new path:

| Variable | Path | Lifetime |
|---|---|---|
| `GLOBAL_MX` | `~/.mx/<project>/<name>/` | Permanent — specs, ADRs |
| `LOCAL_MX` | `<repo-root>/.mx/<name>/` | Ephemeral — plans, tmp drafts, gitignored |

Resolve them with:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$REPO_ROOT")
```

## Commit style

Match the existing log (`git log --oneline`). Format: `type(scope): subject` or `type: subject`. Types in use: `feat`, `fix`, `doc`, `refactor`. Subject is lowercase, no trailing period, under ~60 chars. Body (when needed) explains *why* in prose, not bullet points.

## What this repo is NOT

- Not a Go/TS/Python application — no application build; the Bash installer is covered by the Python standard-library tests above
- Not a place for code reviews of application code — the skills *do* code review; the repo itself is prompts and docs
- Not auto-versioned — there's no `VERSION` file or release pipeline; users install from `main` via `install.sh`
