import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("WorkspaceViewModel", .timeLimit(.minutes(1)))
struct WorkspaceViewModelTests {
    private func makeWorkspace(
        projects: [Project] = [],
        sessions: [Session] = [],
        models: [AIModel] = [Fixtures.model("m", capabilities: [.tools])],
        agent: StubAgentService = StubAgentService(.events([.finished(.completed)]))
    ) -> WorkspaceViewModel {
        WorkspaceViewModel(
            projects: ProjectsViewModel(service: ProjectService(repository: InMemoryProjectRepository(projects: projects))),
            sessions: SessionsViewModel(service: SessionService(repository: InMemorySessionRepository(sessions: sessions))),
            models: ModelsViewModel(registry: ProviderRegistry(providers: [
                MockLLMProvider(id: "fake", displayName: "Fake", models: .success(models))
            ])),
            services: .stub(agent: agent)
        )
    }

    @Test("loading selects the most recent project and resumes its latest session")
    func loadResumesLatest() async {
        let project = Fixtures.project()
        let older = Fixtures.session(projectID: project.id, title: "Old", updatedAt: Date(timeIntervalSinceReferenceDate: 1))
        let newer = Fixtures.session(projectID: project.id, title: "New", updatedAt: Date(timeIntervalSinceReferenceDate: 2))
        let workspace = makeWorkspace(projects: [project], sessions: [older, newer])

        await workspace.load()

        #expect(workspace.selectedProjectID == project.id)
        #expect(workspace.selectedSessionID == newer.id)
        #expect(workspace.activeAgent?.sessionID == newer.id)
        #expect(workspace.sidebarSelection == .session(newer.id))
        #expect(workspace.models.selectedModel?.name == "m")
    }

    @Test("without projects, project commands are disabled with a reason")
    func commandsWithoutProject() async {
        let workspace = makeWorkspace()
        await workspace.load()

        #expect(workspace.isEnabled(.openProject))
        #expect(!workspace.isEnabled(.newSession))
        #expect(workspace.disabledReason(for: .openTerminal) == "Open a project first")
        #expect(workspace.disabledReason(for: .searchFiles) == "Open a project first")
    }

    @Test("change model is disabled when no model is available")
    func changeModelWithoutModels() async {
        let workspace = makeWorkspace(models: [])
        await workspace.load()
        #expect(!workspace.isEnabled(.changeModel))
    }

    @Test("navigation and window commands update state")
    func performCommands() async {
        let workspace = makeWorkspace(projects: [Fixtures.project()])
        await workspace.load()

        workspace.perform(.showChanges)
        #expect(workspace.selectedTab == .changes)
        workspace.perform(.openTerminal)
        #expect(workspace.selectedTab == .terminal)
        workspace.perform(.toggleSidebar)
        #expect(!workspace.isSidebarVisible)
        workspace.perform(.toggleInspector)
        #expect(!workspace.isInspectorPresented)
        workspace.perform(.openProject)
        #expect(workspace.isProjectImporterPresented)
        #expect(workspace.perform(.openSettings) == .openSettings)
    }

    @Test("each project gets its own panels, kept when switching back")
    func projectPanels() async throws {
        let first = Fixtures.project(name: "First", openedAt: Date(timeIntervalSinceReferenceDate: 2))
        let second = Fixtures.project(name: "Second", root: URL(fileURLWithPath: "/tmp/Second"),
                                      openedAt: Date(timeIntervalSinceReferenceDate: 1))
        let workspace = makeWorkspace(projects: [first, second])
        await workspace.load()
        let firstTerminal = try #require(workspace.activePanels?.terminal)
        #expect(firstTerminal.projectRoot == first.rootURL)

        await workspace.selectProject(second.id)
        #expect(workspace.activePanels?.terminal.projectRoot == second.rootURL)
        await workspace.selectProject(first.id)
        #expect(workspace.activePanels?.terminal === firstTerminal)
    }

    @Test("search files opens the Files tab and asks to focus its search")
    func searchFiles() async throws {
        let workspace = makeWorkspace(projects: [Fixtures.project()])
        await workspace.load()
        let files = try #require(workspace.activePanels?.files)
        let before = files.searchFocusRequest

        workspace.perform(.searchFiles)

        #expect(workspace.selectedTab == .files)
        #expect(files.searchFocusRequest == before + 1)
    }

    @Test("disabled commands have no effect")
    func disabledCommandIsNoOp() async {
        let workspace = makeWorkspace()
        await workspace.load()
        workspace.perform(.showChanges)
        #expect(workspace.selectedTab == .agent)
    }

    @Test("creating a session activates it on the agent tab")
    func createSession() async {
        let workspace = makeWorkspace(projects: [Fixtures.project()])
        await workspace.load()
        workspace.selectedTab = .files

        await workspace.createSession()

        #expect(workspace.selectedSessionID != nil)
        #expect(workspace.activeAgent?.sessionID == workspace.selectedSessionID)
        #expect(workspace.selectedTab == .agent)
        #expect(workspace.selectedSession?.model == workspace.models.selectedModelID)
    }

