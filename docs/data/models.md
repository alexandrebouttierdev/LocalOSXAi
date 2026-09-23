# Data models

## Implemented (Phase 1)

| Model | Feature / layer | Key fields | Notes |
|---|---|---|---|
| `Project` | Projects | `id`, `name`, `rootURL`, `createdAt`, `lastOpenedAt` | `rootURL` is standardized and symlink-resolved. It is the tool boundary |
| `Session` | Sessions | `id`, `projectID`, `title`, `createdAt`, `updatedAt`, `model`, `messages` | Title derived from the first prompt while still “New session” |
| `AgentMessage` | Agent | `id`, `role` (user/assistant/error), `text`, `reasoning`, `toolCalls`, `state`, `createdAt` | UI and persistence model |
| `ToolCallRecord` | Agent | `id`, `name`, `argumentsJSON`, `status`, `summary`, `output` | Status: awaitingApproval, running, succeeded, failed, denied, cancelled |
| `AIModel` | Core | `provider`, `name`, `displayName`, `contextWindow`, `capabilities` | Identity = provider + name |
| `ContextWindow` | Core | `advertisedTokens`, `configuredTokens`, `effectiveTokens` | See [model capabilities](../ai/model-capabilities.md) |
| `LLMRequest`, `LLMMessage`, `LLMEvent`, `LLMToolCall` | Core | | Wire-independent provider contract |
| `ToolDefinition`, `ToolParameterSchema`, `ToolArguments`, `ToolResult` | Core | | Tool contract |

## Planned

| Model | Phase | Purpose |
|---|---|---|
| `AgentRun` | 3 | One execution: start/end dates, outcome, iterations, token usage, model used. Makes history auditable |
| `ModelConfiguration` | 2/5 | Per-model user settings: configured context, temperature, reasoning effort |
| `ProviderConfiguration` | 2 | Endpoint URL, enabled flag, Keychain reference for a credential |
| `FileChange` | 4 | Proposed/applied edit: path, diff hunks, added/removed counts, status (pending/accepted/rejected/reverted) |
| `CommandExecution` | 4 | Command, working directory, policy decision, exit code, duration, truncated output |
| `Settings` | 5 | Agent limits, permission policy overrides, terminal and Git preferences |

## Why `Session` embeds messages today

With in-memory storage, embedding keeps Phase 1 simple. In SQLite (Phase 5), messages and tool
calls become their own tables keyed by session. The repository protocol will gain paging
(`messages(in:before:limit:)`) so long sessions are not loaded whole. `Session.messages` will
then be dropped from the persisted row. That change is planned and will be covered by a
migration.
