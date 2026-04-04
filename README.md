# mx-skills

> Plug-and-play AI coding skills that guide your agent from raw idea to merged PR — with structured reviews, TDD loops, and clean commits at every step.

![License](https://img.shields.io/badge/license-MIT-blue)
![Skills](https://img.shields.io/badge/skills-10-brightgreen)
![Works with](https://img.shields.io/badge/works%20with-GitHub%20Copilot%20%7C%20Cursor%20%7C%20Claude-blueviolet)

---

## Why?

AI agents are great at writing code — but left unchecked they skip planning, skip tests, and produce unmaintainable diffs. These skills inject discipline into the loop:

- **Spec before code** — brainstorm and lock down a design doc before any implementation
- **Test-first** — every task follows red → green → refactor
- **Multi-perspective review** — Senior Engineer, SRE, and Future Maintainer weigh in before merge
- **Structured commits** — no more "fix stuff" messages

---

## Skills

### Workflow

| Skill                           | Description                                                               |
| ------------------------------- | ------------------------------------------------------------------------- |
| [mx-flow](mx-flow/)             | Full pipeline orchestrator — idea to verified commit                      |
| [mx-brainstorm](mx-brainstorm/) | Turn a rough idea into an approved design spec                            |
| [mx-plan](mx-plan/)             | Decompose a spec into a concrete, ordered task list                       |
| [mx-worktree](mx-worktree/)     | Create an isolated git worktree with baseline verification                |
| [mx-tdd](mx-tdd/)               | Implement one task: red → green → refactor → commit (one commit per task) |
| [mx-verify](mx-verify/)         | Final gate: full test suite + plan checklist before push                  |
| [mx-finish](mx-finish/)         | Post-merge cleanup — plan files, review reports, worktree                 |

### Review

| Skill                                 | Description                                                         |
| ------------------------------------- | ------------------------------------------------------------------- |
| [mx-team-review](mx-team-review/)     | 3-perspective code review — Senior Engineer, SRE, Future Maintainer |
| [mx-review-triage](mx-review-triage/) | Triage review findings into fix / track / skip buckets              |

### Commit

| Skill                   | Description                                                      |
| ----------------------- | ---------------------------------------------------------------- |
| [mx-commit](mx-commit/) | Commit staged changes with a structured, enforced message format |

---

## How It Fits Together

Use `/mx-flow` to run the full pipeline automatically, or invoke each skill individually for more control:

```
/mx-brainstorm   ──▶  idea → approved spec  (.mx/design/)
/mx-plan         ──▶  spec → task list      (.mx/plan/)
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

── after PR merge ─────────────────────────────────────────────
/mx-finish                      clean up and close out the branch
```

---

## Quickstart

**Install a single skill:**

```bash
# bash / zsh
npx skills add https://github.com/maxence2997/skills --skill <skill-name> -g -y
```

**Install everything at once:**

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

---

## License

MIT
