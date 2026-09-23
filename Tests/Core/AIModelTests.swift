import Foundation
import Testing
@testable import LocalOSXAi

@Suite("AIModel and ContextWindow")
struct AIModelTests {
    @Test("without configuration the conservative fallback is used, even if more is advertised")
    func fallbackIgnoresAdvertisedMaximum() {
        #expect(ContextWindow(advertisedTokens: 131_072).effectiveTokens == ContextWindow.fallbackTokens)
    }

    @Test("configured size is capped by the advertised maximum")
    func configuredIsCapped() {
        #expect(ContextWindow(advertisedTokens: 32_768, configuredTokens: 65_536).effectiveTokens == 32_768)
        #expect(ContextWindow(advertisedTokens: 32_768, configuredTokens: 16_384).effectiveTokens == 16_384)
    }

    @Test("configured size is used when nothing is advertised")
    func configuredWithoutAdvertised() {
        #expect(ContextWindow(configuredTokens: 20_000).effectiveTokens == 20_000)
    }

    @Test("a small advertised window lowers the fallback")
    func smallAdvertisedWindow() {
        #expect(ContextWindow(advertisedTokens: 4_096).effectiveTokens == 4_096)
    }

    @Test("the same model name on two providers has two identities")
    func identityIncludesProvider() {
        let ollama = Fixtures.model("qwen3:8b", provider: "ollama")
        let lmStudio = Fixtures.model("qwen3:8b", provider: "lmstudio")
        #expect(ollama.id != lmStudio.id)
    }

    @Test("capability flags reflect the option set")
    func capabilityFlags() {
        let model = Fixtures.model("m", capabilities: [.tools, .reasoning])
        #expect(model.supportsTools)
        #expect(model.supportsReasoning)
        #expect(!model.supportsVision)
        #expect(!model.supportsStreaming)
    }
}

@Suite("Context estimation")
struct ContextEstimationTests {
    @Test("token estimate rounds up at four characters per token")
    func estimate() {
        #expect(TokenEstimator.estimate("") == 0)
        #expect(TokenEstimator.estimate("abc") == 1)
        #expect(TokenEstimator.estimate("abcd") == 1)
        #expect(TokenEstimator.estimate("abcde") == 2)
    }

    @Test("message estimates include a per-message overhead")
    func messageOverhead() {
        #expect(TokenEstimator.estimate(messages: ["abcd", ""]) == 1 + 2 * TokenEstimator.perMessageOverhead)
    }

    @Test("usage fraction is clamped and over-budget is flagged")
    func usageFraction() {
        #expect(ContextUsage(usedTokens: 50, budgetTokens: 100).fraction == 0.5)
        let over = ContextUsage(usedTokens: 150, budgetTokens: 100)
        #expect(over.fraction == 1)
        #expect(over.isOverBudget)
        #expect(ContextUsage(usedTokens: 1, budgetTokens: 0).fraction == 1)
    }
}
