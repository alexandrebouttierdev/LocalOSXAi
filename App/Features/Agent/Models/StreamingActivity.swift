import Foundation

/// What a streaming assistant message is waiting on, when nothing visible is
/// being written: shown as a prominent loader so a slow local model never
/// looks frozen.
///
/// `nil` while the answer text streams, a tool call is being written or a
/// tool is running: those have their own live content.
enum StreamingActivity: Hashable, Sendable {
    /// Nothing arrived yet: the model may be loading or reading the prompt.
    case waitingForModel
    /// The model is reasoning (its thoughts stream into the reasoning view).
    case thinking
    /// Tools finished; the model is deciding what to do next.
    case nextStep

    /// Seconds without output after which waiting mentions model loading.
    static let slowStartSeconds: TimeInterval = 5

    init?(_ message: AgentMessage) {
        guard message.role == .assistant, message.state == .streaming, message.text.isEmpty,
              message.preparingToolCall == nil, message.toolCalls.allSatisfy(\.status.isFinished) else { return nil }
        if !message.reasoning.isEmpty {
            self = .thinking
        } else {
            self = message.toolCalls.isEmpty ? .waitingForModel : .nextStep
        }
    }

    var title: String {
        switch self {
        case .waitingForModel: "Waiting for the model"
        case .thinking: "Thinking"
        case .nextStep: "Working on the next step"
        }
    }

    /// A second line explaining a long wait, or `nil`.
    func hint(after seconds: TimeInterval) -> String? {
        guard self == .waitingForModel, seconds >= Self.slowStartSeconds else { return nil }
        return "The model may be loading. Large models can take a minute."
    }
}
