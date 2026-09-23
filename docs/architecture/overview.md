# Architecture overview

## Layers

| Folder | Responsibility | May depend on |
|---|---|---|
| `App/Application` | Entry point, composition root (`AppEnvironment`), menu commands, scenes | everything |
| `App/Core` | Provider-agnostic contracts and primitives: `LLMProvider`, `LLMRequest/LLMEvent`, `AIModel`, `AgentTool`, `ToolRegistry`, `ToolParameterSchema`, `ContextUsage`, `TokenEstimator`, logging, `UserFacingError`, `JSONValue` | Foundation, OSLog |
| `App/Features` | User-facing capabilities, each self-contained (models, views, view models, services, tests) | Core, Shared, other features' **models** (one direction only) |
| `App/Infrastructure` | Implementations of protocols: providers (Ollama, OpenAI-compatible), storage, settings store, simulations | Core, feature protocols and models |
| `App/Shared` | Design system, reusable view components, formatting helpers | Core (value types only) |
| `App/Resources` | Assets, Info.plist | — |

## Why this split

- **Core** holds what the agent runtime needs to be provider-agnostic. It is kept free of
  UI and provider specifics, so it could become a Swift package without changes.
- **Features** own their behavior end to end. Changing "Sessions" should not require
  opening five global folders.
- **Infrastructure** is where technology choices live (HTTP, SQLite, `Process`). It is
  replaceable because features only see protocols.
- **Application** is the only place that knows about every concrete type. Swapping the
  simulated agent for the real one is a one-line change there.

## Current features

| Feature | Purpose | Phase |
|---|---|---|
| Workspace | Window shell: sidebar, content, inspector, command routing, navigation state | 1 |
| CommandPalette | ⌘K palette: filtering, ranking, keyboard selection | 1 |
| Projects | Opening folders, recent projects | 1 (storage in 5) |
| Sessions | Conversations per project, resume, auto-title | 1 (storage in 5) |
| Agent | Conversation UI, agent runtime (loop, context, tool execution, approvals) | 1–3 |
| Models | Model discovery (`ProviderRegistry`), selection, resolution for the agent | 1–2 |
| Settings | Appearance, provider settings (endpoints, context, timeout) with live status | 1–2 |
| Terminal | Integrated terminal: `CommandRunner` port, history, streamed output, stop | 4 |
| Git | `GitService` port, porcelain parsing, inspector summary | 4 |
| Changes | `ChangeTracker`, review of the agent's edits: diff, accept, revert | 4 |
| Files | File browser with fuzzy search (⌘P) and preview | 4 | Their folders are created
when their implementation starts; the UI already shows labelled placeholders for them.

## Single module, enforced boundaries

The app is one Swift module. Splitting into Swift packages would enforce boundaries in the
compiler, but it adds build complexity and `public` noise that is not justified yet. The
rules are enforced by `scripts/check-architecture.sh` instead (see
[dependency-rules.md](dependency-rules.md) and [ADR 0012](../decisions/0012-single-module-with-enforced-rules.md)).
If Core stabilizes (after Phase 3), extracting it into a package is the expected next step.
