import Foundation

/// Failures of an agent run that are not provider or tool failures.
enum AgentError: Error, Hashable, Sendable {
    case noModelSelected
    /// The selected model is no longer offered by any configured provider.
    case modelUnavailable(name: String)
    /// Even the minimal prompt (instructions and the new message) exceeds the budget.
    case contextOverflow(usedTokens: Int, budgetTokens: Int)
    /// The model kept producing tool calls that could not be executed.
    case tooManyInvalidToolCalls(count: Int)
    /// The model stopped without any answer or tool call.
    case emptyResponse
    /// The model hit its output or context limit before producing anything usable.
    case outputLimitReached
    /// The model hit its limit while writing a tool call. The call was not
    /// run: its arguments are cut (a `write_file` would write half a file).
    case toolCallCutOff(contextTokens: Int)
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
        case .tooManyInvalidToolCalls(let count):
            "The model produced \(count) rounds of invalid tool calls in a row, so the run was stopped."
        case .emptyResponse:
            "The model finished without answering."
        case .outputLimitReached:
            "The model reached its length limit before answering (it may have spent it reasoning)."
        case .toolCallCutOff(let tokens):
            "The model ran out of room while writing a tool call, so the call was not run "
                + "(context: \(TokenCountFormatter.string(for: tokens)) tokens)."
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
        case .tooManyInvalidToolCalls:
            "Try again, rephrase the request, or choose a model with better tool support. If the context "
                + "meter is full, give the model a larger context."
        case .emptyResponse:
            "Try again, or rephrase the request."
        case .outputLimitReached:
            "Split the task into smaller steps, or load the model with a larger context in its server."
        case .toolCallCutOff:
            "Give the model a larger context (inspector › Model Settings for Ollama, or when loading it in "
                + "LM Studio), then retry. Asking for smaller steps, such as one section of a file at a time, also helps."
        }
    }
}
