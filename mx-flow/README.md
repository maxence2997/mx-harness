# mx-flow

> You make a few decisions. The agent handles the rest.

Full development workflow orchestrator. One command to run the entire process from idea to verified, committable code.

## Usage

```
/mx-flow <topic>
/mx-flow --gated <topic>
```

_Rough or detailed — the agent will ask what it needs._

### Gated mode

Add `--gated` for full human control at all 4 gates. By default, mx-flow only requires spec approval — task list, triage, and PR all auto-proceed (reports are still shown for visibility).

## What it runs

```
  Brainstorm  ──▶  Design spec + ADR          [GATE: spec approval]
  Plan        ──▶  Ordered task list
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

  Verify      ──▶  Full suite + plan checklist
  PR          ──▶  Draft → review → publish
  Finish      ──▶  Clean up branch + worktree
```

## Human decision gates

mx-flow pauses at key points where your judgement matters. Between gates, it runs automatically.

| Gate | When | Default | Gated |
|------|------|---------|-------|
| Spec approval | After brainstorm | Human | Human |
| Task list approval | After planning | Auto | Human |
| Triage approval | After each review cycle | Auto | Human |
| PR review | Before publishing | Auto* | Human |

\* Agent pauses only if it cannot determine how to proceed (no remote, ambiguous platform, etc.)

## Convergent loop safety limit

The tdd → review → triage cycle runs a maximum of **3 iterations**. If findings are still unresolved after 3 rounds, mx-flow escalates and presents three options:

- **Continue** — extend the loop manually
- **Redesign** — return to the spec; the findings indicate a design problem
- **Abort** — discard the branch and start fresh

Three unresolved iterations almost always signal a design issue, not a code issue.

## Example

```
/mx-flow add Redis caching to the search endpoint
/mx-flow --gated add Redis caching to the search endpoint
```

**Brainstorm** — Agent asks one question at a time: Redis or in-memory? TTL strategy? Invalidation scope? Then writes a design spec and ADR, and waits for your approval.

**Plan** — Decomposes the spec into ordered tasks: cache interface, Redis adapter, handler wiring, integration test.

**Worktree** — Creates an isolated branch and worktree under `~/.mx/<project>/<name>/worktree/`, runs baseline tests to confirm a clean starting point.

**TDD loop** — For each task: writes a failing test, implements the minimum to pass, refactors, and commits with a structured message.

**Review** — Three perspectives weigh in on the full diff:

```
Senior Engineer:   "Cache key not normalised — case mismatch will miss."
SRE:               "No fallback if Redis is down."
Future Maintainer: "Document why TTL=300."
```

**Triage** — Findings are sorted into fix / track / skip. Fixes loop back to TDD. Clean results move on to Verify.

**Verify → PR** — Full test suite passes, plan checklist complete, PR drafted and published.

By default, the agent decides what to fix and publishes the PR automatically. Use `--gated` if you want to approve each step.

## Notes

- Default mode auto-publishes the PR. Use `--gated` for manual control
- After merge: run `/mx-finish <name>` to clean up
