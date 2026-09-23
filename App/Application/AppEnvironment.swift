import Foundation

/// Composition root: the single place where concrete implementations are
/// chosen and wired to the protocols features depend on.
///
/// No other type creates infrastructure objects. Swapping a provider, a store
/// or the agent runtime is a change to this file only
/// (docs/architecture/dependency-rules.md).
@MainActor
struct AppEnvironment {
    let projectRepository: any ProjectRepository
    let sessionRepository: any SessionRepository
    let providers: [any LLMProvider]
    let agentService: any AgentService
    let toolRegistry: ToolRegistry
    /// True while providers and the agent are simulated.
    let isSimulated: Bool

    /// Phase 1 environment: in-memory storage, simulated provider and agent.
    ///
    /// Phase 2 replaces `providers` with Ollama and LM Studio, Phase 3 replaces
    /// `agentService` and `toolRegistry`, Phase 5 replaces the repositories.
    static func simulated() -> AppEnvironment {
        AppEnvironment(
            projectRepository: InMemoryProjectRepository(),
            sessionRepository: InMemorySessionRepository(),
            providers: [SimulatedLLMProvider()],
            agentService: SimulatedAgentService(),
            toolRegistry: .empty,
            isSimulated: true
        )
    }

    func makeWorkspaceViewModel() -> WorkspaceViewModel {
        WorkspaceViewModel(
            projects: ProjectsViewModel(service: ProjectService(repository: projectRepository)),
            sessions: SessionsViewModel(service: SessionService(repository: sessionRepository)),
            models: ModelsViewModel(catalog: ModelCatalog(providers: providers)),
            agentService: agentService,
            toolDefinitions: toolRegistry.definitions,
            isSimulated: isSimulated
        )
    }
}
