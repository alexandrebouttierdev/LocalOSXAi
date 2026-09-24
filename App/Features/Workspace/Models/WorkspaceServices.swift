import Foundation

/// The services a workspace needs, injected by the composition root.
///
/// Grouped so `WorkspaceViewModel` has one dependency instead of a growing
/// initializer, and so tests can swap any of them.
struct WorkspaceServices {
    let agentService: any AgentService
    let commandRunner: any CommandRunner
    let git: any GitService
    let changeTracker: ChangeTracker
    let fileBrowser: any ProjectFileBrowsing
    let toolDefinitions: [ToolDefinition]
    /// True in simulated mode (`LOCALOSXAI_SIMULATED=1`): no model is called.
    let isSimulated: Bool
    /// Why history could not be opened, when the app fell back to memory.
    var storageError: (any Error)?
}

/// The per-project view models behind the Files, Changes and Terminal tabs
/// and the inspector's Git section. Created on first use and kept, so a
/// running command or a review in progress survives switching projects.
@MainActor
struct ProjectPanels {
    let terminal: TerminalViewModel
    let git: GitViewModel
    let changes: ChangesViewModel
    let files: FilesViewModel

    init(projectRoot: URL, services: WorkspaceServices) {
        terminal = TerminalViewModel(projectRoot: projectRoot, runner: services.commandRunner)
        git = GitViewModel(projectRoot: projectRoot, git: services.git)
        changes = ChangesViewModel(projectRoot: projectRoot, tracker: services.changeTracker)
        files = FilesViewModel(projectRoot: projectRoot, browser: services.fileBrowser)
    }
}
