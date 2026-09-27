import Foundation
import Testing
@testable import LocalOSXAi

@Suite("HistoryCompaction")
struct HistoryCompactionTests {
    /// Alternating questions and answers of about 500 tokens each.
    static func history(_ count: Int) -> [LLMMessage] {
        (0..<count).map { $0.isMultiple(of: 2) ? .user("question \($0) " + String(repeating: "x", count: 2_000))
                                               : .assistant("answer \($0) " + String(repeating: "y", count: 2_000)) }
    }

    @Test("nothing is summarized while the run starts under half of the budget")
    func fits() {
        #expect(HistoryCompaction.messagesToSummarize(history: Self.history(4), fixedTokens: 100, currentSummaryTokens: 0,
                                                      promptBudget: 6_144) == 0)
    }

    @Test("the smallest cut that fits is chosen, before a question, keeping the last exchange")
    func smallestCut() {
        // Target 3,072 tokens: 100 fixed + 768 for the summary leaves room for four messages.
        let count = HistoryCompaction.messagesToSummarize(history: Self.history(10), fixedTokens: 100, currentSummaryTokens: 0,
                                                          promptBudget: 6_144)
        #expect(count == 6)
    }

    @Test("when no cut fits, as much as allowed is summarized")
    func largestCut() {
        let count = HistoryCompaction.messagesToSummarize(history: Self.history(10), fixedTokens: 2_900, currentSummaryTokens: 0,
                                                          promptBudget: 6_144)
        #expect(count == 8)
    }

    @Test("too short a history is never summarized, and an existing summary counts toward the size")
    func shortHistory() {
        #expect(HistoryCompaction.messagesToSummarize(history: Self.history(3), fixedTokens: 5_000, currentSummaryTokens: 0,
                                                      promptBudget: 6_144) == 0)
        #expect(HistoryCompaction.messagesToSummarize(history: Self.history(4), fixedTokens: 100, currentSummaryTokens: 2_500,
                                                      promptBudget: 6_144) == 2)
    }

    @Test("a summary gets an eighth of the budget, at most 1K tokens")
    func summaryTokens() {
        #expect(HistoryCompaction.summaryTokens(promptBudget: 6_144) == 768)
        #expect(HistoryCompaction.summaryTokens(promptBudget: 98_304) == 1_024)
    }
}

@Suite("AgentPrompt summaries")
struct AgentPromptSummaryTests {
    private let now = Date(timeIntervalSinceReferenceDate: 0)

    @Test("history starts after the latest complete summary")
    func historyAfterSummary() {
        var unfinished = AgentMessage(role: .summary, text: "", createdAt: now)
        unfinished.state = .streaming
        let messages = [
            AgentMessage(role: .user, text: "Q1", createdAt: now),
            AgentMessage(role: .summary, text: "Old", createdAt: now),
            AgentMessage(role: .user, text: "Q2", createdAt: now),
            AgentMessage(role: .summary, text: "Newer", createdAt: now),
            AgentMessage(role: .user, text: "Q3", createdAt: now),
            unfinished,
            AgentMessage(role: .assistant, text: "A3", createdAt: now)
        ]
        let history = AgentPrompt.history(from: messages)
        #expect(history.summary == "Newer")
        #expect(history.messages.map(\.content) == ["Q3", "A3"])
        #expect(history.entries.map(\.messageID) == [messages[4].id, messages[6].id])
    }

    @Test("the summary is appended to the system prompt, not sent as a message")
    func systemWithSummary() {
        #expect(AgentPrompt.system("S", summary: nil) == "S")
        #expect(AgentPrompt.system("S", summary: "Did X") == "S\n\n# Earlier conversation (summary)\n\nDid X")
    }

    @Test("the summary request folds in the previous summary and fits the input budget")
    func summaryRequest() {
        let messages = AgentPrompt.summaryRequest(previousSummary: "Earlier: set up the project.",
                                                  messages: HistoryCompactionTests.history(20), maxInputTokens: 1_000,
                                                  maxSummaryTokens: 400)
        #expect(messages.map(\.role) == [.system, .user])
        #expect(messages[0].content.contains("at most 300 words"))
        #expect(messages[1].content.contains("Summary of what came before:\nEarlier: set up the project."))
        #expect(messages[1].content.contains("middle of the conversation omitted"))
        #expect(messages[1].content.contains("User: question 0"))
        #expect(messages[1].content.hasSuffix(String(repeating: "y", count: 100)))
        #expect(TokenEstimator.estimate(messages: messages.map(\.content)) <= 1_100)
    }
}

