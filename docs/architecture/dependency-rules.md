# Dependency rules

## Direction

```
View ─▶ ViewModel ─▶ Service / use case ─▶ Protocol ◀─ Infrastructure
                                             ▲
                         Application (composition root) wires them
```

Two chains matter most:

```
AgentViewModel ─▶ AgentService ─▶ LLMProvider ◀─ OllamaProvider / LMStudioProvider
AgentViewModel ─▶ AgentService ─▶ ToolExecutor ─▶ AgentTool ◀─ FileSystemTool / TerminalTool / GitTool
```

(`ToolExecutor` and the concrete tools arrive in Phases 3–4.)

## Rules

| # | Rule | Why | Enforced by |
|---|---|---|---|
| 1 | Views never use `URLSession`, `Process`, `FileManager`, storage, repositories or providers | Views must stay replaceable and free of side effects; `body` can run at any time | `check-architecture.sh` |
| 2 | ViewModels, Services and Models do not import SwiftUI | They must be testable without a UI, and SwiftUI types leak rendering concerns | `check-architecture.sh` |
| 3 | Only `App/Application` references infrastructure types (`InMemory…`, `Simulated…`, providers) | One place to swap implementations | `check-architecture.sh` |
| 4 | `Core` does not depend on Features or Infrastructure | Core is the stable base and a future package | `check-architecture.sh` |
| 5 | `Core` code never mentions a concrete provider | The agent must be provider-agnostic (ADR 0004) | `check-architecture.sh` |
| 6 | No `print`; use `Logger(category:)` | Structured logs and privacy controls | `check-architecture.sh` |
| 7 | `TODO(reason)` only | No anonymous debt | `check-architecture.sh` |
| 8 | Cross-feature dependencies: one direction, models only | Avoid cycles between features | Review |
| 9 | No singletons or global mutable state | Testability, explicit dependencies | Review, SwiftLint |

Comments are excluded from the checks: documentation may name providers or implementations.

## Allowed exceptions

- Views may call platform UI services that are purely presentational, such as
  `NSWorkspace.activateFileViewerSelecting` for “Reveal in Finder”.
- `SettingsView` uses `@AppStorage` for appearance, a UI preference with no business meaning.

Any other exception needs an ADR.
