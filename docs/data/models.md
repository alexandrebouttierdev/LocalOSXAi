# Data models

## Implemented (Phases 1–5)

| Model | Feature / layer | Key fields | Notes |
|---|---|---|---|
| `Project` | Projects | `id`, `name`, `rootURL`, `createdAt`, `lastOpenedAt`, `includesClaudeInstructions` | `rootURL` is standardized and symlink-resolved. It is the tool boundary |
| `Session` | Sessions | `id`, `projectID`, `title`, `createdAt`, `updatedAt`, `model`, `messages`, `toolCallCount` | Title derived from the first prompt while still “New session”. Lists carry summaries (`messages` empty) |
| `AgentMessage` | Agent | `id`, `role` (user/assistant/error), `text`, `reasoning`, `toolCalls`, `state`, `createdAt` | UI and persistence model |
| `ToolCallRecord` | Agent | `id`, `name`, `argumentsJSON`, `status`, `summary`, `output` | Status: awaitingApproval, running, succeeded, failed, denied, cancelled |
| `AIModel` | Core | `provider`, `name`, `displayName`, `contextWindow`, `capabilities` | Identity = provider + name |
| `ContextWindow` | Core | `advertisedTokens`, `loadedTokens`, `configuredTokens`, `effectiveTokens` | See [model capabilities](../ai/model-capabilities.md) |
| `LLMRequest`, `LLMMessage`, `LLMEvent`, `LLMToolCall` | Core | | Wire-independent provider contract |
| `ToolDefinition`, `ToolParameterSchema`, `ToolArguments`, `ToolResult` | Core | | Tool contract |
| `ToolApprovalRequest`, `ToolApprovalDecision` | Agent | `id` (call id), `toolName`, `summary`, `reason` / allowOnce, allowForSession, deny | Transient, not persisted |
| `ProjectInstruction` | Agent | `source`, `content`, `isTruncated` | Loaded per run from `AGENTS.md` |
| `FileChange`, `FileDiff` | Changes, Core | file, relative path, status (created/modified/deleted), diff hunks with line numbers and +/− counts | Original contents live in `ChangeTracker` (memory) until accepted or reverted |
| `GitStatus`, `GitFileChange`, `GitCommit` | Git | branch, upstream, ahead/behind, changes (staged/unstaged), commits | Read from Git on demand |
| `TerminalEntry` | Terminal | command, output chunks per stream, state (running/finished/cancelled/failed) | Per project, in memory |
| `ProviderSettings` | Settings | Ollama and LM Studio endpoints (enabled, base URL), Ollama context tokens, idle timeout | Stored as versioned JSON in `UserDefaults` (`providers.v1`) |
| `AgentSettings` | Settings | `maxIterations` (5–100), `toolTimeoutSeconds` (15 s–5 min) | `UserDefaults` (`agent.v1`); read at the start of each run |

## Planned

| Model | Phase | Purpose |
|---|---|---|
| `AgentRun` | 3 | One execution: start/end dates, outcome, iterations, token usage, model used. Makes history auditable |
| `ModelConfiguration` | Not implemented yet | Per-model user settings: configured context, temperature, reasoning effort |
| `CommandExecution` | Not implemented yet | Persisted audit of commands run by the agent: policy decision, exit code, duration |
| Policy overrides | Not implemented yet | Per-project command policy, environment allowlist |

## Sessions in storage

Messages are rows of their own table; tool calls are a JSON column of their message. Lists
return summaries and only an opened session loads its transcript. Paging long transcripts is
not needed yet. See [ADR 0019](../decisions/0019-session-storage-shape.md).
