# PR Template

This file defines the pull request description format.
Customize the sections, labels, and instructions to match your team's conventions.
The skill reads this file and fills each section using collected context.

---

## How the skill fills each section

| Placeholder | Source |
|-------------|--------|
| `{{summary}}` | Design spec — What and How sections |
| `{{motivation}}` | Design spec — Why section |
| `{{changes}}` | Git log since branch start, grouped by commit type |
| `{{test_plan}}` | Completed tasks from plan.md |
| `{{notes}}` | Inferred from spec Out-of-scope, known trade-offs, or left blank |

Sections marked `<!-- optional -->` are omitted from the draft if no content is available.

---

## Template

```markdown
## Summary

{{summary}}

## Motivation

{{motivation}}

## Changes

{{changes}}

## Test plan

{{test_plan}}

## Notes

{{notes}}
```

---

## Customization examples

**Add a checklist:**
```markdown
## Checklist

- [ ] Tests pass locally
- [ ] No secrets committed
- [ ] CHANGELOG updated
```

**Add an issue reference line:**
```markdown
Closes #{{issue_number}}
```

**Add a screenshots section:**
```markdown
## Screenshots <!-- optional -->

{{screenshots}}
```

**Rename sections to match your team:**
```markdown
## What changed
## Why
## How to test
```

---

## Rules

- The title is derived from the first bullet of `{{summary}}` — keep it under 72 characters
- If the design spec does not exist, `{{summary}}`, `{{motivation}}`, and `{{notes}}` are derived from the git log only
- Empty optional sections are removed from the final draft
