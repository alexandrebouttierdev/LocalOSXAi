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
    let modelSettingsRepository: any ModelSettingsRepository
    let settingsStore: any ProviderSettingsStore
    let secretStore: any ProviderSecretStore
    let agentSettingsStore: any AgentSettingsStore
    let registry: ProviderRegistry
    let services: WorkspaceServices
    /// Builds providers from settings; called again whenever settings change.
    let makeProviders: @Sendable (ProviderSettings) -> [any LLMProvider]

    /// Set `LOCALOSXAI_SIMULATED=1` to run the UI without any model server.
    static func current() -> AppEnvironment {
        ProcessInfo.processInfo.environment["LOCALOSXAI_SIMULATED"] == "1" ? simulated() : live()
    }

    /// Real providers from the saved settings, the tool-using agent and the
    /// SQLite history. If the database cannot be opened, the app still runs on
    /// memory and says so; the file is left untouched for the next launch.
    static func live() -> AppEnvironment {
        let store = UserDefaultsProviderSettingsStore()
        let secrets = KeychainProviderSecretStore()
        let agentSettings = UserDefaultsAgentSettingsStore()
        let storage = openStorage()
        let registry = ProviderRegistry(providers: ProviderFactory.providers(for: store.load(), secrets: secrets))
        let runner = PosixCommandRunner()
        let git = CLIGitService(runner: runner)
        let tracker = ChangeTracker(store: storage.changeOriginals)
        let tools = builtInTools(runner: runner, git: git)
        let agent = AgentRuntime(resolver: registry, tools: tools, instructionsLoader: FileProjectInstructionsLoader(),
                                 limits: { agentLimits(from: agentSettings.load()) }, changeRecorder: tracker)
        return AppEnvironment(
            projectRepository: storage.projects,
            sessionRepository: storage.sessions,
            modelSettingsRepository: storage.modelSettings,
            settingsStore: store,
            secretStore: secrets,
            agentSettingsStore: agentSettings,
            registry: registry,
            services: WorkspaceServices(agentService: agent, commandRunner: runner, git: git, changeTracker: tracker,
                                        fileBrowser: LocalFileBrowser(), isSimulated: false,
                                        storageError: storage.error, attachmentLoader: LocalAttachmentLoader(),
                                        notifier: SystemUserNotifier(), appInfo: bundleInfo,
                                        notificationPreferences: { notificationPreferences(from: agentSettings.load()) },
                                        releaseChecker: GitHubReleaseChecker(owner: AppInfo.repositoryOwner,
                                                                             repository: AppInfo.repositoryName,
                                                                             appVersion: bundleInfo.version),
                                        checksForUpdatesAtLaunch: { agentSettings.load().checksForUpdates }),
            makeProviders: { ProviderFactory.providers(for: $0, secrets: secrets) }
        )
    }

    private struct Storage {
        let projects: any ProjectRepository
        let sessions: any SessionRepository
        let modelSettings: any ModelSettingsRepository
        let changeOriginals: (any ChangeOriginalsStore)?
        let error: (any Error)?
    }

    private static func openStorage() -> Storage {
        do {
            let database = try AppDatabase.open(at: try AppDatabase.defaultURL())
            return Storage(projects: SQLiteProjectRepository(database: database),
                           sessions: SQLiteSessionRepository(database: database),
                           modelSettings: SQLiteModelSettingsRepository(database: database),
                           changeOriginals: SQLiteChangeOriginalsStore(database: database), error: nil)
        } catch {
            return Storage(projects: InMemoryProjectRepository(), sessions: InMemorySessionRepository(),
                           modelSettings: InMemoryModelSettingsRepository(), changeOriginals: nil, error: error)
        }
    }

    nonisolated static func agentLimits(from settings: AgentSettings) -> AgentLimits {
        AgentLimits(maxIterations: settings.maxIterations, toolTimeout: .seconds(settings.toolTimeoutSeconds),
                    summarizesHistory: settings.summarizesHistory,
                    summaryStartRatio: Double(settings.compactThresholdPercent) / 100,
                    customInstructions: settings.customInstructions)
    }

    /// The running app's version, from its Info.plist.
    static var bundleInfo: AppInfo { AppInfo(infoDictionary: Bundle.main.infoDictionary ?? [:]) }

    nonisolated static func notificationPreferences(from settings: AgentSettings) -> NotificationPreferences {
        NotificationPreferences(showsNotifications: settings.showsNotifications, playsSound: settings.playsSound)
    }

    /// Scripted agent and a fixed simulated model: for UI work and demos.
    /// The terminal, Git and Files tabs still work on real folders.
    /// `LOCALOSXAI_DEMO_PROJECT=<folder>` opens that folder at launch, so UI
    /// snapshots (`make ui-snapshots`) start inside a project.
    static func simulated() -> AppEnvironment {
        let runner = PosixCommandRunner()
        let demo = ProcessInfo.processInfo.environment["LOCALOSXAI_DEMO_PROJECT"].map { path in
            let root = ProjectService.normalized(URL(fileURLWithPath: path, isDirectory: true))
            return Project(id: UUID(), name: root.lastPathComponent, rootURL: root, createdAt: .now, lastOpenedAt: .now)
        }
        return AppEnvironment(
            projectRepository: InMemoryProjectRepository(projects: demo.map { [$0] } ?? []),
            sessionRepository: InMemorySessionRepository(),
            modelSettingsRepository: InMemoryModelSettingsRepository(),
            settingsStore: InMemoryProviderSettingsStore(),
            secretStore: InMemoryProviderSecretStore(),
            agentSettingsStore: InMemoryAgentSettingsStore(),
            registry: ProviderRegistry(providers: [SimulatedLLMProvider()]),
            services: WorkspaceServices(agentService: SimulatedAgentService(), commandRunner: runner, git: CLIGitService(runner: runner),
                                        changeTracker: ChangeTracker(), fileBrowser: LocalFileBrowser(),
                                        isSimulated: true, attachmentLoader: LocalAttachmentLoader(), appInfo: bundleInfo),
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
            models: ModelsViewModel(registry: registry, settingsRepository: modelSettingsRepository),
            services: services
        )
    }

    func makeAgentSettingsViewModel() -> AgentSettingsViewModel {
        AgentSettingsViewModel(store: agentSettingsStore, notifier: services.notifier,
                               builtInPrompt: AgentPrompt.system(projectName: "Project", instructions: [], toolsEnabled: true))
    }

    func makeProviderSettingsViewModel(models: ModelsViewModel) -> ProviderSettingsViewModel {
        let makeProviders = makeProviders
        return ProviderSettingsViewModel(store: settingsStore, secrets: secretStore) { settings in
            await models.reconfigure(providers: makeProviders(settings))
        }
    }
}
