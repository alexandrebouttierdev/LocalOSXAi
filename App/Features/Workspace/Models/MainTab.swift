import Foundation

/// The main content areas of a project window.
enum MainTab: String, CaseIterable, Identifiable, Sendable {
    case agent
    case files
    case changes
    case terminal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agent: "Agent"
        case .files: "Files"
        case .changes: "Changes"
        case .terminal: "Terminal"
        }
    }

    var systemImage: String {
        switch self {
        case .agent: "sparkles"
        case .files: "doc.text"
        case .changes: "plusminus"
        case .terminal: "terminal"
        }
    }

    /// Roadmap phase that delivers the tab, for tabs not implemented yet.
    /// Displayed in placeholders so unfinished areas are explicit, never silent.
    var plannedPhase: Int? {
        switch self {
        case .agent: nil
        case .files, .changes, .terminal: 4
        }
    }

    var placeholderMessage: String {
        switch self {
        case .agent: ""
        case .files: "Browse and preview project files. The agent can already read and search them."
        case .changes: "Review, accept or reject the agent's edits as diffs before they are applied."
        case .terminal: "Run commands with streamed output, subject to the command permission policy."
        }
    }
}
