import Foundation

/// How much of the effective context window the next request will consume.
///
/// Displayed as “38.4K / 100K context”. Values are estimates unless the
/// provider reported exact usage; see docs/ai/context.md.
struct ContextUsage: Hashable, Sendable {
    var usedTokens: Int
    var budgetTokens: Int

    /// Fraction of the budget in use, clamped to 0...1 for display.
    var fraction: Double {
        guard budgetTokens > 0 else { return 1 }
        return min(max(Double(usedTokens) / Double(budgetTokens), 0), 1)
    }

    var isOverBudget: Bool { usedTokens > budgetTokens }
}

/// Estimates token counts without a model-specific tokenizer.
///
/// Local models use many different tokenizers and providers rarely expose
/// them, so an exact count is not available before sending a request. The
/// heuristic (≈ 4 characters per token for English prose and code) is
/// intentionally a slight *over*-estimate so budgets err on the safe side.
/// Exact provider usage, when reported, replaces the estimate.
enum TokenEstimator {
    static let charactersPerToken = 4
    /// Fixed cost per message for role markers and template tokens.
    static let perMessageOverhead = 4

    static func estimate(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let characters = text.unicodeScalars.count
        return (characters + charactersPerToken - 1) / charactersPerToken
    }

    static func estimate(messages: [String]) -> Int {
        messages.reduce(0) { $0 + estimate($1) + perMessageOverhead }
    }
}
