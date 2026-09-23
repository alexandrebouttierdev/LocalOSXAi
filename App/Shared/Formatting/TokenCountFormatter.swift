import Foundation

/// Formats token counts compactly: `950`, `38.4K`, `100K`, `1.2M`.
///
/// Kept locale-independent on purpose: token counts are technical figures
/// shown next to model names, and the compact “K/M” notation is what
/// developers expect regardless of language.
enum TokenCountFormatter {
    static func string(for tokens: Int) -> String {
        let value = max(tokens, 0)
        switch value {
        case ..<1_000:
            return String(value)
        case ..<1_000_000:
            return compact(Double(value) / 1_000, suffix: "K")
        default:
            return compact(Double(value) / 1_000_000, suffix: "M")
        }
    }

    /// “38.4K / 100K context”
    static func contextSummary(_ usage: ContextUsage) -> String {
        "\(string(for: usage.usedTokens)) / \(string(for: usage.budgetTokens)) context"
    }

    /// Spoken form for VoiceOver: “38.4 thousand of 100 thousand context tokens used”.
    static func accessibilityDescription(_ usage: ContextUsage) -> String {
        "\(spoken(usage.usedTokens)) of \(spoken(usage.budgetTokens)) context tokens used"
    }

    private static func compact(_ value: Double, suffix: String) -> String {
        // One decimal below 100 (38.4K), none above (128K); trailing “.0” dropped.
        let rounded = value < 100 ? (value * 10).rounded() / 10 : value.rounded()
        if rounded == rounded.rounded(.towardZero) {
            return "\(Int(rounded))\(suffix)"
        }
        return String(format: "%.1f%@", rounded, suffix)
    }

    private static func spoken(_ tokens: Int) -> String {
        let formatted = string(for: tokens)
        return formatted
            .replacingOccurrences(of: "K", with: " thousand")
            .replacingOccurrences(of: "M", with: " million")
    }
}
