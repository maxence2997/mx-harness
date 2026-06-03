# Commit Message Rules

## Format

```
<type>: <subject>

1.<change> → <scenario + reason>
2.<change> → <scenario + reason>
3.<change> → <scenario + reason>
```

- **Header**: `<type>: <subject>` — max 50 characters total.
- **Second line**: blank (required).
- **Body** (line 3+): numbered items. Each item states the **change first**, then the scenario + reason (`change → scenario + reason`). The change is the focus in a commit. Max 50 characters per item. Max 3 items.
- Body is optional for trivial changes (e.g. typo fix, dependency bump).

---

## Type Definitions

| Type       | When to use                                                                   |
| ---------- | ----------------------------------------------------------------------------- |
| `feat`     | New code for a new feature, support method, or interface                      |
| `fix`      | Fix a bug or incorrect behavior                                               |
| `refactor` | Restructure code for readability or maintainability without changing behavior |
| `doc`      | Documentation-only or comment-only changes                                    |
| `style`    | Code formatting, parameter reordering, or other non-functional changes        |
| `test`     | Add or modify tests (unit, integration, test fixtures)                        |
| `chore`    | Dependency upgrades, tooling changes, or build configuration                  |
| `revert`   | Revert one or more previous commits                                            |
| `merge`    | Merge operations                                                               |
| `sync`     | Resolve conflicts between branches                                             |

---

## Rules

1. Each commit contains exactly one logical change. Do not mix unrelated modifications.
2. Header max 50 characters. Body items max 50 characters each, **hard limit: max 3 items**.
3. Use a colon `:` between type and subject.
4. All text in English.
5. Use only common, universally recognized abbreviations. Readability is the highest priority.

---

## Body Item Writing Style

Each body item must be self-contained — readable on its own without scanning the diff or other items.

- **Lead with the change, then the scenario + reason.** Use `change → scenario + reason` format. In a commit message the change is the headline; the reason is the justification.
- **No pronouns or vague references.** Avoid "this", "it", "the above", "as mentioned". Name the concrete subject (function, field, condition) explicitly.
- **State the scenario.** When the change addresses a specific case, name the triggering condition — not "fix the bug" but "websocket reconnect dropped first message after backoff".

```
// ❌ Vague, no scenario, says WHAT only
1.Updated the code to handle this case

// ❌ Pronoun + no scenario / reason
1.It now retries on failure

// ✅ Change first, then scenario + reason
1.Dedupe Stripe webhook by event_id → retry storm caused double-charge
```

---

## Examples

```
fix: correct base date to use US trading day minus 5

1.Use US trading day minus 5 as base date → original used current day, off-by-5
2.Add helper computeAdjustedBaseDate → reused by report + alert paths
3.Add test cases for adjusted base date → guard against regression
```

```
feat: add WebSocket reconnect with exponential backoff

1.Add reconnectLoop in ws client → clients need auto-recovery on drop
2.Add backoff with jitter + max delay → avoid thundering herd on outage
3.Add integration test for reconnect + delivery → cover lossless redelivery
```

```
refactor: extract GCP livestream logic into provider layer

1.Move GCP API calls into provider → service layer called GCP APIs directly
2.Split provider into fine-grained methods → enable independent unit tests
```

```
chore: upgrade gorilla/websocket to v1.5.3

1.Upgrade gorilla/websocket to v1.5.3 → prior version had known CVE
2.Verify existing tests pass on v1.5.3 → confirm no behavioral regression
```
