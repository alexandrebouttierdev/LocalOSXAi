import Foundation

/// Every user action reachable from the menu bar and the command palette.
///
/// Declaring commands once guarantees that the menu, the palette and the
/// shortcuts shown in both stay consistent.
enum WorkspaceCommand: String, CaseIterable, Identifiable, Sendable {
    case openProject
    case newSession
    case searchFiles
    case changeModel
    case showAgent
    case showFiles
    case showChanges
    case openTerminal
    case toggleSidebar
    case toggleInspector
    case openSettings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openProject: "Open Project…"
        case .newSession: "New Session"
        case .searchFiles: "Search Files…"
        case .changeModel: "Change Model…"
        case .showAgent: "Show Agent"
        case .showFiles: "Show Files"
        case .showChanges: "Show Changes"
        case .openTerminal: "Open Terminal"
        case .toggleSidebar: "Toggle Sidebar"
        case .toggleInspector: "Toggle Inspector"
        case .openSettings: "Open Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .openProject: "folder"
        case .newSession: "square.and.pencil"
        case .searchFiles: "doc.text.magnifyingglass"
        case .changeModel: "cpu"
        case .showAgent: MainTab.agent.systemImage
        case .showFiles: MainTab.files.systemImage
        case .showChanges: MainTab.changes.systemImage
        case .openTerminal: MainTab.terminal.systemImage
        case .toggleSidebar: "sidebar.left"
        case .toggleInspector: "sidebar.right"
        case .openSettings: "gearshape"
        }
    }

    var shortcut: CommandShortcut? {
        switch self {
        case .openProject: CommandShortcut("o")
        case .newSession: CommandShortcut("n")
        case .searchFiles: CommandShortcut("p")
        case .changeModel: CommandShortcut("l")
        case .showAgent: CommandShortcut("1")
        case .showFiles: CommandShortcut("2")
        case .showChanges: CommandShortcut("3")
        case .openTerminal: CommandShortcut("4")
        case .toggleSidebar: CommandShortcut("s", modifiers: [.control, .command])
        case .toggleInspector: CommandShortcut("i", modifiers: [.option, .command])
        case .openSettings: CommandShortcut(",")
        }
    }

    var section: String {
        switch self {
        case .openProject, .newSession, .searchFiles: "Project"
        case .changeModel: "Agent"
        case .showAgent, .showFiles, .showChanges, .openTerminal: "Navigation"
        case .toggleSidebar, .toggleInspector, .openSettings: "Window"
        }
    }

    var keywords: [String] {
        switch self {
        case .openProject: ["folder", "workspace"]
        case .newSession: ["chat", "conversation", "create"]
        case .searchFiles: ["find", "file", "go to"]
        case .changeModel: ["llm", "provider", "ollama", "lm studio"]
        case .showAgent: ["chat", "conversation"]
        case .showFiles: ["browse", "tree"]
        case .showChanges: ["diff", "review", "edits"]
        case .openTerminal: ["shell", "command", "run"]
        case .toggleSidebar, .toggleInspector: ["panel", "hide", "show"]
        case .openSettings: ["preferences", "configuration"]
        }
    }

    /// The tab a navigation command shows, if any.
    var tab: MainTab? {
        switch self {
        case .showAgent: .agent
        case .showFiles: .files
        case .showChanges: .changes
        case .openTerminal: .terminal
        default: nil
        }
    }
}

/// A keyboard shortcut described without SwiftUI types, so models and view
/// models can expose it and tests can check it. Converted to SwiftUI's
/// `KeyboardShortcut` in the view layer.
struct CommandShortcut: Hashable, Sendable {
    /// Ordered as macOS displays modifiers: ⌃ ⌥ ⇧ ⌘.
    enum Modifier: Int, Hashable, Sendable, Comparable {
        case control
        case option
        case shift
        case command

        var symbol: String {
            switch self {
            case .control: "⌃"
            case .option: "⌥"
            case .shift: "⇧"
            case .command: "⌘"
            }
        }

        static func < (lhs: Modifier, rhs: Modifier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let key: Character
    let modifiers: Set<Modifier>

    init(_ key: Character, modifiers: Set<Modifier> = [.command]) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Display form, e.g. “⌃⌘S”.
    var displayString: String {
        modifiers.sorted().map(\.symbol).joined() + String(key).uppercased()
    }
}
