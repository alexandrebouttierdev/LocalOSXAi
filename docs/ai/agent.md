# Agent runtime

**Status:** implemented in Phase 3 (`AgentRuntime`, `ToolExecutor`, `RunContext`), verified
with `gemma4:26b` on Ollama: list → read → edit with approval → answer. It replaces the Phase 2
`DirectChatAgentService` ([ADR 0013](../decisions/0013-direct-chat-before-agent-runtime.md)). With a
model that does not support tools, it behaves as a plain chat.

## Contract with the UI

```swift
protocol AgentService: Sendable {
    func run(_ request: AgentRunRequest, approver: any ToolApprover) -> AsyncThrowingStream<AgentEvent, Error>
}
```

Events: `instructionsLoaded`, `contextUsageUpdated`, `assistantMessageStarted`, `textDelta`,
`reasoningDelta`, `toolCallPreparing`, `toolCallStarted`, `toolCallStatusChanged` (awaiting approval → running),
`toolCallFinished`, `historySummaryStarted`/`historySummaryFinished`/`historySummaryDiscarded`
(see [context.md](context.md#conversation-summaries)), `finished(outcome)`. Failures throw. The UI applies events through
`TranscriptReducer`. `AgentViewModel` is the `ToolApprover`: it shows the approval banner and
suspends the run until the user answers.

## The loop

```
run(request, approver):
  resolve model (ModelResolving) · load AGENTS.md · build RunContext
  tools offered only if the model declares .tools
  repeat up to maxIterations:
      second iteration: context was only the fallback? re-read the model; use its loaded size
      fit context (compact / drop history, or fail with contextOverflow) → emit contextUsageUpdated
      emit assistantMessageStarted; stream the model (text & reasoning forwarded live)
      tool calls cut by length → fail with toolCallCutOff (never run: their arguments are truncated)
      no tool calls → empty text? fail (outputLimitReached if cut by length, else emptyResponse)
                      otherwise emit finished(.completed); done
      for each tool call, sequentially:
          emit toolCallStarted
          ToolExecutor: lookup → parse → validate → permission → approval? → run with timeout
          emit toolCallFinished; append the result to the context
      all calls invalid 3 iterations in a row → fail with tooManyInvalidToolCalls
  emit finished(.reachedIterationLimit)
```

Each iteration is its own assistant message in the transcript. The UI shows one “Agent”
header per turn.

## Responsibilities

| Concern | Owner |
|---|---|
| Iteration, limits, stopping | `AgentRuntime`: knows no provider and no tool implementation |
| Prompt building and budgeting | `AgentPrompt` (system prompt, history conversion) and `RunContext` (budget, compaction), see [context.md](context.md) |
| Model I/O | `LLMProvider`, resolved through `ModelResolving` |
| Tool lookup, validation, permission, approval, timeout, output limit | `ToolExecutor`, see [tools.md](tools.md) |
| Asking the user | `ToolApprover`, implemented by `AgentViewModel` |

## Limits (`AgentLimits`)

| Limit | Default | On breach |
|---|---|---|
| Model calls per run | 25 | `finished(.reachedIterationLimit)`. The user can send “continue” |
| Tool timeout | 30 s | Failed tool result, and the run continues |
| Consecutive all-invalid iterations | 3 | Run fails with `AgentError.tooManyInvalidToolCalls` |
| Tool output sent to the model | 16,000 characters (head + tail) | Truncated with a marker |
| Model output per turn | The context's reserved output margin (`RunContext.outputReserve`, e.g. 25%, min 1K), sent as `GenerationOptions.maxOutputTokens` unless the run already set one or the context is only the 8K fallback ([ADR 0032](../decisions/0032-bounded-generation-output.md)) | `toolCallCutOff` or `outputLimitReached` |
| Model silence | Provider idle timeout, 900 s by default (Settings) | `ProviderError.timedOut` |

Steps per run (5–100) and the tool timeout (15 s–5 min) are set in Settings › General › Agent
(`AgentSettings`). The runtime reads them at the start of each run, so a change applies to the
next run. The other limits are constants.

## Error recovery

| Failure | Behavior |
|---|---|
| Unknown tool, malformed or invalid arguments | Returned to the model as an error result (listing the available tools, if the tool is unknown), so the model can self-correct. Counted as invalid |
| Tool execution error or timeout | Returned to the model as a failed result |
| Denied by the user | `denied` result telling the model not to retry. The run continues |
| Provider error mid-stream | Run fails. Partial text is kept and marked failed |
| Model hits its length limit (the output cap above, or the context itself) while writing a tool call | Run fails with `AgentError.toolCallCutOff`, naming the context size, **without running the call**: its arguments are truncated (a `write_file` would write half a file, or miss `path` when `content` came first), and a retry would hit the same limit. Providers keep the `length` finish reason even when a tool call was emitted |
| Invalid call with very long arguments (4,000+ characters) | The error sent to the model adds that the arguments may have been cut, to give `path` first and to write a large file in several steps |
| Model returns neither text nor tool calls | Run fails with `AgentError.emptyResponse`, or `outputLimitReached` when the response was cut by the output limit (for example, all tokens spent reasoning). A silent completion would look like a hang |
| Context overflow | Compaction first (see [context.md](context.md)). If the run still does not fit, it fails with a clear message |
| Cancellation (⌘.) | Stops streaming, any running tool and any pending approval (answered “deny”). Partial content is marked “Stopped” |
| Retry | After a failed or stopped run, or a prompt that never got an answer (the app quit), **Retry** under the transcript runs the last prompt again and replaces what the interrupted run produced |
| Quitting mid-run | The prompt is saved before the run starts, so it survives a crash or quit and can be retried |

## Tests

`AgentRuntimeTests` covers every case the specification requires: normal completion, a single
tool call, multiple tool calls, an invalid tool call (with recovery), too many invalid calls, a
tool failure, a provider failure, a provider timeout, a tool timeout, max iterations, context
overflow, cancellation during streaming and during a tool, a denied approval, a model without
tools, instruction loading, missing or unavailable models, and an end-to-end read with the real
filesystem tools.