    @Test("selecting a session from another project switches project")
    func selectSessionInOtherProject() async {
        let first = Fixtures.project(name: "First", openedAt: Date(timeIntervalSinceReferenceDate: 2))
        let second = Fixtures.project(name: "Second", root: URL(fileURLWithPath: "/tmp/Second"),
                                      openedAt: Date(timeIntervalSinceReferenceDate: 1))
        let foreign = Fixtures.session(projectID: second.id, title: "Elsewhere")
        let workspace = makeWorkspace(projects: [first, second], sessions: [foreign])
        await workspace.load()
        #expect(workspace.selectedProjectID == first.id)
        #expect(workspace.sessions.recentSessions.map(\.id) == [foreign.id])

        await workspace.select(.session(foreign.id))

        #expect(workspace.selectedProjectID == second.id)
        #expect(workspace.selectedSessionID == foreign.id)
    }

    @Test("agent conversations are cached per session and persisted after a run")
    func agentPersistence() async throws {
        let workspace = makeWorkspace(
            projects: [Fixtures.project()],
            agent: StubAgentService(.events([.assistantMessageStarted(id: UUID()), .textDelta("Done"), .finished(.completed)]))
        )
        await workspace.load()
        await workspace.createSession()
        let agent = try #require(workspace.activeAgent)

        agent.draft = "Summarize the README"
        agent.send()
        await agent.waitUntilIdle()

        let sessionID = try #require(workspace.selectedSessionID)
        // Lists hold summaries; the saved transcript is read back in full.
        #expect(workspace.selectedSession?.messages.isEmpty == true)
        #expect(await workspace.sessions.fullSession(id: sessionID)?.messages.count == 2)
        #expect(workspace.selectedSession?.title == "Summarize the README")

        await workspace.createSession()
        await workspace.selectSession(sessionID)
        #expect(workspace.activeAgent === agent)
    }

    @Test("opening a session loads its full transcript, which lists do not carry")
    func opensFullTranscript() async throws {
        let project = Fixtures.project()
        let message = AgentMessage(role: .user, text: "Hello", createdAt: Date(timeIntervalSinceReferenceDate: 0))
        let session = Fixtures.session(projectID: project.id, messages: [message])
        let workspace = makeWorkspace(projects: [project], sessions: [session])

        await workspace.load()

        #expect(workspace.sessions.sessions.first?.messages.isEmpty == true)
        #expect(workspace.activeAgent?.messages == [message])
    }

    @Test("removing a project deletes its sessions and selects the next project")
    func removeProject() async throws {
        let first = Fixtures.project(name: "First", openedAt: Date(timeIntervalSinceReferenceDate: 2))
        let second = Fixtures.project(name: "Second", openedAt: Date(timeIntervalSinceReferenceDate: 1))
        let session = Fixtures.session(projectID: first.id)
        let workspace = makeWorkspace(projects: [first, second], sessions: [session])
        await workspace.load()
        #expect(workspace.selectedSessionID == session.id)

        await workspace.removeProject(first.id)

        #expect(workspace.projects.projects.map(\.id) == [second.id])
        #expect(workspace.selectedProjectID == second.id)
        #expect(workspace.selectedSessionID == nil)
        #expect(await workspace.sessions.fullSession(id: session.id) == nil)
        #expect(workspace.sessions.recentSessions.isEmpty)
    }

    @Test("the window title names the session on the Agent tab and the project elsewhere")
    func windowTitle() async {
        let project = Fixtures.project(name: "Candilog")
        let session = Fixtures.session(projectID: project.id, title: "Build the landing page")
        let workspace = makeWorkspace(projects: [project], sessions: [session])
        #expect(workspace.windowTitle == "LocalOSXAi")
        #expect(workspace.windowSubtitle.isEmpty)

        await workspace.load()
        #expect(workspace.windowTitle == "Build the landing page")
        #expect(workspace.windowSubtitle == "Candilog")

        workspace.selectedTab = .files
        #expect(workspace.windowTitle == "Candilog")
        #expect(workspace.windowSubtitle.isEmpty)
    }

    @Test("a storage failure at launch is reported once")
    func storageError() {
        var services = WorkspaceServices.stub(agent: StubAgentService(.events([])))
        services.storageError = PersistenceError.openFailed("disk full")
        let workspace = WorkspaceViewModel(
            projects: ProjectsViewModel(service: ProjectService(repository: InMemoryProjectRepository())),
            sessions: SessionsViewModel(service: SessionService(repository: InMemorySessionRepository())),
            models: ModelsViewModel(registry: ProviderRegistry(providers: [])),
            services: services
        )
        #expect(workspace.currentError?.title == "History is not being saved")
        workspace.dismissError()
        #expect(workspace.currentError == nil)
    }

