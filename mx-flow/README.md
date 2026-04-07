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
mx-brainstorm  →  [GATE: spec approval]     ← human
mx-plan                                      ← auto
mx-worktree
  loop:
    mx-tdd → mx-commit (per task)
    mx-team-review → mx-review-triage        ← auto
    → fixes? back to loop
    → clean? exit loop
mx-verify → mx-commit
mx-pr                                        ← auto
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

## Individual skills

Each skill in the flow can also be used standalone:

| Skill | Use when |
|-------|----------|
| `/mx-brainstorm` | Just need a spec, not the full flow |
| `/mx-plan` | Already have a spec, need tasks |
| `/mx-worktree` | Need an isolated workspace |
| `/mx-tdd` | Already planned, working task by task |
| `/mx-team-review` | Want a code review at any point |
| `/mx-review-triage` | Have review findings to triage |
| `/mx-verify` | Final check before commit |
| `/mx-commit` | Structured commit message |
| `/mx-finish` | Clean up after PR is merged |

## Example

```
/mx-flow add Redis caching to the search endpoint
/mx-flow --gated add Redis caching to the search endpoint
```

Agent asks one question at a time — Redis or in-memory? TTL? Invalidation scope? —
then writes a design spec and ADR, and waits for your approval.

After approval, it decomposes into tasks, creates an isolated branch, and runs
red → green → refactor for each task. At the milestone, three reviewers weigh in:

```
Senior Engineer:   "Cache key not normalised — case mismatch will miss."
SRE:               "No fallback if Redis is down."
Future Maintainer: "Document why TTL=300."
```

By default, the agent decides what to fix and publishes the PR automatically. Use `--gated` if you want to approve each step.

## Notes

- Default mode auto-publishes the PR. Use `--gated` for manual control
- After merge: run `/mx-finish <name>` to clean up
