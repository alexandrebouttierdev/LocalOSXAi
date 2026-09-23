import Foundation
import Testing
@testable import LocalOSXAi

@Suite("TokenCountFormatter")
struct TokenCountFormatterTests {
    @Test(
        "formats counts compactly",
        arguments: [
            (0, "0"), (950, "950"), (999, "999"), (1_000, "1K"), (38_400, "38.4K"), (38_449, "38.4K"),
            (100_000, "100K"), (131_072, "131K"), (1_200_000, "1.2M"), (2_000_000, "2M"), (-5, "0")
        ]
    )
    func formats(tokens: Int, expected: String) {
        #expect(TokenCountFormatter.string(for: tokens) == expected)
    }

    @Test("context summary matches the documented format")
    func contextSummary() {
        let usage = ContextUsage(usedTokens: 38_400, budgetTokens: 100_000)
        #expect(TokenCountFormatter.contextSummary(usage) == "38.4K / 100K context")
    }

    @Test("accessibility description is spoken, not abbreviated")
    func accessibilityDescription() {
        let usage = ContextUsage(usedTokens: 38_400, budgetTokens: 100_000)
        #expect(TokenCountFormatter.accessibilityDescription(usage) == "38.4 thousand of 100 thousand context tokens used")
    }
}
