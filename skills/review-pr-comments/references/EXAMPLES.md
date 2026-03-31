# Examples

## Example triage output

```
| # | Bucket    | Sev | File:Line                     | Comment (summary)                              | Cost | Risk           | Recommended action                    |
|---|-----------|-----|-------------------------------|-------------------------------------------------|------|----------------|---------------------------------------|
| 1 | Fix now   | P0  | server_test.go:142            | time.Sleep(100ms) still used — race on slow CI  | Low  | flaky test     | Fix: replace with channel-based sync  |
| 2 | Fix now   | P1  | metrics_test.go:88            | awaitChan timeout 3s too short for macos runner  | Low  | CI failure     | Fix: increase to 5s with comment      |
| 3 | Track     | P1  | server_test.go:210            | extract waitForState() helper to reduce boilerplate | Med | none (readability) | Track: out of scope for bugfix PR |
| 4 | Skip      | P3  | metrics_test.go:15            | rename ts variable to testServer                 | Low  | none           | Won't fix: ts is idiomatic in tests   |
```

**Notes:**
- #3: Valid suggestion but this is a bugfix PR — extracting helpers would expand scope. Better as a separate refactor PR.

## Example PR responses

### Fixed
```
Fixed in abc1234. Replaced time.Sleep(100ms) with channel-based sync to eliminate race window on slow CI runners.
```

### Tracked
```
Tracked in TODOS.md — extracting waitForState() helper is a good refactor but expands scope of this bugfix PR. Will address in a dedicated refactor PR.
```

### Won't fix
```
Won't fix. `ts` follows standard Go test naming conventions — short names are idiomatic for local test scope. Consistent with all other test files in this repo.
```

### Not applicable
```
Not applicable — this was already addressed in commit def5678 which added the nil check on line 45.
```

### Referencing related comments
```
Same reasoning as #3 above — helper extraction deferred to a separate refactor PR.
```
