# Cross-Language Review Principles

> Core review standards that apply regardless of programming language.
> Language-specific syntax and patterns are in separate language spec files.

---

## Priority

| Priority | Category | Rationale |
|----------|----------|-----------|
| P0 | SRP / Separation of Concerns | Constructor only does DI, business logic must not leak into infrastructure |
| P0 | Exception / Error Handling | Swallowed errors are the hardest anti-pattern to debug, must preserve stack trace |
| P0 | Race Condition | Concurrency bugs are nearly impossible to reproduce in test environments |
| P1 | Component Test | Mock external dependencies, test complete cross-layer scenarios |
| P1 | Observability / Logging | No logs in production = blind debugging |
| P2 | Comment (Why) | Code says What, comments say Why |
| P2 | Performance | Not premature optimization — obvious performance hazards |
| P3 | Metrics | Observable production health: counters, gauges, histograms for key operations |

---

## P0 — SRP / Separation of Concerns

### Core Rules

**A class/module/function should have one reason to change.**

- If a single class handles order creation, email notification, report generation, AND inventory management — it has too many responsibilities.
- Split by business capability, not by technical layer.

**Constructor / initialization should only wire dependencies, not execute business logic.**

- No database calls, no HTTP requests, no complex computation in constructors.
- Dependencies should be injected, not created internally.

**Don't mix infrastructure concerns with business logic.**

- Business rules should not know about HTTP status codes, database drivers, or serialization formats.
- Infrastructure adapters wrap external dependencies and expose clean interfaces to the business layer.

---

## P0 — Exception / Error Handling

### Core Rules

**Never swallow errors silently.** Every catch/error path must log, wrap, or propagate.

**Preserve error chain / stack trace.** Re-throwing must not lose the original error context.
- C#: `throw;` not `throw ex;`
- Go: `fmt.Errorf("context: %w", err)` not `fmt.Errorf("context: %v", err)`

**Use semantically appropriate error/exception types.** Validation errors, not-found errors, and system errors should be distinguishable.
- C#: Use specific exception types (`ValidationException`, `NotFoundException`), not generic `InvalidOperationException` for everything
- Go: Use sentinel errors (`var ErrNotFound = errors.New(...)`) or custom error types

**Resources must be released on error.** Use language-appropriate patterns:
- C#: `using` / `await using` declarations
- Go: `defer` for cleanup

**Every `catch` / error branch must either:**
1. Log with full context (error object + business identifiers) and re-throw, OR
2. Handle the error explicitly (return appropriate response, retry, fallback)

Never just log and continue silently — that hides bugs.

---

## P0 — Race Condition

### Core Concepts

**Shared mutable state must be synchronized.**

- Any mutable variable accessible by multiple threads/goroutines/tasks requires explicit synchronization (locks, atomic operations, concurrent collections, etc.).
- Static / singleton mutable fields are high-risk by default.

**Check-then-act is NOT atomic.**

- Reading a value, making a decision, then writing back is a classic race condition pattern.
- Use atomic operations, transactions, or lock-protected critical sections.

**Cache read-modify-write must be atomic.**

- `if not cached -> compute -> store` executed by concurrent callers can cause redundant computation or data corruption.
- Use built-in atomic cache patterns (e.g., `GetOrCreate`, `LoadOrStore`, `singleflight`).

---

## P1 — Component Test

### When to Require

Component tests validate complete scenarios with external dependencies mocked out. They sit between unit tests and integration tests — testing real cross-layer collaboration without requiring live infrastructure.

**When to require component tests:**
- Features involving multiple collaborating classes (e.g., Controller → Service → Repository)
- Background services / hosted services with complex lifecycle (start → process → error → retry → stop)
- Event pipelines (webhook received → validated → queued → consumed → side effect)
- State machines or multi-step workflows

**What to mock:**
- External APIs (HTTP clients, third-party SDKs)
- Databases (use in-memory fakes or mock repositories)
- Message brokers (Kafka, RabbitMQ — use fake producers/consumers)
- Redis / distributed cache

**What NOT to mock:**
- The classes under test and their internal collaborators
- Serialization / deserialization (test real JSON handling)
- DI wiring (use real or test-specific DI container)

**Scenario naming convention:**
Group by feature area with clear scenario IDs for traceability:
```
A1 — Normal lifecycle (start → process → stop)
A2 — Lifecycle with empty input
B1 — Error during processing → retry succeeds
B2 — Error during processing → max retries → fail
C1 — Token rotation before expiry
E1 — Edge case: concurrent requests
```

### Unit Test Coverage

Every tested unit should cover:

