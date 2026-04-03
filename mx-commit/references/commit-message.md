# Commit Message Rules

## Format

```
<type>: <subject>

1.<reason> → <change>
2.<reason> → <change>
3.<reason> → <change>
```

- **Header**: `<type>: <subject>` — max 50 characters total.
- **Second line**: blank (required).
- **Body** (line 3+): numbered items. Each item states the reason first, then the change (`reason → change`). Max 50 characters per item. Max 3 items.
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
2. Header max 50 characters. Body items max 50 characters each, max 3 items.
3. Use a colon `:` between type and subject.
4. All text in English.
5. Use only common, universally recognized abbreviations. Readability is the highest priority.

---

## Examples

```
fix: correct base date to use US trading day minus 5

1.Original code used current day as base date → changed to 5 US trading days ago
2.Added helper function to compute the adjusted base date
3.Added test cases to verify new base date logic
```

```
feat: add WebSocket reconnect with exponential backoff

1.Clients need auto-recovery on connection drop → added reconnectLoop
2.Added backoff function with jitter and configurable max delay
3.Added integration test covering reconnect + message delivery
```

```
refactor: extract GCP livestream logic into provider layer

1.Service layer called multiple GCP APIs directly → moved to provider
2.Added fine-grained methods for independent testing
```

```
chore: upgrade gorilla/websocket to v1.5.3

1.Previous version had known vulnerability → upgraded to patched release
2.Verified all existing tests pass with new version
```
