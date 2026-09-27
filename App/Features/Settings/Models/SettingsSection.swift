import Foundation

/// A page of the settings screen, listed in its sidebar.
enum SettingsSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case systemPrompt
    case providers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .systemPrompt: "System Prompt"
        case .providers: "Providers"
        }
    }

    /// One line under the page title.
    var subtitle: String {
        switch self {
        case .general: "Appearance and how the agent runs."
        case .systemPrompt: "Your instructions for the agent, in every project, after its built-in prompt."
        case .providers: "The model servers the agent can use: Ollama, LM Studio and OpenAI-compatible servers."
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .systemPrompt: "text.quote"
        case .providers: "cpu"
        }
    }
}