/// Summaries in real runs, with a scripted provider.
@Suite("AgentRuntime history summaries", .timeLimit(.minutes(1)))
struct AgentRuntimeSummaryTests {
    /// Ten messages of about 500 tokens: more than half of the 6K budget the
    /// 8K fallback context of `Fixtures.toolModel` leaves for the prompt.
    private func longHistory() -> [AgentMessage] {
        HistoryCompactionTests.history(10).map { message in
            AgentMessage(role: message.role == .user ? .user : .assistant, text: message.content, createdAt: Date())
        }
    }

    private func runtime(_ provider: FakeLLMProvider, summarizes: Bool = true) throws -> AgentRuntime {
        var limits = AgentLimits()
        limits.summarizesHistory = summarizes
        return AgentRuntime(resolver: StubResolver(model: Fixtures.toolModel, provider: provider), tools: try ToolRegistry([EchoTool()]),
                            instructionsLoader: StubInstructionsLoader(instructions: []), limits: limits)
    }

    private func summaryEvents(_ events: [AgentEvent]) -> [AgentEvent] {
        events.filter {
            switch $0 {
            case .historySummaryStarted, .historySummaryFinished, .historySummaryDiscarded: true
            default: false
            }
        }
    }

    @Test("a run that starts too full summarizes the oldest messages first, then runs on the summary")
    func summarizes() async throws {
        let history = longHistory()
        let provider = FakeLLMProvider(turns: [.response("They discussed questions 0 to 4."), .response("Done.")])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(history: history), approver: StubApprover()))

        #expect(result.error == nil)
        let events = summaryEvents(result.elements)
        guard case let .historySummaryStarted(id, afterMessageID) = events.first else {
            Issue.record("No summary started")
            return
        }
        #expect(afterMessageID == history[5].id)
        #expect(events.last == .historySummaryFinished(id: id, text: "They discussed questions 0 to 4."))

        let summaryRequest = try #require(provider.requests.first)
        #expect(summaryRequest.tools.isEmpty)
        #expect(summaryRequest.messages.last?.content.contains("question 0") == true)

        let run = try #require(provider.requests.last)
        #expect(run.messages.first?.content.contains("# Earlier conversation (summary)\n\nThey discussed questions 0 to 4.") == true)
        #expect(run.messages.dropFirst().map(\.content).first?.hasPrefix("question 6") == true)
        #expect(run.messages.last?.content == "Do it")
    }

    @Test("a failed summary is discarded and the run continues by dropping old messages")
    func failedSummary() async throws {
        let provider = FakeLLMProvider(turns: [.failure(.timedOut), .response("Done.")])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(history: longHistory()), approver: StubApprover()))

        #expect(result.error == nil)
        let events = summaryEvents(result.elements)
        #expect(events.count == 2)
        if case let .historySummaryStarted(id, _) = events.first {
            #expect(events.last == .historySummaryDiscarded(id: id))
        }
        #expect(result.elements.contains(.finished(.completed)))
        #expect(provider.requests.last?.messages.first?.content.contains("Earlier conversation") == false)
    }

    @Test("with summaries turned off, the model is called once and nothing is summarized")
    func disabled() async throws {
        let provider = FakeLLMProvider(turns: [.response("Done.")])
        let result = await collect(try runtime(provider, summarizes: false)
            .run(Fixtures.runRequest(history: longHistory()), approver: StubApprover()))

        #expect(result.error == nil)
        #expect(summaryEvents(result.elements).isEmpty)
        #expect(provider.requests.count == 1)
    }

    @Test("an existing summary is reused without another model call")
    func reusesSummary() async throws {
        var history = longHistory()
        history.insert(AgentMessage(role: .summary, text: "Earlier work.", createdAt: Date()), at: 8)
        let provider = FakeLLMProvider(turns: [.response("Done.")])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(history: history), approver: StubApprover()))

        #expect(summaryEvents(result.elements).isEmpty)
        let run = try #require(provider.requests.first)
        #expect(provider.requests.count == 1)
        #expect(run.messages.first?.content.hasSuffix("# Earlier conversation (summary)\n\nEarlier work.") == true)
        #expect(run.messages.count == 4)
    }
}
