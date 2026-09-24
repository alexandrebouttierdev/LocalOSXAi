import Foundation
import Observation

/// Navigation state of the main window and coordination between features.
///
/// Owns *where the user is* (selected project, session, tab, visible panels)
/// and routes commands. Business rules stay in the feature view models it
/// composes (`ProjectsViewModel`, `SessionsViewModel`, `ModelsViewModel`,
/// `AgentViewModel`); this type only sequences them.
@MainActor
@Observable
final class WorkspaceViewModel {
    /// Where a command leaves the UI, for effects only a view can perform.
    enum Effect: Equatable {
        case none
        case openSettings
    }

    /// Identifies a selectable sidebar row.
    enum SidebarItem: Hashable {
        case project(Project.ID)
        case session(Session.ID)
    }

    let projects: ProjectsViewModel
    let sessions: SessionsViewModel
    let models: ModelsViewModel
    let palette = CommandPaletteViewModel()
    let services: WorkspaceServices
    var toolDefinitions: [ToolDefinition] { services.toolDefinitions }
    var isSimulated: Bool { services.isSimulated }

    private(set) var selectedProjectID: Project.ID?
    private(set) var selectedSessionID: Session.ID?
    private(set) var activeAgent: AgentViewModel?
    /// Terminal, Git, changes and files of the selected project.
    private(set) var activePanels: ProjectPanels?
    var selectedTab: MainTab = .agent
    var isSidebarVisible = true
    var isInspectorPresented = true
    var isCommandPalettePresented = false
    var isProjectImporterPresented = false
    var isProjectSettingsPresented = false

    /// Set when history could not be opened and the app runs on memory only.
    private(set) var storageError: UserFacingError?

    private var agents: [Session.ID: AgentViewModel] = [:]
    private var panels: [Project.ID: ProjectPanels] = [:]
    private var paletteModelIDs: [String: AIModel.ID] = [:]

    init(projects: ProjectsViewModel, sessions: SessionsViewModel, models: ModelsViewModel, services: WorkspaceServices) {
        self.projects = projects
        self.sessions = sessions
        self.models = models
        self.services = services
        storageError = services.storageError.map {
            UserFacingError($0, title: "History is not being saved", category: .persistence)
        }
    }

    // MARK: Derived state

    var selectedProject: Project? { projects.project(id: selectedProjectID) }
    var selectedSession: Session? { sessions.session(id: selectedSessionID) }

    /// Window title: the session on the Agent tab, otherwise the project.
    var windowTitle: String {
        guard let project = selectedProject else { return "LocalOSXAi" }
        if selectedTab == .agent, let session = selectedSession { return session.title }
        return project.name
    }

    /// Window subtitle: the project, when the title names something inside it.
    var windowSubtitle: String {
        guard let project = selectedProject, windowTitle != project.name else { return "" }
        return project.name
    }

    /// Pending file changes, shown as a badge on the Changes tab.
    var pendingChangesCount: Int { activePanels?.changes.changes.count ?? 0 }

    var sidebarSelection: SidebarItem? {
        if let selectedSessionID { return .session(selectedSessionID) }
        return selectedProjectID.map(SidebarItem.project)
    }

    /// First pending error across child view models, for a single alert.
    var currentError: UserFacingError? { storageError ?? projects.error ?? sessions.error }

    func dismissError() {
        if storageError != nil {
            storageError = nil
        } else if projects.error != nil {
            projects.error = nil
        } else {
            sessions.error = nil
        }
    }

    // MARK: Lifecycle and navigation

    func load() async {
        await projects.load()
        await models.refresh()
        if selectedProjectID == nil, let mostRecent = projects.projects.first {
            await selectProject(mostRecent.id)
        }
    }

    func select(_ item: SidebarItem?) async {
        switch item {
        case .project(let id): await selectProject(id)
        case .session(let id): await selectSession(id)
        case nil: break
        }
    }

    /// Selects a project and resumes its most recently updated session.
    func selectProject(_ id: Project.ID) async {
        guard let project = projects.project(id: id) else { return }
        selectedProjectID = id
        activatePanels(for: project)
        await sessions.load(projectID: id)
        await activateSession(sessions.sessions.first?.id)
    }

    private func activatePanels(for project: Project) {
        if panels[project.id] == nil {
            panels[project.id] = ProjectPanels(projectRoot: project.rootURL, services: services)
        }
        activePanels = panels[project.id]
    }

    /// Selects a session, switching project first when it belongs to another one.
    func selectSession(_ id: Session.ID) async {
        guard let session = sessions.session(id: id) else { return }
        if session.projectID != selectedProjectID {
            selectedProjectID = session.projectID
            if let project = projects.project(id: session.projectID) { activatePanels(for: project) }
            await sessions.load(projectID: session.projectID)
        }
        await activateSession(id)
        selectedTab = .agent
    }

    /// Opens the settings of a project, selecting it first.
    func showProjectSettings(for id: Project.ID) async {
        if selectedProjectID != id { await selectProject(id) }
        isProjectSettingsPresented = selectedProjectID == id
    }

    /// Forgets a project and its sessions (the folder on disk is untouched).
    func removeProject(_ id: Project.ID) async {
        for agent in agents.values where agent.projectID == id { agent.cancel() }
        guard await sessions.deleteAll(inProject: id) else { return }
        await projects.remove(id)
        guard projects.project(id: id) == nil else { return }
        agents = agents.filter { $0.value.projectID != id }
        panels[id] = nil
        if selectedProjectID == id {
            selectedProjectID = nil
            activePanels = nil
            await activateSession(nil)
            if let next = projects.projects.first {
                await selectProject(next.id)
                return
            }
        }
        await sessions.load(projectID: selectedProjectID)
    }

