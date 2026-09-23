import Foundation

/// Failures of an agent run that are not provider or tool failures.
enum AgentError: Error, Hashable, Sendable {
    case noModelSelected
    /// The selected model is no longer offered by any configured provider.
    case modelUnavailable(name: String)
    /// Even the minimal prompt (instructions and the new message) exceeds the budget.
    case contextOverflow(usedTokens: Int, budgetTokens: Int)
}

extension AgentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noModelSelected:
            "No model is selected."
        case .modelUnavailable(let name):
            "The model “\(name)” is not available anymore."
        case let .contextOverflow(used, budget):
            "The message is too long for the model's context (\(TokenCountFormatter.string(for: used)) of "
                + "\(TokenCountFormatter.string(for: budget)) tokens)."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noModelSelected:
            "Choose a model in the inspector or with ⌘L. Start Ollama or LM Studio if no model is listed."
        case .modelUnavailable:
            "Check that its server is running, then refresh the model list."
        case .contextOverflow:
            "Shorten the message, or increase the context length in Settings."
        }
    }
}
