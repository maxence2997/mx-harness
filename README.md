# mx-skills

> Your AI agent writes fast. mx-skills makes it engineer properly.

![License](https://img.shields.io/badge/license-MIT-blue)
![Works with](https://img.shields.io/badge/works%20with-GitHub%20Copilot%20%7C%20Cursor%20%7C%20Claude-blueviolet)
![Stars](https://img.shields.io/github/stars/maxence2997/skills)
![Last commit](https://img.shields.io/github/last-commit/maxence2997/skills)
![Forks](https://img.shields.io/github/forks/maxence2997/skills)

---

## See it in action

Just tell the agent your idea — rough or detailed, it will ask what it needs.

```
/mx-flow add Redis caching to the search endpoint
```

Brainstorm → spec approval → plan approval → TDD loop → review → triage → verify → PR.  
You make a few decisions. The agent handles the rest. [Full walkthrough →](mx-flow/)

---

## Why?

mx-skills is the engineering harness your agent is missing.

Left unchecked, AI agents skip planning, skip tests, and produce unmaintainable diffs. Every session you end up reminding it: write the design doc first, follow TDD, fix the commit message, check the SRE angle...

Plan Mode helps — but it only covers the beginning. What comes after — how to write tests, who reviews, what the commit looks like, how to clean up after merge — it doesn't handle any of that.

mx-skills wraps the entire lifecycle into a set of skills the agent is forced to follow:

- **Spec before code** — brainstorm and lock down a design doc before any implementation
- **Test-first** — every task follows red → green → refactor
- **Multi-perspective review** — Senior Engineer, SRE, and Future Maintainer weigh in before merge
- **Structured commits** — no more "fix stuff" messages

---

## The difference

**Without mx-skills**

```
User:  "Add caching to the search endpoint"
Agent: [writes 200 lines of code]
       [commit: "add cache"]
       [no tests · no design doc · breaks 2 existing behaviours]
```

**With mx-skills**

```
User:  /mx-brainstorm "Add caching to the search endpoint"
Agent: → Asks: Redis or in-memory? TTL strategy? Cache invalidation scope?
       → Writes design spec + ADR to ~/.mx/project/search-cache/
       → Waits for approval before touching any code

User:  /mx-plan
Agent: → Task 1: Cache interface (testable abstraction)
       → Task 2: Redis adapter
       → Task 3: Wire into search handler
       → Task 4: Integration test with mock Redis
       → Waits for task list approval

       [each task: red → green → refactor → structured commit]

User:  /mx-team-review
Agent: → Senior Engineer:     "Cache key includes user locale? Edge case."
       → SRE:                 "No TTL cap — potential memory leak under load."
       → Future Maintainer:   "Document why TTL=300 was chosen."
```

The first scenario is something most engineers have lived through. The second is what mx-skills locks in by default.

---

## Skills

### Workflow

| Skill                           | Description                                                               |
| ------------------------------- | ------------------------------------------------------------------------- |
| [mx-flow](mx-flow/)             | Full pipeline orchestrator — idea to verified commit                      |
| [mx-brainstorm](mx-brainstorm/) | Turn a rough idea into an approved design spec (with ADR auto-recorded)   |
| [mx-plan](mx-plan/)             | Decompose a spec into a concrete, ordered task list                       |
| [mx-worktree](mx-worktree/)     | Create an isolated git worktree with baseline verification                |
| [mx-tdd](mx-tdd/)               | Implement one task: red → green → refactor → commit (one commit per task) |
| [mx-verify](mx-verify/)         | Final gate: full test suite + plan checklist before push                  |
| [mx-pr](mx-pr/)                 | Draft, review, and publish a PR to GitHub / GitLab / Bitbucket            |
| [mx-finish](mx-finish/)         | Post-merge cleanup — plan files, review reports, worktree, branch         |

### Review

| Skill                                  | Description                                                         |
| -------------------------------------- | ------------------------------------------------------------------- |
| [mx-team-review](mx-team-review/)      | 3-perspective code review — Senior Engineer, SRE, Future Maintainer |
| [mx-review-triage](mx-review-triage/) | Triage review findings into fix / track / skip buckets              |

### Commit

| Skill                   | Description                                                      |
| ----------------------- | ---------------------------------------------------------------- |
| [mx-commit](mx-commit/) | Commit staged changes with a structured, enforced message format |

---

## How It Fits Together

Use `/mx-flow` to run the full pipeline automatically, or invoke each skill individually for more control:

```
/mx-brainstorm   ──▶  idea → approved design spec + ADR  (~/.mx/<project>/<name>/)
/mx-plan         ──▶  spec → task list            (~/.mx/<project>/<name>/plan.md)
/mx-worktree     ──▶  isolated branch + baseline test pass

  ┌─ loop (one iteration per task) ──────────────────────────────┐
  │  /mx-tdd              red → green → refactor                 │
  │  /mx-commit           structured commit for this task        │
  │  (milestone reached)                                         │
  │  /mx-team-review      3-perspective code review              │
  │  /mx-review-triage    fix / track / skip                     │
  │  ↺  fixes? → back to mx-tdd + mx-commit                     │
  └──────────────────────────────────────────────────────────────┘

/mx-verify       ──▶  full suite + checklist + learning note
/mx-pr           ──▶  draft PR → review → publish (GitHub/GitLab/Bitbucket)

── after PR merge ─────────────────────────────────────────────
/mx-finish                      clean up and close out the branch
```

---

## Quickstart

**Install or update a single skill:**

```bash
# bash / zsh
npx skills add https://github.com/maxence2997/skills --skill <skill-name> -g -y
```

**Install or update everything at once:**

```bash
# bash / zsh — auto-discovers all mx-* skills
curl -s https://api.github.com/repos/maxence2997/skills/contents \
  | grep '"name"' | grep -o '"mx-[^"]*"' | tr -d '"' \
  | xargs -I{} npx skills add https://github.com/maxence2997/skills --skill {} -g -y
```

```powershell
# PowerShell
(Invoke-RestMethod "https://api.github.com/repos/maxence2997/skills/contents") |
  Where-Object { $_.name -like "mx-*" } |
  Select-Object -ExpandProperty name |
  ForEach-Object {
    npx skills add https://github.com/maxence2997/skills --skill $_ -g -y
  }
```

> **If you cloned the repo directly:** `git pull` is all you need — your symlinks already point to the repo.

---

## License

MIT