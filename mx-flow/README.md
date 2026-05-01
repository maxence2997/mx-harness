# mx-flow

> You make a few decisions. The agent handles the rest.

Full development workflow orchestrator. One command to run the entire process from idea to verified, committable code.

## Usage

```
/mx-flow <topic>          # full pipeline: idea to PR
/mx-flow finish <name>    # post-merge cleanup
```

_Rough or detailed — the agent will ask what it needs._

## What it runs

```
  Phase 1  Brainstorm  ──▶  Design spec + ADR     [GATE: spec approval]
  Phase 2  Plan        ──▶  Ordered task list
  Phase 3  Worktree    ──▶  Isolated branch + baseline pass

  ┌─ convergent loop (max 3 iterations) ────────────┐
  │                                                 │
  │  ┌─ per task ────────────────────────┐          │
  │  │  Phase 4a  TDD    red → green → refactor │   │
  │  │            Commit one structured commit  │   │
  │  └──────────────────────────────────-┘          │
  │                                                 │
  │  Phase 4b  Review   3-perspective code review   │
  │            Triage   fix / track / skip          │
  │                                                 │
  │  ↺  fixes? → TDD + Commit → Review + Triage     │
  │  ✔  clean? → exit loop                          │
  └─────────────────────────────────────────────────┘

  Phase 5  Verify      ──▶  Full suite + plan checklist
  Phase 6  PR          ──▶  Draft → review → publish
  Phase 7  Finish      ──▶  Clean up branch + worktree (post-merge)
```

Phases 2, 3, 4a, 5, and 7 are built-in. Phases 1, 4b, and 6 delegate to standalone skills
(/mx-brainstorm, /mx-team-review + /mx-review-triage, /mx-pr).

## File locations

mx-flow stores files in two places:

| Location | Contains | Lifecycle |
|----------|----------|-----------|
| `~/.mx/<project>/<name>/` | spec.md, adr.md | Permanent — survives cleanup |
| `.mx/<name>/` (project root) | plan.md, worktree/, tmp/ | Ephemeral — cleaned by `/mx-flow finish` |

`.mx/` is automatically added to `.gitignore` on first run.

## Human decision gates

mx-flow pauses at key points where your judgement matters. Between gates, it runs automatically.

| Gate | When | Behaviour |
|------|------|-----------|
| Spec approval | After brainstorm | Human — requires explicit approval |
| Task list | After planning | Auto — shown for visibility |
| Triage | After each review cycle | Auto — fixes executed immediately |
| PR | Before publishing | Auto — pauses only if stuck |

## Convergent loop safety limit

The TDD → review → triage cycle runs a maximum of **3 iterations**. If findings are still unresolved after 3 rounds, mx-flow escalates and presents three options:

- **Continue** — extend the loop manually
- **Redesign** — return to the spec; the findings indicate a design problem
- **Abort** — discard the branch and start fresh

Three unresolved iterations almost always signal a design issue, not a code issue.

## Example

```
/mx-flow add Redis caching to the search endpoint
```

**Brainstorm** — Agent asks one question at a time: Redis or in-memory? TTL strategy? Invalidation scope? Then writes a design spec and ADR to `~/.mx/<project>/search-cache/`, and waits for your approval.

**Plan** — Decomposes the spec into ordered tasks: cache interface, Redis adapter, handler wiring, integration test. Plan saved to `.mx/search-cache/plan.md`.

**Worktree** — Creates an isolated branch and worktree at `.mx/search-cache/worktree/`, runs baseline tests to confirm a clean starting point.

**TDD loop** — For each task: writes a failing test, implements the minimum to pass, refactors, and commits with a structured message.

**Review** — Three perspectives weigh in on the full diff:

```
Senior Engineer:   "Cache key not normalised — case mismatch will miss."
SRE:               "No fallback if Redis is down."
Future Maintainer: "Document why TTL=300."
```

**Triage** — Findings are sorted into fix / track / skip. Fixes loop back to TDD. Clean results move on to Verify.

**Verify → PR** — Full test suite passes, plan checklist complete, PR drafted and published.

```
/mx-flow finish search-cache
```

**Finish** — After the PR is merged: deletes the plan, clears tmp files, removes the worktree and branch. Design spec and ADRs are preserved permanently.

## Notes

- Default mode auto-publishes the PR
- After merge: run `/mx-flow finish <name>` to clean up
- `.mx/` directory is gitignored automatically
