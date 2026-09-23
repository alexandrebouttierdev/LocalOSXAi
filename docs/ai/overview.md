# AI architecture overview

AI is the core of the product, and it is designed around one rule: **the agent runtime knows
abstract capabilities, never providers.**

```
User request
    │
AgentViewModel ──▶ AgentService (protocol)            ◀── AgentRuntime · SimulatedAgentService (demo)
   (ToolApprover)       │
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
| Agent service | `AgentService.run(_:approver:)` | ✅ `AgentRuntime` (tool loop), simulated ✅ |
| Tools | `AgentTool`, `ToolRegistry`, `ToolParameterSchema`, `ToolArguments`, `ToolResult` | ✅ 6 filesystem tools; terminal and Git in Phase 4 |
| Context | `ContextUsage`, `TokenEstimator`, `AgentPrompt`, `RunContext` | ✅ (summarization planned) |
| Tool executor, permissions, approvals | `ToolExecutor`, `ToolPermissionPolicy`, `ToolApprover` | ✅ (`CommandPolicy`: Phase 4) |

## Documents

- [providers.md](providers.md): the provider abstraction, Ollama and LM Studio specifics.
- [agent.md](agent.md): the agent loop, limits, recovery.
- [tools.md](tools.md): tool contract, validation, execution, catalog.
- [context.md](context.md): budget, instructions (AGENTS.md), compaction.
- [streaming.md](streaming.md): event contracts and cancellation.
- [errors.md](errors.md): error taxonomy and presentation.
- [model-capabilities.md](model-capabilities.md): capabilities and why they are not trusted blindly.
