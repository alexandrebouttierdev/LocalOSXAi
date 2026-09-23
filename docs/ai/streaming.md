# Streaming

## Provider stream contract (`LLMEvent`)

1. Text and reasoning arrive as ordered deltas (`textDelta`, `reasoningDelta`).
2. A tool call is emitted **once, fully assembled**. Providers whose wire format streams
   argument fragments (OpenAI-compatible SSE) buffer them internally.
3. `usage` may appear at most once, before `finished`.
4. `finished(reason)` is the last event of a successful stream: `.stop`, `.length` or `.toolCalls`.
5. Failures end the stream by **throwing** (`ProviderError`, `CancellationError`), never as events.

## Agent stream contract (`AgentEvent`)

1. `assistantMessageStarted(id)` opens a message. Later deltas and tool calls attach to it.
2. `toolCallFinished(id:)` always refers to a previously started call.
3. `finished(outcome)` ends a successful run. Errors throw.
4. `contextUsageUpdated` may appear at any time.

`TranscriptReducer` tolerates small deviations. For example, deltas without a started message
create one. The contract still stands, and tests assert it for `SimulatedAgentService`.

## Cancellation

Consumer-driven: cancelling the consuming task terminates the stream, and `onTermination`
cancels the producer. See [architecture/concurrency.md](../architecture/concurrency.md) for
the full chain.

## Performance

- Deltas are applied to the transcript on the main actor, one small mutation each. At local
  model speeds (roughly 20–150 tokens/s), this is well within budget.
- If profiling shows excessive view updates at very high token rates, the ViewModel will
  coalesce deltas per frame (about 16 ms). That is a Phase 6 optimization, measured first and
  not presumed.
- The transcript uses `LazyVStack` and keeps the bottom anchored with
  `defaultScrollAnchor(.bottom, for: .sizeChanges)`, with no scroll code running per delta.
