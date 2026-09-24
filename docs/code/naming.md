# Naming

Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
Project-specific conventions:

| Kind | Convention | Examples |
|---|---|---|
| Views | `…View` | `AgentView`, `SidebarView`, `ToolCallView` |
| ViewModels | `…ViewModel` | `AgentViewModel`, `WorkspaceViewModel` |
| Use cases | `…Service` (a struct of related use cases) | `ProjectService`, `SessionService` |
| Storage ports | `…Repository` | `ProjectRepository`, `SessionRepository` |
| Storage implementations | technology prefix | `InMemoryProjectRepository`, `SQLiteSessionRepository` |
| Providers | `…Provider` | `LLMProvider`, `OllamaProvider` (Phase 2) |
| Tools | `…Tool`; model-facing names in `snake_case` | `ReadFileTool` → `read_file` |
| Errors | `…Error` enums | `ProviderError`, `ToolError`, `ProjectError` |
| Test doubles | `Fake…` (working behavior), `Mock…` (records and returns canned data), `Stub…` (fixed scripted output) | `FakeLLMProvider`, `MockLLMProvider`, `StubAgentService` |
| Simulations shipped in the app | `Simulated…` | `SimulatedAgentService` |
| Design tokens | `App…` enums | `AppColors.surface`, `AppSpacing.md` |

## Words we use consistently

- **Project**: a folder opened by the user; its root is the tool boundary.
- **Session**: a conversation inside a project.
- **Run**: one execution of the agent for one user message (may contain several model turns).
- **Turn / iteration**: one model call inside a run.
- **Tool call**: a model request to execute a tool; **tool result** is its structured outcome.
- **Provider**: a model server (Ollama, LM Studio…). **Model**: an `AIModel` served by a provider.

Do not introduce synonyms (“chat”, “thread”, “conversation” for sessions) in code.
