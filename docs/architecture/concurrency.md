# Concurrency

The project compiles in **Swift 6 language mode with complete strict concurrency** and treats
warnings as errors, so data races are compile-time errors.

## Isolation strategy

| Kind of type | Isolation | Reason |
|---|---|---|
| ViewModels | `@MainActor @Observable final class` | They drive SwiftUI; state changes must happen on the main actor |
| Services / use cases | `struct … : Sendable` with `Sendable` dependencies | Stateless; safe to call from anywhere |
| Stateful infrastructure (repositories) | `actor` | Serializes access to mutable state |
| Providers, tools, agent services | `Sendable` protocols; `struct`s or `actor`s | Called concurrently from the agent runtime |
| Domain models | `Sendable` value types | Cross actor boundaries freely |

We do **not** enable "default MainActor isolation". Most non-UI code must run off the main
actor, so explicit `@MainActor` on UI types states the intent more clearly.

`@unchecked Sendable` is forbidden without a comment that proves safety. Test doubles use
`Mutex` (Synchronization) instead.

## Streaming

Long-running producers expose `AsyncThrowingStream`:

- `LLMProvider.stream(request:) -> AsyncThrowingStream<LLMEvent, Error>`
- `AgentService.run(_:) -> AsyncThrowingStream<AgentEvent, Error>`

The standard pattern is:

```swift
AsyncThrowingStream { continuation in
    let task = Task {
        do { …yield…; continuation.finish() }
        catch { continuation.finish(throwing: error) }
    }
    continuation.onTermination = { _ in task.cancel() }
}
```

Failures end the stream by throwing. They are never encoded as events, so a consumer cannot
forget to handle them.

## Cancellation chain

```
User presses Stop (⌘.)
  └▶ AgentViewModel.cancel() cancels its run Task
       └▶ the for-await loop ends, and the AgentService stream terminates
            └▶ onTermination cancels the agent's producing Task
                 ├▶ the LLM stream terminates, onTermination cancels the HTTP task
                 └▶ the running tool sees Task.isCancelled / terminates its Process
```

Every level must respect cancellation:

- Loops check `Task.isCancelled` or use cancellable APIs (`Task.sleep`, `URLSession` async APIs).
- Tools that spawn processes terminate them on cancellation (Phase 4).
- A consumer that is cancelled ends its `for try await` loop *without* an error. The
  ViewModel therefore checks `Task.isCancelled` after the loop to tell a cancellation apart
  from normal completion (see `AgentViewModel.consume`).

The tests prove this chain: `ProviderTestDoublesTests.cancellation`,
`AgentViewModelTests.cancellation` and `SimulatedServicesTests.cancellation`.

## Never block the main actor

- No file I/O, JSON parsing of large payloads, diffing or searching on the main actor.
  Move them into services or actors, and `await` them.
- Nothing expensive in `body`. Derived values that are costly to compute are computed once in
  the ViewModel. Markdown rendering is deferred to Phase 6 for this reason.

## Timeouts

Timeouts will be implemented in the agent runtime (Phase 3) by racing the operation against
`Task.sleep` in a task group, then cancelling the loser. The tests use `FakeLLMProvider.timeout`
and `.hang` to cover them.
