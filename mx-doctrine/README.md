# mx-doctrine

Shared execution doctrine for the mx-* skill suite. The other skills
(mx-flow, mx-team-review, mx-pr, …) reference these files at the moments
they matter: before dispatching a sub-agent, after repeated failures,
before declaring work done, before editing the harness itself.

## What's inside

| File | Contents |
|---|---|
| [references/model-dispatch.md](references/model-dispatch.md) | Which model tier does what; commander-doesn't-descend rules; the delegation contract; verification-is-never-self-verification; the escalation/de-escalation ladder with its counting rule |
| [references/judgment-rubrics.md](references/judgment-rubrics.md) | Checklists with ✅/❌ examples: when to escalate, when "done" is real, when to stop and ask the user, wrong-direction signals, the quality floor per change type, honest limits of process |
| [references/delegation-templates.md](references/delegation-templates.md) | Fill-in-the-blank sub-agent prompts: search, implement, refactor, research, review, plus a read-back verification stub and the shared report contract |
| [references/maintenance.md](references/maintenance.md) | How to update mx-harness safely: repo vs installed copies, what may change autonomously vs needs the user, lesson write-back format, compaction triggers |
| [references/diagnosis.md](references/diagnosis.md) | The measured 2026-07-07 diagnosis (token leaks, focus risks, error sources) that motivated the current structure, plus a 60-second re-audit procedure |

## Why it exists

These rules were distilled by a frontier-model session (2026-07-07) into a
form weaker models can execute: concrete triggers, procedures, budgets, and
worked examples — no "use good judgment" hand-waving. They travel with the
skills so every installed machine gets the same institution.

## Invocation

```
/mx-doctrine              # summary of what doctrine exists
/mx-doctrine escalation   # read + apply the matching file(s)
```

Everything user-tunable lives under `references/` — `install.sh` preserves
your local edits there (hash lock), while SKILL.md is always updated from
the repo.
