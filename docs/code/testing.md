# Testing

Tests are mandatory. A change without tests for its behavior, including failure paths, is
incomplete.

## Framework and layout

- **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`). See
  [ADR 0011](../decisions/0011-swift-testing.md).
- Feature tests: `App/Features/<Name>/Tests/`. They are compiled into the test target only
  (`project.yml` excludes `**/Tests/**` from the app).
- Core, Shared and Infrastructure tests: `Tests/Core`, `Tests/Shared`, `Tests/Infrastructure`.
- Test doubles and helpers: `Tests/Support/`.

Run with `make test`. The full gate is `make check`.

## Test doubles

| Double | Use when | Simulates |
|---|---|---|
| `FakeLLMProvider` | Testing agent loops and streaming behavior over time | Scripted turns: normal response, streaming, tool calls, malformed tool call, error, partial failure, timeout, hang (for cancellation) |
| `MockLLMProvider` | Asserting what was sent to a provider, model listing | Handler closure computing events from the request, records requests |
| `StubAgentService` | Testing UI state (ViewModels) without any agent logic | Scripted events, failure after events, hang until cancelled |
| `TemporaryDirectory` | Filesystem tests | Real, isolated folder, removed in `defer` |
| `TestClock` | Anything with timestamps | Manually advanced `now` |
| `Recorder` | Capturing values from `@Sendable` callbacks | Thread-safe append-only log |

**Unit tests never contact Ollama or LM Studio.** Tests against a real server (Phase 2) will be
a separate, opt-in suite gated by an environment variable.

## What to test

| Area | Required cases |
|---|---|
| Agent (Phase 3) | normal completion, one tool call, multiple tool calls, invalid tool call, tool failure, provider failure, cancellation, timeout, max iterations, context overflow |
| Filesystem tools (Phase 3) | read existing, read missing, write, edit, invalid path, path outside project, permission error |
| Terminal (Phase 4) | success, failure exit code, timeout, cancellation, policy refusal |
| Providers (Phase 2) | request encoding, stream decoding (fixtures), malformed chunks, HTTP errors, unreachable server |
| Repositories | CRUD, ordering, migrations (Phase 5) |
| ViewModels | every action, loading/error/success states, cancellation |

## Style

- One behavior per test. The display name states the behavior: `"a missing folder is rejected"`.
- Use parameterized tests (`arguments:`) for input tables.
- Put `@MainActor` on suites that test ViewModels.
- Use `.timeLimit(.minutes(1))` on suites with concurrency, so a hang fails instead of blocking CI.
- When polling for asynchronous effects, use a bounded loop (`for _ in 0..<200 where !condition`),
  never an unbounded wait.
- Never delete, skip or weaken a test to get a green build. Fix the code or the test's
  premise, and explain why in the change.
