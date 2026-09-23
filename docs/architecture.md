# Architecture

LocalOSXAi uses **MVVM + feature-first + dependency injection + protocol-oriented
boundaries**, in a single app module with rules enforced by a script.

```
┌──────────── App/Application ─────────────┐   composition root: picks implementations
│ AppEnvironment → WorkspaceViewModel …     │
└───────────────┬──────────────────────────┘
                │ injects
┌───────────────▼──────────── App/Features ─────────────────────────────┐
│ View ──▶ ViewModel (@MainActor @Observable) ──▶ Service / use case ──▶ │ Protocol
└───────────────────────────────────────────────────────────────────────┘   ▲
┌──────────── App/Core ─────────────┐        ┌──────── App/Infrastructure ──┴──┐
│ LLMProvider, AgentTool, ToolRegistry│◀──────│ InMemory…Repository, Simulated… │
│ ContextUsage, Logger, UserFacingError│      │ (Ollama/LM Studio in Phase 2)   │
└───────────────────────────────────┘        └──────────────────────────────────┘
          App/Shared: design system, components, formatting (used by Views)
```

Read in this order:

1. [overview.md](architecture/overview.md): layers and what belongs where.
2. [feature-architecture.md](architecture/feature-architecture.md): anatomy of a feature.
3. [dependency-rules.md](architecture/dependency-rules.md): allowed dependencies and how they are enforced.
4. [concurrency.md](architecture/concurrency.md): isolation, streaming and cancellation.

Key decisions are recorded as ADRs in [decisions/](decisions/README.md).
