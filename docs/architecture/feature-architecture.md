# Feature architecture

## Anatomy

```
Features/<Name>/
├── Models/       value types of the domain (Sendable, usually Codable)
├── Views/        SwiftUI views: layout and presentation only
├── ViewModels/   @MainActor @Observable state + actions, no SwiftUI import
├── Services/     use cases and the ports (protocols) the feature needs
├── Components/   views reused inside this feature only (optional)
└── Tests/        tests for this feature (compiled into the test target only)
```

Create only the folders you need. An empty folder is not documentation.

## Example: Agent

```
Features/Agent/
├── Models/       AgentMessage, ToolCallRecord, AgentEvent, AgentRunRequest
├── Services/     AgentService (protocol), TranscriptReducer (pure rules)
├── ViewModels/   AgentViewModel (run lifecycle, cancellation)
├── Views/        AgentView, AgentMessageView, ToolCallView, ComposerView
└── Tests/        AgentViewModelTests, TranscriptReducerTests
```

## Rules

1. **A ViewModel orchestrates and a service decides.** Business rules (title derivation,
   de-duplicating projects, ranking palette results) live in services or pure helpers so they
   can be tested synchronously.
2. **Keep ViewModels small.** When one grows past ~200 lines or mixes concerns, extract a pure
   type. `TranscriptReducer` was extracted from `AgentViewModel` for this reason.
3. **The feature owns its ports.** `ProjectRepository` lives in `Projects/Services`, not in
   Infrastructure: the feature says what it needs and storage adapts.
4. **Cross-feature dependencies go one way, on models only.** `Sessions` uses the Agent
   feature's `AgentMessage`, while `Agent` knows nothing about `Sessions`. The workspace joins
   them by injecting a `persist` closure into `AgentViewModel`.
5. **Coordination lives in Workspace.** `WorkspaceViewModel` holds navigation state (selected
   project, session, tab, panels) and sequences feature view models. It holds no business rules.

## Adding a feature

1. Write the models and the port (protocol), if the feature needs external data.
2. Write the tests for the service/ViewModel against a fake of that port.
3. Implement the service and ViewModel, then the views.
4. Implement the port in `Infrastructure/` and wire it in `AppEnvironment`.
5. Add commands to `WorkspaceCommand` if the feature is reachable from the palette or menus.
6. Document it in `docs/` and run `make check`.
