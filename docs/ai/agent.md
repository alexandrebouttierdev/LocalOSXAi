# Agent runtime

**Status:** the contract (`AgentService`, `AgentEvent`, `AgentRunRequest`) and the UI are
implemented. Since Phase 2 the live app runs `DirectChatAgentService`: a real streaming chat
with the selected model, **without tools** ([ADR 0013](../decisions/0013-direct-chat-before-agent-runtime.md)).
The tool-using runtime described below is Phase 3.

## Contract with the UI

```swift
protocol AgentService: Sendable {
    func run(_ request: AgentRunRequest) -> AsyncThrowingStream<AgentEvent, Error>
}
```

Events: `assistantMessageStarted`, `textDelta`, `reasoningDelta`, `toolCallStarted`,
`toolCallFinished`, `contextUsageUpdated`, `finished(outcome)`. Failures throw. The UI applies
events through `TranscriptReducer`, so any service that honors this contract drives the UI
correctly.

## The loop (Phase 3)

```
run(request):
  context = ContextManager.build(system prompt, instructions, history, prompt)
  for iteration in 1...limits.maxIterations:
      emit contextUsageUpdated(context.usage)
      if context.usage.isOverBudget: compact, or fail with .contextOverflow
      emit assistantMessageStarted
      stream = provider.stream(context.request(tools: registry.definitions))
      collect text/reasoning deltas (forwarded as events) and tool calls
      if no tool calls: emit finished(.completed); return
      for call in toolCalls (sequentially):
          emit toolCallStarted
          result = ToolExecutor.execute(call)   // validate → permission → run with timeout
          emit toolCallFinished
          context.append(assistant tool call, tool result)
  emit finished(.reachedIterationLimit)
```

## Responsibilities

| Concern | Owner | Notes |
|---|---|---|
| Iteration, limits, stopping | `AgentLoop` | Knows no provider and no tool implementation |
| Building and budgeting the prompt | `ContextManager` | See [context.md](context.md) |
| Model I/O | `LLMProvider` | Injected |
| Tool validation, permission, execution, timeout | `ToolExecutor` | See [tools.md](tools.md) |
| Approval prompts | `ApprovalHandler` protocol, implemented by the UI layer | The loop suspends (`await`) until the user answers |

## Limits (configurable, with conservative defaults)

| Limit | Default | On breach |
|---|---|---|
| Max iterations per run | 25 | `finished(.reachedIterationLimit)`, and the user can continue |
| Model first-token timeout | 120 s (models may load) | `ProviderError.timedOut` |
| Model inactivity timeout (between chunks) | 60 s | `ProviderError.timedOut` |
| Tool timeout | 30 s (commands: 120 s) | Tool result `failure`, run continues |
| Consecutive invalid tool calls | 3 | Run fails with an explanation |

## Error recovery

| Failure | Behavior |
|---|---|
| Malformed arguments, unknown tool, schema violation | Returned to the model as a tool result (`isError`) with the validation message, so the model can self-correct |
| Tool execution error | Returned to the model as a failed tool result |
| Permission denied by the user | Returned as a `denied` tool result. The model is told not to retry the same action |
| Provider error mid-stream | Run fails. Partial text is kept and marked failed. The user can retry |
| Context overflow | Compaction first. If still over budget, the run fails with a clear message |
| Cancellation | Everything stops. Partial content is kept and marked “Stopped” |

## Required tests (Phase 3)

Normal completion, a single tool call, multiple tool calls, invalid tool call, tool failure,
provider failure, cancellation (during streaming and during a tool), timeout, max iterations,
context overflow. All are built on `FakeLLMProvider` scripts.
