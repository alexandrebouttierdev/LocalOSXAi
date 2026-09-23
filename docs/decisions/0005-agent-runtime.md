# 0005: Event-stream agent runtime behind AgentService

**Status:** Accepted

## Context
The agent loop (model ↔ tools) is the core of the product, and the UI must be independent from
it, both to test the UI and to build it before the runtime exists.

## Decision
The UI consumes `AgentService.run(_:) -> AsyncThrowingStream<AgentEvent, Error>`. Events are
small and UI-oriented (message started, deltas, tool call started/finished, context usage,
finished). A pure `TranscriptReducer` applies them to the transcript. The real runtime
(Phase 3) is composed of `AgentLoop`, `ContextManager`, `ToolExecutor` and an `LLMProvider`,
with explicit limits (iterations, timeouts, invalid-call budget). Until then,
`SimulatedAgentService` drives the UI and is labelled "Simulated" in the app.

## Alternatives
- **The ViewModel runs the loop itself**: couples UI and AI, and makes both hard to test.
- **Callback/delegate-based progress**: worse cancellation semantics than structured concurrency.
- **Shared mutable run state observed by the UI**: harder to reason about across actors.

## Consequences
- The UI is fully testable with `StubAgentService`, and demos run without a model.
- Cancellation propagates naturally through stream termination.
- The event contract is an API. Changing it requires updating the reducer, the services and
  the tests together.
