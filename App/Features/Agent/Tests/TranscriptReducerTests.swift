import Foundation
import Testing
@testable import LocalOSXAi

@Suite("TranscriptReducer")
struct TranscriptReducerTests {
    private let now = Date(timeIntervalSinceReferenceDate: 0)
    private let running = ToolCallRecord(id: "t1", name: "read_file", argumentsJSON: "{}", status: .running)

    private func reduce(_ events: [AgentEvent], into messages: [AgentMessage] = []) -> [AgentMessage] {
        var messages = messages
        events.forEach { TranscriptReducer.apply($0, to: &messages, now: now) }
        return messages
    }

    @Test("deltas accumulate into the streaming assistant message")
    func accumulatesDeltas() {
        let messages = reduce([
            .assistantMessageStarted(id: UUID()), .reasoningDelta("Let me "), .reasoningDelta("think"),
            .textDelta("Hello"), .textDelta(" world")
        ])
        #expect(messages.count == 1)
        #expect(messages[0].text == "Hello world")
        #expect(messages[0].reasoning == "Let me think")
        #expect(messages[0].state == .streaming)
    }

    @Test("finishing marks the message complete")
    func finishing() {
        let messages = reduce([.assistantMessageStarted(id: UUID()), .textDelta("Done"), .finished(.completed)])
        #expect(messages[0].state == .complete)
    }

    @Test("tool calls attach to the current message and are updated by id")
    func toolCalls() {
        let messages = reduce([
            .assistantMessageStarted(id: UUID()),
            .toolCallStarted(running),
            .toolCallFinished(id: "t1", status: .succeeded, summary: "Read 3 lines", output: "a\nb\nc")
        ])
        let call = messages[0].toolCalls[0]
        #expect(call.status == .succeeded)
        #expect(call.summary == "Read 3 lines")
        #expect(call.output == "a\nb\nc")
    }

    @Test("a tool call being prepared shows until it starts, and never outlives the message")
    func preparingToolCall() {
        let draft = ToolCallDraft(name: "write_file", path: "index.html", characters: 1_024)
        var messages = reduce([.assistantMessageStarted(id: UUID()), .toolCallPreparing(draft)])
        #expect(messages[0].preparingToolCall == draft)

        TranscriptReducer.apply(.toolCallStarted(running), to: &messages, now: now)
        #expect(messages[0].preparingToolCall == nil)

        messages = reduce([.assistantMessageStarted(id: UUID()), .toolCallPreparing(draft)])
        TranscriptReducer.cancel(&messages)
        #expect(messages[0].preparingToolCall == nil)
    }

    @Test("server token counts and finish times are recorded on the message")
    func timingAndUsage() {
        let later = now.addingTimeInterval(4)
        var messages = reduce([.assistantMessageStarted(id: UUID()), .textDelta("Hi"),
                               .usage(TokenUsage(promptTokens: 900, completionTokens: 12))])
        #expect(messages[0].outputTokens == 12)
        #expect(messages[0].finishedAt == nil)

        TranscriptReducer.apply(.finished(.completed), to: &messages, now: later)
        #expect(messages[0].finishedAt == later)

        var stopped = reduce([.assistantMessageStarted(id: UUID())])
        TranscriptReducer.cancel(&stopped, now: later)
        #expect(stopped[0].finishedAt == later)
    }

    @Test("a finish event for an unknown tool call is ignored")
    func unknownToolCallFinish() {
        let messages = reduce([
            .assistantMessageStarted(id: UUID()),
            .toolCallFinished(id: "missing", status: .failed, summary: "", output: "")
        ])
        #expect(messages[0].toolCalls.isEmpty)
    }

    @Test("a new assistant message completes the previous one")
    func newMessageCompletesPrevious() {
        let messages = reduce([.assistantMessageStarted(id: UUID()), .textDelta("A"), .assistantMessageStarted(id: UUID())])
        #expect(messages.map(\.state) == [.complete, .streaming])
    }

    @Test("deltas without a started message create one")
    func implicitMessage() {
        let messages = reduce([.textDelta("Hi")])
        #expect(messages.count == 1)
        #expect(messages[0].role == .assistant)
    }

    @Test("cancellation marks in-flight messages and tool calls as cancelled")
    func cancellation() {
        var messages = reduce([.assistantMessageStarted(id: UUID()), .toolCallStarted(running)])
        TranscriptReducer.cancel(&messages)
        #expect(messages[0].state == .cancelled)
        #expect(messages[0].toolCalls[0].status == .cancelled)
    }

    @Test("failure marks in-flight content failed and appends an error entry")
    func failure() {
        var messages = reduce([.assistantMessageStarted(id: UUID()), .toolCallStarted(running)])
        TranscriptReducer.fail(&messages, error: UserFacingError(title: "Failed", message: "Model crashed"), now: now)
        #expect(messages[0].state == .failed)
        #expect(messages[0].toolCalls[0].status == .cancelled)
        #expect(messages.last?.role == .error)
        #expect(messages.last?.text == "Model crashed")
    }

    @Test("a completed run marks unfinished tool calls as failed")
    func completedRunWithUnfinishedTool() {
        let messages = reduce([.assistantMessageStarted(id: UUID()), .toolCallStarted(running), .finished(.completed)])
        #expect(messages[0].toolCalls[0].status == .failed)
    }

    @Test("context usage events do not change the transcript")
    func contextUsageIgnored() {
        let messages = reduce([.contextUsageUpdated(ContextUsage(usedTokens: 1, budgetTokens: 2))])
        #expect(messages.isEmpty)
    }
}
