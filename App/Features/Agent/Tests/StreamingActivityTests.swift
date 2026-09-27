import Foundation
import Testing
@testable import LocalOSXAi

@Suite("StreamingActivity")
struct StreamingActivityTests {
    private func streaming(_ update: (inout AgentMessage) -> Void = { _ in }) -> AgentMessage {
        var message = AgentMessage(role: .assistant, text: "", state: .streaming, createdAt: Date())
        update(&message)
        return message
    }

    @Test("an empty streaming message waits for the model, then mentions loading")
    func waiting() {
        let activity = StreamingActivity(streaming())
        #expect(activity == .waitingForModel)
        #expect(activity?.hint(after: 2) == nil)
        #expect(activity?.hint(after: 6) != nil)
    }

    @Test("streamed reasoning without an answer is thinking")
    func thinking() {
        let activity = StreamingActivity(streaming { $0.reasoning = "Let me look" })
        #expect(activity == .thinking)
        #expect(activity?.hint(after: 60) == nil)
    }

    @Test("after finished tool calls the model is working on the next step")
    func nextStep() {
        let done = ToolCallRecord(id: "1", name: "read_file", argumentsJSON: "{}", status: .succeeded)
        #expect(StreamingActivity(streaming { $0.toolCalls = [done] }) == .nextStep)
    }

    @Test("nothing is shown while text streams, a tool is written or runs, or the message ended")
    func noActivity() {
        let running = ToolCallRecord(id: "1", name: "run_command", argumentsJSON: "{}", status: .running)
        #expect(StreamingActivity(streaming { $0.text = "Hi" }) == nil)
        #expect(StreamingActivity(streaming { $0.preparingToolCall = ToolCallDraft(name: "write_file", path: nil, characters: 10) }) == nil)
        #expect(StreamingActivity(streaming { $0.toolCalls = [running] }) == nil)
        #expect(StreamingActivity(AgentMessage(role: .assistant, text: "", state: .complete, createdAt: Date())) == nil)
        #expect(StreamingActivity(AgentMessage(role: .user, text: "", state: .streaming, createdAt: Date())) == nil)
    }
}
