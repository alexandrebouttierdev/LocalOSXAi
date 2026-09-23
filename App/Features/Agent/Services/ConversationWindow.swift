import Foundation

/// Fits a conversation into a token budget by dropping the oldest history.
///
/// A deliberately simple precursor of the Phase 3 `ContextManager`
/// (docs/ai/context.md): the system prompt and the new message are always
/// kept; older turns are dropped first; nothing is summarized yet.
enum ConversationWindow {
    struct Result: Equatable {
        let messages: [LLMMessage]
        let estimatedTokens: Int
        let droppedMessages: Int
    }

    /// Share of the context reserved for the model's answer.
    static let outputReserveRatio = 0.25
    static let minimumOutputReserve = 1_024

    /// Tokens available for the prompt within a context window.
    static func promptBudget(contextTokens: Int) -> Int {
        let reserve = max(Int(Double(contextTokens) * outputReserveRatio), minimumOutputReserve)
        return max(contextTokens - reserve, 0)
    }

    /// - Throws: `AgentError.contextOverflow` when the system prompt and the
    ///   prompt alone exceed `budget`.
    static func fit(system: String, history: [LLMMessage], prompt: String, budget: Int) throws -> Result {
        let fixed = [LLMMessage.system(system), LLMMessage.user(prompt)]
        let fixedTokens = estimate(fixed)
        guard fixedTokens <= budget else {
            throw AgentError.contextOverflow(usedTokens: fixedTokens, budgetTokens: budget)
        }

        var kept = history
        var total = fixedTokens + estimate(kept)
        var dropped = 0
        while total > budget, !kept.isEmpty {
            total -= estimate([kept.removeFirst()])
            dropped += 1
        }
        // Never start the kept history with an assistant turn whose question was dropped.
        while kept.first?.role == .assistant {
            total -= estimate([kept.removeFirst()])
            dropped += 1
        }
        return Result(messages: [fixed[0]] + kept + [fixed[1]], estimatedTokens: total, droppedMessages: dropped)
    }

    static func estimate(_ messages: [LLMMessage]) -> Int {
        TokenEstimator.estimate(messages: messages.map(\.content))
    }
}
