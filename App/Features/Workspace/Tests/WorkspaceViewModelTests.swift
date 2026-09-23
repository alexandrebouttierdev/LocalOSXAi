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
            models: ModelsViewModel(catalog: ModelCatalog(providers: [
                MockLLMProvider(id: "fake", displayName: "Fake", models: .success(models))
            ])),
            agentService: agent,
            toolDefinitions: [],
            isSimulated: false
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
        #expect(workspace.disabledReason(for: .searchFiles) == "Available in Phase 3")
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

        #expect(workspace.selectedSession?.messages.count == 2)
        #expect(workspace.selectedSession?.title == "Summarize the README")

        let sessionID = try #require(workspace.selectedSessionID)
        await workspace.createSession()
        await workspace.selectSession(sessionID)
        #expect(workspace.activeAgent === agent)
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
