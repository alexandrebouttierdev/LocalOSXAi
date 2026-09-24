# Streaming

## Provider stream contract (`LLMEvent`)

1. Text and reasoning arrive as ordered deltas (`textDelta`, `reasoningDelta`).
2. A tool call is emitted **once, fully assembled**. Providers whose wire format streams
   argument fragments (OpenAI-compatible SSE) buffer them internally.
3. `toolCallProgress` is **informational**: while a provider buffers argument fragments, it
   reports the call's name, the characters received so far and a prefix of the arguments
   (the first report when the name is known, then every 512 characters). Consumers may ignore
   it. It exists because a model writing a whole file into `write_file` can stream for minutes
   with nothing else to show.
4. `usage` may appear at most once, before `finished`.
5. `finished(reason)` is the last event of a successful stream: `.stop`, `.length` or `.toolCalls`.
6. Failures end the stream by **throwing** (`ProviderError`, `CancellationError`), never as events.

## Agent stream contract (`AgentEvent`)

1. `assistantMessageStarted(id)` opens a message. Later deltas and tool calls attach to it.
2. `toolCallFinished(id:)` always refers to a previously started call.
3. `finished(outcome)` ends a successful run. Errors throw.
4. `contextUsageUpdated` may appear at any time.
5. `toolCallPreparing(draft)` reports a tool call still being generated (name, target path once
   readable from the partial arguments, characters so far). The draft is cleared when the call
   starts or the message ends.

Under each agent turn, a line shows how long it took and how many tokens the model wrote
(“12.4 s · 356 tokens”). While the turn streams it ticks every second and counts an estimate
(“~210 tokens”, about 4 characters per token, including reasoning and tool arguments); each
model call's estimate is replaced by the server's count when `AgentEvent.usage` arrives. The
duration runs from the user's message, so model loading and tool time count (`TurnStats`).

The transcript shows a live status while a message has no content yet: “Waiting for the
model… 12 s (it may be loading)”, “Thinking… 40 s” during reasoning, or “Writing index.html…
12.3K characters” while a tool call is prepared. A local runtime that loads a model on demand
(LM Studio JIT loading) can take tens of seconds before the first byte, and a reasoning model
can think for minutes: the user must always see that something is happening.

`TranscriptReducer` tolerates small deviations. For example, deltas without a started message
create one. The contract still stands, and tests assert it for `SimulatedAgentService`.

## Cancellation

Consumer-driven: cancelling the consuming task terminates the stream, and `onTermination`
cancels the producer. See [architecture/concurrency.md](../architecture/concurrency.md) for
the full chain.

## Performance

- Deltas are applied to the transcript on the main actor, one small mutation each. At local
  model speeds (roughly 20–150 tokens/s), this is well within budget.
- Streaming text is shown as plain `Text`; Markdown is parsed once the message is complete.
- Coalescing deltas per frame (about 16 ms) was **not implemented** in Phase 6: nothing has
  shown a problem at local model speeds, and batching would delay the last token of a burst
  until the next event. It stays the first thing to try if Instruments shows view updates
  dominating while streaming.
- The transcript uses `LazyVStack` and keeps the bottom anchored with
  `defaultScrollAnchor(.bottom, for: .sizeChanges)`, with no scroll code running per delta.
