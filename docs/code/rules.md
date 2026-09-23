# Code rules

These rules are authoritative. When a rule conflicts with convenience, the rule wins. When
two rules conflict, the priority is:

**Clarity > Correctness > Testability > Maintainability > Performance > Abstraction**

## The rules

1. **Clarity before concision.** Prefer an explicit `guard`, a named helper or an intermediate
   type over a clever one-liner. Code is read far more than it is written.
2. **Simplicity before abstraction.** Add a protocol when there are two implementations
   (including a test double) or a real boundary, not "in case".
3. **One responsibility per type.** If a type's doc comment needs “and”, consider splitting it.
4. **No giant ViewModels.** Extract pure logic (see `TranscriptReducer`, `FuzzyMatcher`).
5. **No global singletons.** `FileManager.default`, `NSApp` and similar platform singletons
   are acceptable at the edges; app state is never global.
6. **Dependency injection** through initializers. The composition root is `AppEnvironment`.
7. **Protocols at boundaries**: storage, providers, agent, tools, processes.
8. **No business logic in SwiftUI views.**
9. **No provider access from the UI.** The UI talks to ViewModels and ViewModels talk to services.
10. **No force unwrap** (`!`, `try!`, `as!`) unless an adjacent comment proves it cannot fail.
    SwiftLint `force_unwrapping` is enabled.
11. **Explicit error handling.** Throw typed errors at boundaries. Never `try?` away an error
    that the user or the logs should see.
12. **Swift Concurrency, not callbacks.** `async/await`, `AsyncSequence`, actors. No
    completion handlers or Combine in new code.
13. **Strict `Sendable`.** No `@unchecked Sendable` without a documented proof.
14. **No dead code.** No commented-out code, unused types or speculative parameters.
15. **No anonymous TODO.** Write `TODO(reason or link)`. It is checked by `make architecture`.

## Additional conventions

- Design tokens only in views (`AppColors`, `AppSpacing`, `AppTypography`, `AppRadius`,
  `AppLayout`, `AppAnimation`, `AppShadow`).
- User-facing text is sentence case, short, and says what happens next.
- A partially implemented feature must be labelled in the UI (placeholder with its phase)
  and reported. It is never silently missing.
- Warnings are errors (`SWIFT_TREAT_WARNINGS_AS_ERRORS`). Do not silence a warning without
  a comment explaining why.
