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
    let services: WorkspaceServices
    /// Builds providers from settings; called again whenever settings change.
    let makeProviders: @Sendable (ProviderSettings) -> [any LLMProvider]

    /// Set `LOCALOSXAI_SIMULATED=1` to run the UI without any model server.
    static func current() -> AppEnvironment {
        ProcessInfo.processInfo.environment["LOCALOSXAI_SIMULATED"] == "1" ? simulated() : live()
    }

    /// Real providers from the saved settings and the tool-using agent.
    /// Phase 5 replaces the in-memory repositories.
    static func live() -> AppEnvironment {
        let store = UserDefaultsProviderSettingsStore()
        let registry = ProviderRegistry(providers: ProviderFactory.providers(for: store.load()))
        let runner = PosixCommandRunner()
        let git = CLIGitService(runner: runner)
        let tracker = ChangeTracker()
        let tools = builtInTools(runner: runner, git: git)
        let agent = AgentRuntime(resolver: registry, tools: tools, instructionsLoader: FileProjectInstructionsLoader(),
                                 changeRecorder: tracker)
        return AppEnvironment(
            projectRepository: InMemoryProjectRepository(),
            sessionRepository: InMemorySessionRepository(),
            settingsStore: store,
            registry: registry,
            services: WorkspaceServices(agentService: agent, commandRunner: runner, git: git, changeTracker: tracker,
                                        fileBrowser: LocalFileBrowser(), toolDefinitions: tools.definitions, isSimulated: false),
            makeProviders: ProviderFactory.providers(for:)
        )
    }

    /// Scripted agent and a fixed simulated model: for UI work and demos.
    /// The terminal, Git and Files tabs still work on real folders.
    static func simulated() -> AppEnvironment {
        let runner = PosixCommandRunner()
        return AppEnvironment(
            projectRepository: InMemoryProjectRepository(),
            sessionRepository: InMemorySessionRepository(),
            settingsStore: InMemoryProviderSettingsStore(),
            registry: ProviderRegistry(providers: [SimulatedLLMProvider()]),
            services: WorkspaceServices(agentService: SimulatedAgentService(), commandRunner: runner, git: CLIGitService(runner: runner),
                                        changeTracker: ChangeTracker(), fileBrowser: LocalFileBrowser(), toolDefinitions: [],
                                        isSimulated: true),
            makeProviders: { _ in [SimulatedLLMProvider()] }
        )
    }

    /// The built-in tools. Their names are constants, so a registration
    /// failure is a programming error caught by the first launch and by tests.
    static func builtInTools(runner: any CommandRunner, git: any GitService) -> ToolRegistry {
        let tools: [any AgentTool] = FileSystemTools.all() + [
            RunCommandTool(runner: runner), GitStatusTool(git: git), GitDiffTool(git: git), GitLogTool(git: git)
        ]
        do {
            return try ToolRegistry(tools)
        } catch {
            preconditionFailure("Invalid built-in tool registry: \(error)")
        }
    }

    func makeWorkspaceViewModel() -> WorkspaceViewModel {
        WorkspaceViewModel(
            projects: ProjectsViewModel(service: ProjectService(repository: projectRepository)),
            sessions: SessionsViewModel(service: SessionService(repository: sessionRepository)),
            models: ModelsViewModel(registry: registry),
            services: services
        )
    }

    func makeProviderSettingsViewModel(models: ModelsViewModel) -> ProviderSettingsViewModel {
        let makeProviders = makeProviders
        return ProviderSettingsViewModel(store: settingsStore) { settings in
            await models.reconfigure(providers: makeProviders(settings))
        }
    }
}