    func openProject(at url: URL) async {
        guard let project = await projects.open(url) else { return }
        await selectProject(project.id)
    }

    func createSession() async {
        guard selectedProjectID != nil, let session = await sessions.createSession(model: models.selectedModelID) else { return }
        await activateSession(session.id)
        selectedTab = .agent
    }

    private func activateSession(_ id: Session.ID?) async {
        selectedSessionID = id
        guard let id else {
            activeAgent = nil
            return
        }
        let agent = await agent(for: id)
        // Another selection may have happened while the transcript loaded.
        if selectedSessionID == id { activeAgent = agent }
    }

    /// Returns the cached conversation for a session, loading its transcript
    /// on first use. Cached view models keep running when the user switches sessions.
    private func agent(for sessionID: Session.ID) async -> AgentViewModel? {
        if let existing = agents[sessionID] { return existing }
        guard let session = await sessions.fullSession(id: sessionID),
              let project = projects.project(id: session.projectID) else { return nil }
        if let existing = agents[sessionID] { return existing }

        let projectID = project.id
        let agent = AgentViewModel(
            sessionID: session.id,
            projectID: projectID,
            projectRoot: project.rootURL,
            messages: session.messages,
            agentService: services.agentService,
            currentModel: { [weak models] in models?.selectedModelID },
            runOptions: { [weak self] in self?.runOptions(for: projectID) ?? AgentRunOptions() },
            addCommandRule: { [weak projects] prefix in
                await projects?.addAllowedCommandPrefix(prefix, for: projectID)
            },
            persist: { [weak self] sessionID, messages in
                await self?.persist(messages, in: sessionID)
            }
        )
        agents[sessionID] = agent
        return agent
    }

    /// Settings for the next run: the project's, plus the selected model's.
    private func runOptions(for projectID: Project.ID) -> AgentRunOptions {
        let project = projects.project(id: projectID)
        return AgentRunOptions(
            includesClaudeInstructions: project?.includesClaudeInstructions ?? false,
            commandRules: project?.commandRules ?? CommandRules(),
            generation: models.generationOptions(for: models.selectedModelID)
        )
    }

    /// Saves the transcript after a run and refreshes what the run may have changed.
    private func persist(_ messages: [AgentMessage], in sessionID: Session.ID) async {
        await sessions.updateMessages(messages, model: models.selectedModelID, in: sessionID)
        guard let panels = activePanels else { return }
        await panels.changes.refresh()
        await panels.git.refresh()
    }

    // MARK: Commands

    func isEnabled(_ command: WorkspaceCommand) -> Bool {
        disabledReason(for: command) == nil
    }

    func disabledReason(for command: WorkspaceCommand) -> String? {
        switch command {
        case .openProject, .toggleSidebar, .toggleInspector, .openSettings:
            nil
        case .newSession, .projectSettings, .showAgent, .showFiles, .showChanges, .openTerminal, .searchFiles:
            selectedProjectID == nil ? "Open a project first" : nil
        case .changeModel:
            models.allModels.isEmpty ? "No models available" : nil
        }
    }

    /// Performs a command. Returns an effect the calling view must carry out
    /// when the command needs a SwiftUI environment action.
    @discardableResult
    func perform(_ command: WorkspaceCommand) -> Effect {
        guard isEnabled(command) else { return .none }
        if let tab = command.tab {
            selectedTab = tab
            return .none
        }
        switch command {
        case .openProject: isProjectImporterPresented = true
        case .newSession: Task { await createSession() }
        case .projectSettings: isProjectSettingsPresented = true
        case .searchFiles:
            selectedTab = .files
            activePanels?.files.requestSearchFocus()
        case .changeModel: showModelPalette()
        case .toggleSidebar: isSidebarVisible.toggle()
        case .toggleInspector: isInspectorPresented.toggle()
        case .openSettings: return .openSettings
        case .showAgent, .showFiles, .showChanges, .openTerminal: break
        }
        return .none
    }

    // MARK: Command palette

    func showCommandPalette() {
        let items = WorkspaceCommand.allCases.map { command in
            PaletteItem(
                id: command.rawValue,
                title: command.title,
                systemImage: command.systemImage,
                shortcut: command.shortcut?.displayString,
                section: command.section,
                keywords: command.keywords,
                isEnabled: isEnabled(command),
                disabledReason: disabledReason(for: command)
            )
        }
        paletteModelIDs = [:]
        palette.show(items: items, placeholder: "Type a command or search…")
        isCommandPalettePresented = true
    }

    func dismissCommandPalette() {
        isCommandPalettePresented = false
    }

    /// Handles an activated palette row and returns the effect to perform.
    func activatePaletteItem(_ item: PaletteItem) -> Effect {
        if let modelID = paletteModelIDs[item.id] {
            models.select(modelID)
            dismissCommandPalette()
            return .none
        }
        guard let command = WorkspaceCommand(rawValue: item.id) else { return .none }
        if command != .changeModel { dismissCommandPalette() }
        return perform(command)
    }

    private func showModelPalette() {
        var items: [PaletteItem] = []
        paletteModelIDs = [:]
        for group in models.catalog {
            for model in group.models {
                let itemID = "model:\(model.provider.rawValue)/\(model.name)"
                paletteModelIDs[itemID] = model.id
                items.append(PaletteItem(
                    id: itemID,
                    title: model.displayName,
                    subtitle: model.id == models.selectedModelID ? "Current" : nil,
                    systemImage: model.id == models.selectedModelID ? "checkmark" : "cpu",
                    section: group.provider.displayName,
                    keywords: [model.name, group.provider.displayName]
                ))
            }
        }
        palette.show(items: items, placeholder: "Choose a model…")
        isCommandPalettePresented = true
    }
}
