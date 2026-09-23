# Data models

## Implemented (Phases 1–4)

| Model | Feature / layer | Key fields | Notes |
|---|---|---|---|
| `Project` | Projects | `id`, `name`, `rootURL`, `createdAt`, `lastOpenedAt` | `rootURL` is standardized and symlink-resolved. It is the tool boundary |
| `Session` | Sessions | `id`, `projectID`, `title`, `createdAt`, `updatedAt`, `model`, `messages` | Title derived from the first prompt while still “New session” |
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
| `ProviderSettings` | Settings | Ollama and LM Studio endpoints (enabled, base URL), Ollama context tokens, idle timeout | Stored as versioned JSON in `UserDefaults` |

## Planned

| Model | Phase | Purpose |
|---|---|---|
| `AgentRun` | 3 | One execution: start/end dates, outcome, iterations, token usage, model used. Makes history auditable |
| `ModelConfiguration` | 5 | Per-model user settings: configured context, temperature, reasoning effort |
| `CommandExecution` | 5 | Persisted audit of commands run by the agent: policy decision, exit code, duration |
| `Settings` | 5 | Agent limits, permission policy overrides, terminal and Git preferences |

## Why `Session` embeds messages today

With in-memory storage, embedding keeps Phase 1 simple. In SQLite (Phase 5), messages and tool
calls become their own tables keyed by session. The repository protocol will gain paging
(`messages(in:before:limit:)`) so long sessions are not loaded whole. `Session.messages` will
then be dropped from the persisted row. That change is planned and will be covered by a
migration.
