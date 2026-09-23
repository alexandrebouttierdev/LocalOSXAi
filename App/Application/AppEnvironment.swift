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
    let settingsStore: any ProviderSettingsStore
    let registry: ProviderRegistry
    let agentService: any AgentService
    let toolRegistry: ToolRegistry
    /// Builds providers from settings; called again whenever settings change.
    let makeProviders: @Sendable (ProviderSettings) -> [any LLMProvider]
    /// True when the agent and providers are simulated.
    let isSimulated: Bool

    /// Set `LOCALOSXAI_SIMULATED=1` to run the UI without any model server.
    static func current() -> AppEnvironment {
        ProcessInfo.processInfo.environment["LOCALOSXAI_SIMULATED"] == "1" ? simulated() : live()
    }

    /// Real providers from the saved settings, streaming chat without tools
    /// (Phase 2). Phase 3 replaces `agentService` and `toolRegistry`,
    /// Phase 5 the repositories.
    static func live() -> AppEnvironment {
        let store = UserDefaultsProviderSettingsStore()
        let registry = ProviderRegistry(providers: ProviderFactory.providers(for: store.load()))
        return AppEnvironment(
            projectRepository: InMemoryProjectRepository(),
            sessionRepository: InMemorySessionRepository(),
            settingsStore: store,
            registry: registry,
            agentService: DirectChatAgentService(resolver: registry),
            toolRegistry: .empty,
            makeProviders: ProviderFactory.providers(for:),
            isSimulated: false
        )
    }

    /// Scripted agent and a fixed simulated model: for UI work and demos.
    static func simulated() -> AppEnvironment {
        AppEnvironment(
            projectRepository: InMemoryProjectRepository(),
            sessionRepository: InMemorySessionRepository(),
            settingsStore: InMemoryProviderSettingsStore(),
            registry: ProviderRegistry(providers: [SimulatedLLMProvider()]),
            agentService: SimulatedAgentService(),
            toolRegistry: .empty,
            makeProviders: { _ in [SimulatedLLMProvider()] },
            isSimulated: true
        )
    }

    func makeWorkspaceViewModel() -> WorkspaceViewModel {
        WorkspaceViewModel(
            projects: ProjectsViewModel(service: ProjectService(repository: projectRepository)),
            sessions: SessionsViewModel(service: SessionService(repository: sessionRepository)),
            models: ModelsViewModel(registry: registry),
            agentService: agentService,
            toolDefinitions: toolRegistry.definitions,
            isSimulated: isSimulated
        )
    }

    func makeProviderSettingsViewModel(models: ModelsViewModel) -> ProviderSettingsViewModel {
        let makeProviders = makeProviders
        return ProviderSettingsViewModel(store: settingsStore) { settings in
            await models.reconfigure(providers: makeProviders(settings))
        }
    }
}