    @Test("project and model settings reach the run request")
    func settingsReachRun() async throws {
        let agentService = StubAgentService(.events([.finished(.completed)]))
        let project = Fixtures.project()
        let workspace = makeWorkspace(projects: [project], agent: agentService)
        await workspace.load()
        await workspace.createSession()
        await workspace.projects.setIncludesClaudeInstructions(true, for: project.id)
        await workspace.projects.addAllowedCommandPrefix("npm install", for: project.id)
        let model = try #require(workspace.models.selectedModelID)
        await workspace.models.updateSettings(ModelSettings(temperature: 0.4, reasoning: .off), for: model)
        let agent = try #require(workspace.activeAgent)

        agent.draft = "Go"
        agent.send()
        await agent.waitUntilIdle()

        let options = try #require(agentService.requests.last?.options)
        #expect(options.includesClaudeInstructions)
        #expect(options.commandRules.allowedPrefixes == ["npm install"])
        #expect(options.generation == GenerationOptions(temperature: 0.4, reasoning: .off))
    }

    @Test("project settings open for the selected project, selecting it first from the sidebar")
    func projectSettings() async {
        let first = Fixtures.project(name: "First", openedAt: Date(timeIntervalSinceReferenceDate: 2))
        let second = Fixtures.project(name: "Second", openedAt: Date(timeIntervalSinceReferenceDate: 1))
        let workspace = makeWorkspace(projects: [first, second])
        #expect(!workspace.isEnabled(.projectSettings))
        await workspace.load()

        workspace.perform(.projectSettings)
        #expect(workspace.isProjectSettingsPresented)

        workspace.isProjectSettingsPresented = false
        await workspace.showProjectSettings(for: second.id)
        #expect(workspace.selectedProjectID == second.id)
        #expect(workspace.isProjectSettingsPresented)
    }

    @Test("the command palette lists every command with its shortcut and state")
    func paletteCommands() async {
        let workspace = makeWorkspace()
        await workspace.load()

        workspace.showCommandPalette()

        #expect(workspace.isCommandPalettePresented)
        let item = workspace.palette.results.first { $0.id == WorkspaceCommand.openProject.rawValue }
        #expect(item?.shortcut == "⌘O")
        let disabled = workspace.palette.results.first { $0.id == WorkspaceCommand.newSession.rawValue }
        #expect(disabled?.isEnabled == false)
        #expect(workspace.palette.results.count == WorkspaceCommand.allCases.count)
    }

    @Test("activating a command runs it and closes the palette")
    func activateCommand() async throws {
        let workspace = makeWorkspace()
        await workspace.load()
        workspace.showCommandPalette()
        let item = try #require(workspace.palette.results.first { $0.id == WorkspaceCommand.toggleInspector.rawValue })

        _ = workspace.activatePaletteItem(item)

        #expect(!workspace.isCommandPalettePresented)
        #expect(!workspace.isInspectorPresented)
    }

    @Test("change model switches the palette to a model list, then selects")
    func changeModelFlow() async throws {
        let workspace = makeWorkspace(models: [Fixtures.model("alpha", capabilities: [.tools]), Fixtures.model("beta")])
        await workspace.load()
        workspace.showCommandPalette()
        let changeModel = try #require(workspace.palette.results.first { $0.id == WorkspaceCommand.changeModel.rawValue })

        _ = workspace.activatePaletteItem(changeModel)
        #expect(workspace.isCommandPalettePresented)
        #expect(workspace.palette.results.map(\.title) == ["alpha", "beta"])
        #expect(workspace.palette.results.first?.subtitle == "Current")

        let beta = try #require(workspace.palette.results.last)
        _ = workspace.activatePaletteItem(beta)
        #expect(!workspace.isCommandPalettePresented)
        #expect(workspace.models.selectedModel?.name == "beta")
    }

    @Test("errors from child view models are surfaced and dismissed one at a time")
    func errorAggregation() async {
        let workspace = makeWorkspace()
        _ = await workspace.projects.open(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))
        #expect(workspace.currentError?.title == "Could not open project")
        workspace.dismissError()
        #expect(workspace.currentError == nil)
    }
}

@Suite("CommandShortcut")
struct CommandShortcutTests {
    @Test("modifiers are displayed in macOS order")
    func displayOrder() {
        #expect(CommandShortcut("s", modifiers: [.command, .control]).displayString == "⌃⌘S")
        #expect(CommandShortcut("i", modifiers: [.command, .option]).displayString == "⌥⌘I")
        #expect(CommandShortcut("k").displayString == "⌘K")
    }

    @Test("every command shortcut is unique")
    func uniqueShortcuts() {
        let shortcuts = WorkspaceCommand.allCases.compactMap(\.shortcut)
        #expect(Set(shortcuts).count == shortcuts.count)
    }
}
