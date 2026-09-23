import Foundation

/// Applies agent events to a transcript.
///
/// Extracted from `AgentViewModel` so the event-to-transcript rules are pure,
/// synchronous and exhaustively testable without concurrency.
///
/// Invariant: at most one assistant message is `.streaming` at a time, and it
/// is the last assistant message of the transcript.
enum TranscriptReducer {
    static func apply(_ event: AgentEvent, to messages: inout [AgentMessage], now: Date) {
        switch event {
        case .assistantMessageStarted(let id):
            finishStreaming(&messages, as: .complete)
            messages.append(AgentMessage(id: id, role: .assistant, text: "", state: .streaming, createdAt: now))
        case .textDelta(let delta):
            updateStreaming(&messages, now: now) { $0.text += delta }
        case .reasoningDelta(let delta):
            updateStreaming(&messages, now: now) { $0.reasoning += delta }
        case .toolCallStarted(let record):
            updateStreaming(&messages, now: now) { $0.toolCalls.append(record) }
        case let .toolCallFinished(id, status, summary, output):
            updateToolCall(id: id, in: &messages) { record in
                record.status = status
                record.summary = summary
                record.output = output
            }
        case .contextUsageUpdated:
            break
        case .finished:
            finishStreaming(&messages, as: .complete)
        }
    }

    /// Marks in-flight content as cancelled after the user stopped the run.
    static func cancel(_ messages: inout [AgentMessage]) {
        finishStreaming(&messages, as: .cancelled)
    }

    /// Marks in-flight content as failed and appends a visible error entry.
    static func fail(_ messages: inout [AgentMessage], error: UserFacingError, now: Date) {
        finishStreaming(&messages, as: .failed)
        messages.append(AgentMessage(role: .error, text: error.message, state: .complete, createdAt: now))
    }

    // MARK: Helpers

    private static func updateStreaming(_ messages: inout [AgentMessage], now: Date,
                                        _ update: (inout AgentMessage) -> Void) {
        if let index = messages.lastIndex(where: { $0.state == .streaming }) {
            update(&messages[index])
        } else {
            // Tolerate services that omit `assistantMessageStarted`.
            var message = AgentMessage(role: .assistant, text: "", state: .streaming, createdAt: now)
            update(&message)
            messages.append(message)
        }
    }

    private static func updateToolCall(id: String, in messages: inout [AgentMessage],
                                       _ update: (inout ToolCallRecord) -> Void) {
        for messageIndex in messages.indices.reversed() {
            if let callIndex = messages[messageIndex].toolCalls.firstIndex(where: { $0.id == id }) {
                update(&messages[messageIndex].toolCalls[callIndex])
                return
            }
        }
    }

    private static func finishStreaming(_ messages: inout [AgentMessage], as state: AgentMessage.State) {
        for index in messages.indices where messages[index].state == .streaming {
            messages[index].state = state
            for callIndex in messages[index].toolCalls.indices where !messages[index].toolCalls[callIndex].status.isFinished {
                messages[index].toolCalls[callIndex].status = state == .complete ? .failed : .cancelled
            }
        }
    }
}
