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
`toolCallFinished`, `finished(outcome)`. Failures throw. The UI applies events through
`TranscriptReducer`. `AgentViewModel` is the `ToolApprover`: it shows the approval banner and
suspends the run until the user answers.

## The loop

```
run(request, approver):
  resolve model (ModelResolving) · load AGENTS.md · build RunContext
  tools offered only if the model declares .tools
  repeat up to maxIterations:
      fit context (compact / drop history, or fail with contextOverflow) → emit contextUsageUpdated
      emit assistantMessageStarted; stream the model (text & reasoning forwarded live)
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
| Model silence | Provider idle timeout, 300 s by default (Settings) | `ProviderError.timedOut` |

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
| Model returns neither text nor tool calls | Run fails with `AgentError.emptyResponse`, or `outputLimitReached` when the response was cut by the output limit (for example, all tokens spent reasoning). A silent completion would look like a hang |
| Context overflow | Compaction first (see [context.md](context.md)). If the run still does not fit, it fails with a clear message |
| Cancellation (⌘.) | Stops streaming, any running tool and any pending approval (answered “deny”). Partial content is marked “Stopped” |

## Tests

`AgentRuntimeTests` covers every case the specification requires: normal completion, a single
tool call, multiple tool calls, an invalid tool call (with recovery), too many invalid calls, a
tool failure, a provider failure, a provider timeout, a tool timeout, max iterations, context
overflow, cancellation during streaming and during a tool, a denied approval, a model without
tools, instruction loading, missing or unavailable models, and an end-to-end read with the real
filesystem tools.
