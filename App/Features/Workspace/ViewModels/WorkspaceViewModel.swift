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
    let toolDefinitions: [ToolDefinition]
    /// True in simulated mode (`LOCALOSXAI_SIMULATED=1`): no model is called.
    let isSimulated: Bool

    private(set) var selectedProjectID: Project.ID?
    private(set) var selectedSessionID: Session.ID?
    private(set) var activeAgent: AgentViewModel?
    var selectedTab: MainTab = .agent
    var isSidebarVisible = true
    var isInspectorPresented = true
    var isCommandPalettePresented = false
    var isProjectImporterPresented = false

    private let agentService: any AgentService
    private var agents: [Session.ID: AgentViewModel] = [:]
    private var paletteModelIDs: [String: AIModel.ID] = [:]

    init(projects: ProjectsViewModel, sessions: SessionsViewModel, models: ModelsViewModel,
         agentService: any AgentService, toolDefinitions: [ToolDefinition], isSimulated: Bool) {
        self.projects = projects
        self.sessions = sessions
        self.models = models
        self.agentService = agentService
        self.toolDefinitions = toolDefinitions
        self.isSimulated = isSimulated
    }

    // MARK: Derived state

    var selectedProject: Project? { projects.project(id: selectedProjectID) }
    var selectedSession: Session? { sessions.session(id: selectedSessionID) }

    var sidebarSelection: SidebarItem? {
        if let selectedSessionID { return .session(selectedSessionID) }
        return selectedProjectID.map(SidebarItem.project)
    }

    /// First pending error across child view models, for a single alert.
    var currentError: UserFacingError? { projects.error ?? sessions.error }

    func dismissError() {
        if projects.error != nil { projects.error = nil } else { sessions.error = nil }
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
        guard projects.project(id: id) != nil else { return }
        selectedProjectID = id
        await sessions.load(projectID: id)
        activateSession(sessions.sessions.first?.id)
    }

    /// Selects a session, switching project first when it belongs to another one.
    func selectSession(_ id: Session.ID) async {
        guard let session = sessions.session(id: id) else { return }
        if session.projectID != selectedProjectID {
            selectedProjectID = session.projectID
            await sessions.load(projectID: session.projectID)
        }
        activateSession(id)
        selectedTab = .agent
    }

    func openProject(at url: URL) async {
        guard let project = await projects.open(url) else { return }
        await selectProject(project.id)
    }

    func createSession() async {
        guard selectedProjectID != nil, let session = await sessions.createSession(model: models.selectedModelID) else { return }
        activateSession(session.id)
        selectedTab = .agent
    }

    private func activateSession(_ id: Session.ID?) {
        selectedSessionID = id
        activeAgent = id.flatMap(agent(for:))
    }

    /// Returns the cached conversation for a session, creating it on first use.
    /// Cached view models keep running when the user switches sessions.
    private func agent(for sessionID: Session.ID) -> AgentViewModel? {
        if let existing = agents[sessionID] { return existing }
        guard let session = sessions.session(id: sessionID),
              let project = projects.project(id: session.projectID) else { return nil }

        let agent = AgentViewModel(
            sessionID: session.id,
            projectRoot: project.rootURL,
            messages: session.messages,
            agentService: agentService,
            currentModel: { [weak models] in models?.selectedModelID },
            persist: { [weak self] sessionID, messages in
                await self?.persist(messages, in: sessionID)
            }
        )
        agents[sessionID] = agent
        return agent
    }

    private func persist(_ messages: [AgentMessage], in sessionID: Session.ID) async {
        await sessions.updateMessages(messages, model: models.selectedModelID, in: sessionID)
    }

    // MARK: Commands

    func isEnabled(_ command: WorkspaceCommand) -> Bool {
        disabledReason(for: command) == nil
    }

    func disabledReason(for command: WorkspaceCommand) -> String? {
        switch command {
        case .openProject, .toggleSidebar, .toggleInspector, .openSettings:
            nil
        case .newSession, .showAgent, .showFiles, .showChanges, .openTerminal:
            selectedProjectID == nil ? "Open a project first" : nil
        case .searchFiles:
            "Available in Phase 4"
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
        case .changeModel: showModelPalette()
        case .toggleSidebar: isSidebarVisible.toggle()
        case .toggleInspector: isInspectorPresented.toggle()
        case .openSettings: return .openSettings
        case .searchFiles, .showAgent, .showFiles, .showChanges, .openTerminal: break
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
