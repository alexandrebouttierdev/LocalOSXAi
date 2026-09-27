import Foundation

/// A page of the settings screen, listed in its sidebar.
enum SettingsSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case providers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        }
    }

    /// One line under the page title.
    var subtitle: String {
        switch self {
        case .general: "Appearance and how the agent runs."
        case .providers: "The model servers the agent can use: Ollama, LM Studio and OpenAI-compatible servers."
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .providers: "cpu"
        }
    }
}
