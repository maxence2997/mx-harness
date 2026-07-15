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
  Scope       ──▶  Plan audit: order, split, complexity (inline)
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

Scope analysis is a plan audit, run inline in the parent — by the end of planning the spec, plan, and relevant code are already in its context, and dispatching a sub-agent to rebuild that from disk proved slower. Targeted lookups ground every task in real files and symbols, then the audit fixes the plan where the split is wrong: forward dependencies get reordered, tasks hiding several behaviors get split, overlapping tasks get merged or explicitly ordered, and vague tasks get rewritten (max 2 passes, then conservative defaults). The audited metadata (predicted files, dependencies, complexity S/M/L) lands in `.mx/<name>/scope.yaml`, which Phase 5 reads per task as advisory context. Execution itself is strictly serial in the parent: parallel task sub-agents were removed 2026-07-15 — each one rebuilt context the parent already had, multiplied machine costs (per-worktree setup, test suites contending for the same cores), and their failure paths (merge conflicts, integration failures) re-ran tasks sequentially anyway.

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
- Branch-specific procedures live in `references/` (finish phase); the
  content check's canonical copy is `mx-pr/references/content-check.md`
- Sub-agent model choice, escalation after repeated failures, and
  verification rules come from the sibling [mx-doctrine](../mx-doctrine/)
  skill