| Scenario | Description |
|----------|-------------|
| Happy path | Normal successful flow |
| Edge cases | Empty collections, zero, null/nil, boundary values, max values |
| Error path | Behavior when external dependencies fail |
| Business rule violation | Correct rejection of invalid input |

### Mock / Stub Guidelines

- Mock external dependencies (DB, HTTP, message queues), not pure functions.
- Verify critical side effects (e.g., was the error logged? was the notification sent?).
- Avoid over-mocking — if a function has no external dependency, don't mock it.

### Test Naming Convention

Use descriptive names that express intent:
```
MethodName_StateUnderTest_ExpectedBehavior
```

Bad: `Test1`, `TestCreateOrder`
Good: `TestCreateOrder_WhenAmountIsZero_ShouldReturnValidationError`

---

## P1 — Observability / Logging

### Mandatory Rules

**Use structured logging framework, never raw print / console output.**

- All log entries must be structured (key-value pairs), parsable by log aggregation tools (ELK, Loki, Seq, etc.).
- Raw print / console / debug output is strictly prohibited in production code.

**Log Level Guidelines:**

| Level | Usage | Production Visibility |
|-------|-------|----------------------|
| Debug | Diagnostics only, not on hot paths | Off by default |
| Info | Business milestones (2-5 per request) | On |
| Warn | Expected degradation / retry, no immediate human action needed | On |
| Error | Requires human intervention, must include error/exception object | On |
| Critical/Fatal | Service cannot continue, should trigger alerts | On |

**Every error/catch path must log or propagate — never swallow silently.**

- Log must include the error/exception object (not just a message string).
- Log must include business context (e.g., order ID, user ID) for traceability.

**Correlation / Trace ID must be propagated across service boundaries.**

- Every log entry in a request chain should carry a trace ID.
- Cross-service calls must forward the trace ID.

**Never log sensitive information:**

- PII (email, phone, address), credentials (passwords, tokens, API keys), financial data (card numbers).
- Mask or exclude sensitive fields.

---

## P2 — Comment (Why)

### Core Rule: Comments explain WHY, not WHAT.

Code already tells you WHAT it does. Comments must explain:

- **Why** this approach was chosen over alternatives
- **Why** a magic number has this specific value
- **Why** a workaround exists (link to issue / external bug)
- **Why** a business rule is enforced here

### Must-Have "Why" Comments

| Situation | Example |
|-----------|---------|
| Non-obvious algorithm or magic number | Why retry 3 times? Why timeout 30s? |
| Framework default overridden | Why we bypass the default behavior |
| Business rule enforcement | Rate calculation, fee logic, eligibility rules |
| Known external limitation / workaround | Third-party bug, API quirk |
| TODO / FIXME | Must include issue link or explanation of why and when |

### Anti-Patterns

```
// ❌ Says WHAT (code already says this)
// Call the repository to save the order
await repo.SaveAsync(order);

// ❌ Empty / meaningless doc
/// <summary>
/// Creates an order.
/// </summary>

// ✅ Says WHY
// TransactionScope is not used here because EF Core 8 has a known issue
// with distributed transactions (dotnet/efcore#23523).
// We manually control commit order in the service layer instead.
await repo.SaveAsync(order);
```

---

## P2 — Performance

### Obvious Hazards to Flag

| Hazard | Description |
|--------|-------------|
| N+1 queries | Querying inside a loop instead of batch/join |
| Load-then-filter | Loading entire dataset into memory, then filtering client-side |
| Unnecessary allocation in hot paths | Creating objects/buffers inside tight loops |
| Client/connection not reused | Creating new HTTP clients or DB connections per request |
| Blocking async | Synchronously waiting on async operations (deadlock risk) |

These are not premature optimization concerns — they are production-impacting patterns that should be flagged during review.

---

## P3 — Metrics

### Core Concepts

**Key operations should emit observable metrics for production health monitoring.**

Metrics complement logging — logs tell you what happened, metrics tell you how the system is performing over time.

**What to measure:**

- **Counters** — total requests, errors, retries, messages processed
- **Gauges** — active connections, queue depth, in-flight requests
- **Histograms** — request latency, processing duration, payload size

**When to require metrics:**

- API endpoints: request count + latency + error rate
- Background services: execution count + duration + failure count
- External calls: call count + latency + timeout/error rate
- Queue consumers: messages processed + lag + processing time

**Anti-patterns:**

- High-cardinality labels (user IDs, request IDs as metric labels — use logs for those)
- Metrics without alerts — if nobody acts on it, don't collect it
- Missing error rate metrics — knowing request count without error rate is incomplete
