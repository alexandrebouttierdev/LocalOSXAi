import Foundation

/// Applies agent events to a transcript.
///
/// Extracted from `AgentViewModel` so the event-to-transcript rules are pure,
/// synchronous and exhaustively testable without concurrency.
///
/// Invariant: at most one assistant message is `.streaming` at a time, and it
/// is the last assistant message of the transcript. A summary is `.streaming`
/// only while the model writes it, and is removed if it never completes.
enum TranscriptReducer {
    static func apply(_ event: AgentEvent, to messages: inout [AgentMessage], now: Date) {
        switch event {
        case .assistantMessageStarted(let id):
            finishStreaming(&messages, as: .complete, now: now)
            messages.append(AgentMessage(id: id, role: .assistant, text: "", state: .streaming, createdAt: now))
        case .textDelta(let delta):
            updateStreaming(&messages, now: now) { $0.text += delta }
        case .reasoningDelta(let delta):
            updateStreaming(&messages, now: now) { $0.reasoning += delta }
        case .toolCallPreparing(let draft):
            updateStreaming(&messages, now: now) { $0.preparingToolCall = draft }
        case .toolCallStarted(let record):
            updateStreaming(&messages, now: now) { message in
                message.preparingToolCall = nil
                message.toolCalls.append(record)
            }
        case .toolCallStatusChanged, .toolCallFinished:
            applyToolCallUpdate(event, to: &messages)
        case .usage(let usage):
            updateStreaming(&messages, now: now) { $0.outputTokens = usage.completionTokens }
        case .historySummaryStarted, .historySummaryFinished, .historySummaryDiscarded:
            applySummary(event, to: &messages, now: now)
        case .contextUsageUpdated, .instructionsLoaded:
            break
        case .finished:
            finishStreaming(&messages, as: .complete, now: now)
        }
    }

    /// Marks in-flight content as cancelled after the user stopped the run.
    static func cancel(_ messages: inout [AgentMessage], now: Date = Date()) {
        finishStreaming(&messages, as: .cancelled, now: now)
    }

    /// Marks in-flight content as failed and appends a visible error entry.
    static func fail(_ messages: inout [AgentMessage], error: UserFacingError, now: Date) {
        finishStreaming(&messages, as: .failed, now: now)
        // The suggestion says what to do next (start the server, pick another model…).
        let text = [error.message, error.recoverySuggestion].compactMap { $0 }.joined(separator: "\n")
        messages.append(AgentMessage(role: .error, text: text, state: .complete, createdAt: now))
    }

    // MARK: Helpers

    private static func applyToolCallUpdate(_ event: AgentEvent, to messages: inout [AgentMessage]) {
        switch event {
        case let .toolCallStatusChanged(id, status):
            updateToolCall(id: id, in: &messages) { $0.status = status }
        case let .toolCallFinished(id, status, summary, output):
            updateToolCall(id: id, in: &messages) { record in
                record.status = status
                record.summary = summary
                record.output = output
            }
        default:
            break
        }
    }

    private static func applySummary(_ event: AgentEvent, to messages: inout [AgentMessage], now: Date) {
        switch event {
        case let .historySummaryStarted(id, afterMessageID):
            // Placed right after the last message it covers: everything above
            // it is what the model no longer sees verbatim.
            guard let index = messages.firstIndex(where: { $0.id == afterMessageID }) else { return }
            messages.insert(AgentMessage(id: id, role: .summary, text: "", state: .streaming, createdAt: now), at: index + 1)
        case let .historySummaryFinished(id, text):
            guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
            messages[index].text = text
            messages[index].state = .complete
            messages[index].finishedAt = now
        case .historySummaryDiscarded(let id):
            messages.removeAll { $0.id == id }
        default:
            break
        }
    }

    private static func updateStreaming(_ messages: inout [AgentMessage], now: Date,
                                        _ update: (inout AgentMessage) -> Void) {
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.state == .streaming }) {
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

    private static func finishStreaming(_ messages: inout [AgentMessage], as state: AgentMessage.State, now: Date) {
        // An unfinished summary has no content worth keeping.
        messages.removeAll { $0.role == .summary && $0.state == .streaming }
        for index in messages.indices where messages[index].state == .streaming {
            messages[index].state = state
            messages[index].finishedAt = now
            messages[index].preparingToolCall = nil
            for callIndex in messages[index].toolCalls.indices where !messages[index].toolCalls[callIndex].status.isFinished {
                messages[index].toolCalls[callIndex].status = state == .complete ? .failed : .cancelled
            }
        }
    }
}
