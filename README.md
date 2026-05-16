# mx-harness

> Your AI agent writes fast. mx-harness makes it engineer properly.

![License](https://img.shields.io/badge/license-MIT-blue)
![Works with](https://img.shields.io/badge/works%20with-GitHub%20Copilot%20%7C%20Cursor%20%7C%20Claude-blueviolet)

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
/mx-flow finish search-cache                # post-merge cleanup
```

[How it works →](mx-flow/)

### Standalone skills

These skills also run inside `mx-flow`, but you can use them independently anytime:

| Skill                                  | Description                                                         |
| -------------------------------------- | ------------------------------------------------------------------- |
| [mx-brainstorm](mx-brainstorm/)       | Turn a rough idea into an approved design spec (with ADR)           |
| [mx-team-review](mx-team-review/)     | 3-perspective code review — Senior Engineer, SRE, Future Maintainer |
| [mx-review-triage](mx-review-triage/) | Triage review findings into fix / track / skip buckets              |
| [mx-commit](mx-commit/)               | Structured commit with enforced message format                      |
| [mx-pr](mx-pr/)                       | Draft, review, and publish a PR to GitHub / GitLab / Bitbucket      |
| [mx-status](mx-status/)               | Show current stage, progress, and next action for all features      |

---

## Installation

**Install or update a single skill:**

```bash
# bash / zsh
npx skills add https://github.com/maxence2997/mx-harness --skill <skill-name> -g -y
```

**Install or update everything at once:**

```bash
# bash / zsh — auto-discovers all mx-* skills
curl -s https://api.github.com/repos/maxence2997/mx-harness/contents \
  | grep '"name"' | grep -o '"mx-[^"]*"' | tr -d '"' \
  | xargs -I{} npx skills add https://github.com/maxence2997/mx-harness --skill {} -g -y
```

```powershell
# PowerShell
(Invoke-RestMethod "https://api.github.com/repos/maxence2997/mx-harness/contents") |
  Where-Object { $_.name -like "mx-*" } |
  Select-Object -ExpandProperty name |
  ForEach-Object {
    npx skills add https://github.com/maxence2997/mx-harness --skill $_ -g -y
  }
```

> **If you cloned the repo directly:** `git pull` is all you need — your symlinks already point to the repo.

---

## License

MIT
