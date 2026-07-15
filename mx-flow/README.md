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
  Brainstorm  ──▶  Design spec + ADR
  Plan        ──▶  Ordered task list
  Scope       ──▶  Per-task files + complexity DAG (inline)
  Worktree    ──▶  Isolated branch + baseline pass

  ┌─ convergent loop (max 3 iterations) ────────────┐
  │                                                 │
  │  ┌─ per task ────────────────────────┐          │
  │  │  TDD       red → green → refactor │          │
  │  │  Commit    one structured commit  │          │
  │  └──────────────────────────────────-┘          │
  │                                                 │
  │  Review      3-perspective code review          │
  │  Triage      fix / track / skip                 │
  │                                                 │
  │  ↺  fixes? → TDD + Commit → Review + Triage     │
  │  ✔  clean? → exit loop                          │
  └─────────────────────────────────────────────────┘

  Verify      ──▶  Tests + plan + content check (cancel + squash, autonomous)
  PR          ──▶  Draft → review → publish
  Finish      ──▶  Clean up branch + worktree
```

Plan, Scope, Worktree, TDD, Verify, and Finish are built-in mx-flow phases. Brainstorm,
Review + Triage, and PR delegate to standalone skills (/mx-brainstorm,
/mx-team-review + /mx-review-triage, /mx-pr).

Scope analysis runs inline in the parent — by the end of planning the spec, plan, and relevant code are already in its context, and dispatching a sub-agent to rebuild that from disk proved slower. Targeted lookups confirm each task's files, and the resulting per-task metadata (predicted files, dependencies, complexity S/M/L, and a derived `parallelizable` flag) is written to `.mx/<name>/scope.yaml`. Phase 5 consumes this metadata directly: tasks marked `parallelizable: true` are dispatched concurrently — each sub-agent gets its own isolated git worktree (via the Agent tool's `isolation: "worktree"`), runs a full TDD cycle including `/mx-commit`, and the parent cherry-picks the resulting commits back in `task_id` order. Trivial cherry-pick conflicts (additive only) are auto-resolved by the parent; non-trivial conflicts bounce the task to the sequential queue (already-landed tasks stay). The `parallelizable` flag fires only when `total_tasks >= 3 AND depends_on == [] AND complexity in {M, L}` — small plans and S-sized work stay sequential because the worktree spin-up overhead exceeds the wall-clock savings.

## File locations

mx-flow stores files in two places:

| Location | Contains | Lifecycle |
|----------|----------|-----------|
| `~/.mx/<project>/<name>/` | spec.md, adr.md | Permanent — survives cleanup |
| `.mx/<name>/` (project root) | plan.md, scope.yaml, worktree/, tmp/ | Ephemeral — cleaned by `/mx-flow finish` |

`.mx/` is automatically added to `.gitignore` on first run.

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

**Verify → PR** — Full test suite passes, plan checklist complete, content check autonomously cleans up review-iteration noise (Pass 1 removes mutually-cancelling changes; Pass 2 squashes fixups into parents; both tree-invariant guarded), PR drafted and published.

```
/mx-flow finish search-cache
```

**Finish** — After the PR is merged: deletes the plan, clears tmp files, removes the worktree and branch. Design spec and ADRs are preserved permanently.

## Notes

- Default mode auto-publishes the PR
- After merge: run `/mx-flow finish <name>` to clean up
- `.mx/` directory is gitignored automatically
- Branch-specific procedures live in `references/` (parallel dispatch,
  finish phase); the content check's canonical copy is
  `mx-pr/references/content-check.md`
- Sub-agent model choice, escalation after repeated failures, and
  verification rules come from the sibling [mx-doctrine](../mx-doctrine/)
  skill
