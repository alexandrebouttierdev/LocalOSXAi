# Swift style

SwiftLint (`.swiftlint.yml`, run in strict mode) enforces the mechanical rules. This page
covers the choices a linter cannot make.

## Types

- Prefer `struct` and `enum`. Use `final class` for `@Observable` ViewModels, and `actor` for
  shared mutable state outside the main actor.
- Mark classes `final` unless inheritance is part of the design (it never is today).
- Default access level (`internal`). The app is one module, so `public` is noise.
  `private` is for real encapsulation.

## Errors

- Typed `enum` errors conforming to `LocalizedError` at boundaries. `errorDescription` is
  written for users and `recoverySuggestion` says what to do.
- Use typed throws (`throws(ToolError)`) where a function can only fail one way and callers
  benefit (tool argument access, the registry).

## Observation

- Use `@Observable` (Observation framework), not `ObservableObject`/`@Published`.
- Expose state as `private(set) var`, and mutate it only through methods.
- Views take ViewModels as `let` or `@Bindable var` (for two-way bindings), never `@State` for
  injected ViewModels.

## SwiftUI views

- Split a view when `body` exceeds roughly 60 lines or when a part has its own state.
- Use a `private var` or a small private struct for subviews, not free functions that return
  `AnyView`. Avoid `AnyView`.
- No expensive work in `body`. Views read precomputed state.
- Every interactive custom control has an accessibility label, and traits when not obvious.

## Formatting

- Line length 140 (warning) / 180 (error). Multi-line argument lists put one argument per line.
- Trailing closures for the last closure argument only.
- `// MARK: -` sections for types longer than roughly 80 lines.
