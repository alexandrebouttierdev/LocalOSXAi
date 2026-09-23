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
}
