# mx-harness

> Your AI agent writes fast. mx-harness makes it engineer properly.

![License](https://img.shields.io/badge/license-MIT-blue)
![Works with](https://img.shields.io/badge/works%20with-Claude%20%7C%20Codex%20%7C%20Copilot%20%7C%20Cursor-blueviolet)

---

## What it looks like

Once installed, you tell the agent your idea — rough or detailed, it asks what it needs.

```
/mx-flow add Redis caching to the search endpoint
```

You make a few decisions. The agent handles the rest. [Full walkthrough →](mx-flow/)

---

## Principles

Without a harness, AI agents skip planning, skip tests, and produce unmaintainable diffs. mx-harness wraps the lifecycle into skills the agent must follow.

| Principle                    | Addresses                                           |
|------------------------------|-----------------------------------------------------|
| **Spec before code**         | Vague requirements, hidden assumptions, scope creep |
| **Test-first**               | Tests written after the fact, missed edge cases     |
| **Multi-perspective review** | Single-reviewer blind spots, missed SRE concerns    |
| **Structured commits**       | "fix stuff" messages, mixed concerns per commit     |
| **Surgical changes**         | Drive-by edits, inflated diffs, unrelated refactors |
| **Don't assume**             | Silent guessing on ambiguous specs                  |

---

## The difference

**Without mx-harness**

```
User:  "Add caching to the search endpoint"
Agent: [writes 200 lines of code]
       [commit: "add cache"]
       [no tests · no design doc · breaks 2 existing behaviours]
```

**With mx-harness**

```
User:  /mx-flow "Add caching to the search endpoint"
Agent: → Asks: Redis or in-memory? TTL strategy? Cache invalidation scope?
       → Writes design spec + ADR to ~/.mx/project/search-cache/
       → Waits for approval before touching any code

       → Task 1: Cache interface (testable abstraction)
       → Task 2: Redis adapter
       → Task 3: Wire into search handler
       → Task 4: Integration test with mock Redis

       [each task: red → green → refactor → structured commit]

       → Senior Engineer:     "Cache key includes user locale? Edge case."
       → SRE:                 "No TTL cap — potential memory leak under load."
       → Future Maintainer:   "Document why TTL=300 was chosen."
```

The first scenario is something most engineers have lived through. The second is what mx-harness locks in by default.

---

## Skills

### `/mx-flow` — the full pipeline

One command in. A few decisions from you. PR out.

```
/mx-flow add Redis caching to the search endpoint
/mx-flow status [name]                      # where every feature stands, next command
/mx-flow finish search-cache                # post-merge cleanup
```

[How it works →](mx-flow/)

### Standalone skills

Most of these also run inside `mx-flow`; all of them work standalone.

| Skill                                  | Description                                                         |
| -------------------------------------- | ------------------------------------------------------------------- |
| [mx-brainstorm](mx-brainstorm/)       | Turn a rough idea into an approved design spec (ADR when a real choice was made) |
| [mx-team-review](mx-team-review/)     | Standards-based 3-perspective code review (Go, C#) — Senior Engineer, SRE, Future Maintainer |
| [mx-review-triage](mx-review-triage/) | Triage review findings into fix / track / skip buckets              |
| [mx-commit](mx-commit/)               | Structured commit with enforced message format                      |
| [mx-pr](mx-pr/)                       | Draft, review, and publish a PR to GitHub / GitLab (Bitbucket experimental) |
| [mx-doctrine](mx-doctrine/)           | Shared execution doctrine: model dispatch, escalation, verification, judgment rubrics |

---

## Installation and updates

Installation contract updated 2026-11-21.

`install.sh` keeps one real copy of each skill in `~/.agents/skills/<skill>/`, which Codex reads directly. It creates a link for each skill in the following locations when the corresponding agent home exists:

- Claude Code: `~/.claude/skills/`, including existing legacy installs under `~/.config/claude/skills/`
- Codex: `~/.codex/skills/` (compatibility links)
- GitHub Copilot: `~/.copilot/skills/`
- Cursor: `~/.cursor/skills/`

**Install a release** (it then [updates itself](#automatic-updates)):

```bash
curl -fsSL --retry 3 https://github.com/maxence2997/mx-harness/archive/refs/heads/main.tar.gz | tar -xz -C /tmp && bash /tmp/mx-harness-main/install.sh --ref v1.1.0
```

Any `v1` tag from v1.1.0 on works; the first skill run moves the install to the newest `v1` release. Tags are listed on the [tags page](https://github.com/maxence2997/mx-harness/tags).

Requires Bash 3.2+ and standard Unix utilities, including `sha256sum` or `shasum`. Downloading also requires `curl`, `tar`, and `gzip`. Node.js and Python are not installer dependencies. Inspect [install.sh](install.sh) before running it if desired.

**Install unreleased `main` instead** (never updates itself), after downloading the script above:

```bash
bash /tmp/mx-harness-main/install.sh --remote
```

Append skill names to either command to install a subset, for example `--remote mx-flow mx-pr`; an [automatic update](#automatic-updates) installs the full suite.

**From a clone:** `./install.sh` installs or updates from the working tree; `./install.sh --remote` fetches GitHub `main` and `./install.sh --ref vX.Y.Z` fetches that release instead. Append skill names to select a subset. The lock's `_meta source` row records the source commit or path. A working-tree install is a development install and never updates itself.

After installing or updating by hand, start a new Claude Code or Codex session to load the current skill files.

### Versions

Releases are git tags `vX.Y.Z` on `main`; the whole suite shares one version because the skills call each other (for example `/mx-flow` hands off to `/mx-pr`). There is no `VERSION` file — the tag is the only source of truth.

| Bump | When |
|---|---|
| Major | A user must change something: a skill is renamed or removed, a command's arguments change incompatibly, `~/.mx/` or `.mx/` paths or file formats change, or the installer contract changes in a way that needs action |
| Minor | Backward-compatible additions: a new skill, subcommand, flag, or behavior |
| Patch | Prompt wording, bug fixes, and docs that change no interface |

To release, tag a commit on `main` that passes the [installer checks](#installer-checks) and push the tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.

To see what is installed: `grep '^_meta' ~/.mx/.mx-harness.lock`. The `version` row is the tag for `--ref` installs, `main` for `--remote`, `git describe` output for a clone (`v1.0.0`, `v1.0.0-3-g<sha>` for commits after a tag, `-dirty` for uncommitted changes to tracked files), or `unknown` for a downloaded `main` archive.

### Automatic updates

Release installs (`--ref`) update themselves: every skill run first checks GitHub for a newer release with the same major version and installs it, which may take a few seconds.

- Local edits under `references/` are kept ([hash lock rules](#updates-and-migration)). The skill tells you when it updated and names any path it moved to `~/.mx/backups/`.
- A new major version is never installed automatically, because it needs manual steps (see [Versions](#versions)).
- If GitHub can't be reached or the update fails, the skill carries on and the next skill run tries again.
- Installs from `main` or from a working tree never update themselves.
- Codex's sandbox blocks network access by default, so Codex skills update only when another agent or a manual install updates the shared copy.
- Automatic updates are on by default. To turn them off, set `MX_HARNESS_AUTO_UPDATE` to `0`, `false` or `off` in the environment your agent starts from, such as your shell profile.

### Updates and migration

The hash lock at `~/.mx/.mx-harness.lock` protects customizations under `references/`:

- `SKILL.md` and `README.md` are refreshed from the selected source. Keep local customizations under `references/`.
- A reference file is updated when its installed hash matches the recorded baseline. A differing local file is preserved, including when no baseline is known.
- When several installations contain local edits to the same reference, one distinct edited version is retained with its previous baseline. Conflicting edited versions stop that skill's migration before its active installations change; reconcile the reported file and rerun.

During migration, existing real directories and individual skill symlinks that need replacement, including links into a development checkout, are moved to `~/.mx/backups/` before their agent paths are linked to the canonical copy. Backing up a symlink moves the link itself; its checkout target is never overwritten. Canonical skill symlinks and symlinks inside a canonical skill are materialized as ordinary directories and files before updating. A custom installation path recorded in the lock is also migrated before its lock root changes.

An agent's whole `skills` directory may already link to `~/.agents/skills`. Other parent symlinks, such as `~/.claude/skills` pointing into a checkout, fail the path check before that skill is changed; use individual skill links instead.

Skills the lock records but the repo no longer ships are reported. Add `--prune` to remove them: real directories are backed up and links to retired installations are removed. A failed removal returns a nonzero exit status and retains the skill's lock entries for a later retry.

> [`npx skills add maxence2997/mx-harness`](https://github.com/vercel-labs/skills) is an alternative installer, but it bypasses this hash lock and its customization-preservation rules.

### Installer checks

Run the isolated filesystem fixtures with Python 3's standard library:

```bash
bash -n install.sh
python3 -m unittest discover -s tests -v
```

Python is required only for these tests. They exercise installation and update behavior without changing the real agent skill directories.

---

## License

MIT
