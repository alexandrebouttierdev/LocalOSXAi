import Foundation
import Testing
@testable import LocalOSXAi

@Suite("TurnStats")
struct TurnStatsTests {
    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSinceReferenceDate: seconds) }

    private func assistant(_ text: String, at start: TimeInterval, end: TimeInterval?, tokens: Int?,
                           state: AgentMessage.State = .complete) -> AgentMessage {
        var message = AgentMessage(role: .assistant, text: text, state: state, createdAt: date(start))
        message.finishedAt = end.map(date)
        message.outputTokens = tokens
        return message
    }

    @Test("a turn runs from the user's message to its last answer, and sums the server's counts")
    func completedTurn() throws {
        let messages = [
            AgentMessage(role: .user, text: "Go", createdAt: date(0)),
            assistant("", at: 2, end: 5, tokens: 40),
            assistant("Done", at: 5, end: 12.4, tokens: 60),
            AgentMessage(role: .user, text: "Again", createdAt: date(20)),
            assistant("Sure", at: 21, end: 22, tokens: 5)
        ]
        let turns = TurnStats.turns(in: messages)

        #expect(Set(turns.keys) == [2, 4])
        let first = try #require(turns[2])
        #expect(first.duration(now: date(100)) == 12.4)
        #expect(first.outputTokens == 100)
        #expect(!first.isEstimated)
        #expect(first.summary(now: date(100)) == "12.4 s · 100 tokens")
        #expect(turns[4]?.outputTokens == 5)
    }

    @Test("a streaming turn has no end and grows with the clock; unknown counts are estimated")
    func streamingTurn() throws {
        let messages = [
            AgentMessage(role: .user, text: "Go", createdAt: date(0)),
            assistant(String(repeating: "a", count: 400), at: 1, end: nil, tokens: nil, state: .streaming)
        ]
        let stats = try #require(TurnStats.turns(in: messages)[1])

        #expect(stats.end == nil)
        #expect(stats.isEstimated)
        #expect(stats.outputTokens == 100)
        #expect(stats.summary(now: date(7.9)) == "7 s · ~100 tokens")
        #expect(stats.summary(now: date(125)) == "2 min 05 s · ~100 tokens")
    }

    @Test("reasoning, tool arguments and a tool call being written count in the estimate")
    func estimate() {
        var message = AgentMessage(role: .assistant, text: "abcd", reasoning: "efgh",
                                   toolCalls: [ToolCallRecord(id: "1", name: "x", argumentsJSON: "{\"a\":1}", status: .running)],
                                   state: .streaming, createdAt: date(0))
        message.preparingToolCall = ToolCallDraft(name: "write_file", path: nil, characters: 400)
        #expect(TurnStats.estimatedTokens(of: message) == 1 + 1 + 2 + 100)
    }

    @Test("messages without a user message before them still form a turn")
    func turnWithoutPrompt() {
        let turns = TurnStats.turns(in: [assistant("Hi", at: 3, end: 4, tokens: 2)])
        #expect(turns[0]?.duration(now: date(9)) == 1)
    }
}
