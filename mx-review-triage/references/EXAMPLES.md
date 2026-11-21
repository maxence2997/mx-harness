# Examples

## Example triage output

```
| # | Bucket    | Sev | File:Line                     | Comment (summary)                              | Cost | Risk           | Recommended action                    |
|---|-----------|-----|-------------------------------|-------------------------------------------------|------|----------------|---------------------------------------|
| 1 | Fix now   | P0  | server_test.go:142            | time.Sleep(100ms) still used — race on slow CI  | Low  | flaky test     | Fix: replace with channel-based sync  |
| 2 | Fix now   | P1  | metrics_test.go:88            | awaitChan timeout 3s too short for macos runner  | Low  | CI failure     | Fix: sync on the channel, no timeout  |
| 3 | Track     | P1  | store/retry.go:57             | retry loop has no backoff — hammers DB in outage | Med  | DB overload during outage | Track: needs backoff design, out of scope |
| 4 | Skip      | P2  | server_test.go:210            | extract waitForState() helper to reduce boilerplate | Med | none (readability) | Won't fix: nothing breaks if left |
| 5 | Skip      | P2  | parser.go:30                  | handle payloads larger than 4 GiB                | Med  | none — gateway caps at 10 MiB | Won't fix: no realistic trigger |
| 6 | Skip      | P3  | metrics_test.go:15            | rename ts variable to testServer                 | Low  | none           | Won't fix: ts is idiomatic in tests   |
```

**Notes:**
- #3: Passes the Track test — every DB outage triggers it, and the fix needs a backoff policy decision that is outside this bugfix PR.
- #4: Valid, but fails the Track test: no consequence if left, so a TODO would only add list upkeep.
- #5: Fails the Track test: the trigger cannot occur behind the gateway limit, and handling it would add code with no caller.

## Example PR responses

### Fixed
```
Fixed in abc1234. Replaced time.Sleep(100ms) with channel-based sync to eliminate race window on slow CI runners.
```

### Tracked
```
Tracked in TODOS.md — without backoff the retry loop floods the DB during an outage; choosing the backoff policy is a design decision outside this bugfix PR.
```

### Won't fix
```
Won't fix. `ts` follows standard Go test naming conventions — short names are idiomatic for local test scope. Consistent with all other test files in this repo.
```

### Won't fix (no realistic trigger)
```
Won't fix. The gateway caps request bodies at 10 MiB, so a payload over 4 GiB cannot reach this parser; handling it would add code no caller exercises.
```

### Not applicable
```
Not applicable — this was already addressed in commit def5678 which added the nil check on line 45.
```

### Referencing related comments
```
Same reasoning as #5 above — that payload size cannot reach this code path.
```
