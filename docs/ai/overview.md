# AI architecture overview

AI is the core of the product, and it is designed around one rule: **the agent runtime knows
abstract capabilities, never providers.**

```
User request
    │
AgentViewModel ──▶ AgentService (protocol)            ◀── DirectChatAgentService (Phase 2, no tools)
                        │                                  AgentRuntime (Phase 3) · SimulatedAgentService (demo)
                        ▼
                 ┌─ Agent loop ─────────────────────────────────────────┐
                 │ ContextManager ─▶ LLMProvider.stream ─▶ LLMEvent…     │
                 │        ▲                    │                        │
                 │        │             tool call? ── no ─▶ final answer│
                 │        │                    │ yes                     │
                 │   tool result ◀─ ToolExecutor (validate → permission  │
                 │                   → execute with timeout)             │
                 └───────────────────────────────────────────────────────┘
```

## Components

| Component | Contract | Status |
|---|---|---|
| Provider | `LLMProvider`: `listModels()`, `stream(request:)` | ✅ Ollama, LM Studio, generic OpenAI-compatible |
| Model resolution | `ModelResolving` → `ProviderRegistry` (discovery, per-provider isolation) | ✅ |
| Model | `AIModel` + `ModelCapabilities` + `ContextWindow` | ✅ |
| Agent service | `AgentService.run(_:) -> AsyncThrowingStream<AgentEvent, Error>` | ✅ `DirectChatAgentService` (streaming chat, no tools), simulated ✅, tool runtime Phase 3 |
| Tools | `AgentTool`, `ToolRegistry`, `ToolParameterSchema`, `ToolArguments`, `ToolResult` | Contract ✅, tools Phase 3–4 |
| Context | `ContextUsage`, `TokenEstimator`, `ConversationWindow` (drop oldest) | ✅, `ContextManager` Phase 3 |
| Tool executor, permission policy | `ToolExecutor`, `CommandPolicy` | Phase 3–4 |

## Documents

- [providers.md](providers.md): the provider abstraction, Ollama and LM Studio specifics.
- [agent.md](agent.md): the agent loop, limits, recovery.
- [tools.md](tools.md): tool contract, validation, execution, catalog.
- [context.md](context.md): budget, instructions (AGENTS.md), compaction.
- [streaming.md](streaming.md): event contracts and cancellation.
- [errors.md](errors.md): error taxonomy and presentation.
- [model-capabilities.md](model-capabilities.md): capabilities and why they are not trusted blindly.
