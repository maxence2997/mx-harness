# [Language] Review Standards

> Replace this line with a one-sentence philosophy for reviewing this language.
> Example: "Focus on what Go idiomatic code looks like in production, not just whether it compiles."

---

## Language Version
- Target: [e.g. Go 1.22+ / Python 3.12+ / Rust 1.75+]
- Primary frameworks: [e.g. Gin, GORM]

---

## Review Priority

| Priority | Category | Notes |
|----------|----------|-------|
| P0 | Observability / Logging | No logs in production = blind debugging |
| P0 | [Language-specific high risk] | e.g. goroutine leak, unsafe block |
| P1 | Test coverage | Business logic must be tested |
| P1 | Comments (Why) | Code says what. Comments say why. |
| P2 | Error handling | |
| P2 | Performance | |
| P3 | [Language idioms] | e.g. interface design, context passing |

---

## P0 — Observability / Logging

[Describe the logging standard for this language/framework]

**Required structured logger:** [e.g. slog, zap, ILogger<T>]

**Forbidden:**
- [e.g. fmt.Println, Console.WriteLine]

**Log level guidelines:**
- Debug:
- Info:
- Warning:
- Error:
- Critical/Fatal:

**Every error path must log or propagate — silent discard is forbidden.**

---

## P0 — [Language-Specific High Risk]

[Describe the most dangerous language-specific issue]

```[lang]
// ❌ Bad example
// explain why this is dangerous

// ✅ Good example
// explain the fix
```

---

## P1 — Test Coverage

**Business logic must have tests. Infrastructure layer (DB migrations, SDK wrappers) is exempt.**

Decision rule: "If this logic is wrong, will the business break?" → yes = must test.

Required scenarios:
- ✅ Happy path
- ✅ Edge cases (null, zero, empty, boundary values)
- ✅ Error path (behavior when dependencies fail)
- ✅ Business rule violations (inputs that should be rejected)

**Test naming convention:** `FunctionName_StateUnderTest_ExpectedBehavior`

---

## P1 — Comments (Why)

Code says what. Comments say why.

**Forbidden comments (say what, not why):**
```[lang]
// ❌ calls the repository to save the order
// ❌ increment counter
```

**Required Why contexts:**
- Non-obvious numbers (why retry 3 times, why timeout 30s)
- Workarounds for known upstream bugs or limitations
- Business rules enforced in code (rates, limits, thresholds)
- TODO/FIXME must include an issue link or clear reason

---

## P2 — Error Handling

[Describe the language's error handling standards]

```[lang]
// ❌ Bad: swallow error / lose stack
// ✅ Good: propagate with context
```

---

## P2 — Performance

[Describe common performance issues specific to this language]

**DB / IO:**
- [e.g. N+1 queries, missing index hints]

**Memory / Allocation:**
- [e.g. unnecessary boxing, buffer reuse]

**Caching:**
- High-frequency, low-change data without a cache strategy is a P2 issue.
- Cache TTL must be justified in a comment.

---

## P3 — [Language Idioms]

[Describe language-specific best practices that reviewers should check]

---

## Bad vs Good Examples

### ❌ Bad
```[lang]
// Example of a common mistake in this language
```

### ✅ Good
```[lang]
// The correct approach
```
