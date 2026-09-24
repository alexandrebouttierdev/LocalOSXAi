import Foundation

/// How long an agent turn took and how many tokens it produced, shown under
/// the turn's last message (live while it streams).
///
/// A turn is the consecutive assistant messages answering one user message
/// (one per model call). It starts when the user sent the message, so model
/// loading and tool time count: that is what the user waited.
struct TurnStats: Hashable, Sendable {
    let start: Date
    /// `nil` while the turn is still streaming.
    let end: Date?
    let outputTokens: Int
    /// True when at least one model call's count is estimated (the server did not say).
    let isEstimated: Bool

    func duration(now: Date) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }

    /// Stats of every turn, keyed by the index of the turn's last assistant message.
    static func turns(in messages: [AgentMessage]) -> [Int: TurnStats] {
        var result: [Int: TurnStats] = [:]
        var index = messages.startIndex
        while index < messages.endIndex {
            guard messages[index].role == .assistant else {
                index += 1
                continue
            }
            let first = index
            while index + 1 < messages.endIndex, messages[index + 1].role == .assistant { index += 1 }
            let turn = messages[first...index]
            let previous = first > messages.startIndex ? messages[first - 1] : nil
            let start = previous?.role == .user ? previous?.createdAt ?? turn.first?.createdAt : turn.first?.createdAt
            let isStreaming = turn.contains { $0.state == .streaming }
            result[index] = TurnStats(
                start: start ?? messages[first].createdAt,
                end: isStreaming ? nil : turn.compactMap(\.finishedAt).max(),
                outputTokens: turn.reduce(0) { $0 + ($1.outputTokens ?? estimatedTokens(of: $1)) },
                isEstimated: turn.contains { $0.outputTokens == nil }
            )
            index += 1
        }
        return result
    }

    /// “12.4 s · 356 tokens”, with “~” before an estimated count. While
    /// streaming, whole seconds, so the label does not flicker.
    func summary(now: Date) -> String {
        "\(Self.duration(duration(now: now), precise: end != nil)) · \(tokenLabel)"
    }

    var accessibilityDescription: String {
        let seconds = Int((duration(now: end ?? start)).rounded())
        return "\(seconds) seconds, \(isEstimated ? "about " : "")\(outputTokens) output tokens"
    }

    private var tokenLabel: String {
        let count = TokenCountFormatter.string(for: outputTokens)
        return "\(isEstimated ? "~" : "")\(count) \(outputTokens == 1 ? "token" : "tokens")"
    }

    static func duration(_ seconds: TimeInterval, precise: Bool) -> String {
        if seconds < 60 {
            return precise ? String(format: "%.1f s", seconds) : "\(Int(seconds)) s"
        }
        let total = Int(seconds)
        return String(format: "%d min %02d s", total / 60, total % 60)
    }

    /// What the model wrote: answer, reasoning and tool call arguments.
    static func estimatedTokens(of message: AgentMessage) -> Int {
        let arguments = message.toolCalls.map(\.argumentsJSON).joined()
        let preparing = message.preparingToolCall?.characters ?? 0
        return TokenEstimator.estimate(message.text + message.reasoning + arguments) + preparing / TokenEstimator.charactersPerToken
    }
}
