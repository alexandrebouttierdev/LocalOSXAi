import Foundation

/// Failures raised by `LLMProvider` implementations.
///
/// Cases describe what went wrong from the application's point of view, not
/// the transport details, so the agent can decide how to recover (retry,
/// surface to the user, stop the run) without knowing the provider.
enum ProviderError: Error, Hashable, Sendable {
    /// The server could not be reached (not running, wrong URL, refused).
    case unreachable(endpoint: String)
    /// The server answered with a non-success HTTP status.
    case httpStatus(code: Int, message: String?)
    /// The payload did not match the expected format.
    case invalidResponse(String)
    /// The requested model is not installed or not loaded.
    case modelNotFound(String)
    /// The request needs a capability the model does not have (e.g. tools).
    case unsupportedCapability(String)
    /// No data was received within the configured timeout.
    case timedOut
}

extension ProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unreachable(let endpoint): "Could not reach the model server at \(endpoint)."
        case .httpStatus(let code, let message): "The model server returned HTTP \(code)\(message.map { ": \($0)" } ?? ".")"
        case .invalidResponse: "The model server returned an unexpected response."
        case .modelNotFound(let name): "The model “\(name)” is not available."
        case .unsupportedCapability(let capability): "The selected model does not support \(capability)."
        case .timedOut: "The model server did not respond in time."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unreachable: "Check that the model server is running and that its URL in Settings is correct."
        case .modelNotFound: "Refresh the model list or pull the model in your provider."
        case .unsupportedCapability: "Choose a model that supports this capability."
        case .timedOut: "The model may still be loading. Try again, or increase the timeout in Settings."
        case .httpStatus, .invalidResponse: nil
        }
    }
}
