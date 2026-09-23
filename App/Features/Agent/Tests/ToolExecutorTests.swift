import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ToolExecutor", .timeLimit(.minutes(1)))
struct ToolExecutorTests {
    private let context = ToolContext(projectRoot: URL(fileURLWithPath: "/tmp"))

    private func executor(_ tools: [any AgentTool], timeout: Duration = .seconds(5), maxOutput: Int = 16_000) throws -> ToolExecutor {
        ToolExecutor(registry: try ToolRegistry(tools), timeout: timeout, maxOutputCharacters: maxOutput)
    }

    private func execute(_ executor: ToolExecutor, _ call: LLMToolCall, approver: StubApprover = StubApprover(),
                         statuses: Recorder<ToolCallRecord.Status> = Recorder()) async -> ToolExecutor.Outcome {
        await executor.execute(call, context: context, approver: approver) { statuses.record($0) }
    }

    @Test("an allowed read runs without asking")
    func allowedRead() async throws {
        let approver = StubApprover()
        let statuses = Recorder<ToolCallRecord.Status>()
        let outcome = await execute(try executor([EchoTool()]), Fixtures.call("echo", #"{"text":"hi"}"#),
                                    approver: approver, statuses: statuses)

        #expect(outcome == .init(status: .succeeded, summary: "Echoed 2 characters", output: "hi", isInvalidCall: false))
        #expect(approver.requests.isEmpty)
        #expect(statuses.values == [.running])
    }

    @Test("an unknown tool is an invalid call that lists the available tools")
    func unknownTool() async throws {
        let outcome = await execute(try executor([EchoTool()]), Fixtures.call("rm_rf"))
        #expect(outcome.status == .failed)
        #expect(outcome.isInvalidCall)
        #expect(outcome.output.contains("Available tools: echo"))
    }

    @Test(
        "malformed and invalid arguments are invalid calls returned to the model",
        arguments: ["{text:", #"{}"#, #"{"text":1}"#, #"{"text":"a","x":1}"#]
    )
    func invalidArguments(raw: String) async throws {
        let outcome = await execute(try executor([EchoTool()]), Fixtures.call("echo", raw))
        #expect(outcome.status == .failed)
        #expect(outcome.isInvalidCall)
        #expect(outcome.output.hasPrefix("Error:"))
    }

    @Test("a write asks for approval, then runs when allowed")
    func approvedWrite() async throws {
        let tool = RecordingWriteTool()
        let approver = StubApprover(.allowOnce)
        let statuses = Recorder<ToolCallRecord.Status>()
        let outcome = await execute(try executor([tool]), Fixtures.call("write_note", #"{"text":"x"}"#, id: "c1"),
                                    approver: approver, statuses: statuses)

        #expect(outcome.status == .succeeded)
        #expect(tool.calls.values == ["x"])
        #expect(statuses.values == [.awaitingApproval, .running])
        #expect(approver.requests.first?.id == "c1")
        #expect(approver.requests.first?.reason == "This changes files in your project.")
    }

    @Test("a denied write never runs and tells the model not to retry")
    func deniedWrite() async throws {
        let tool = RecordingWriteTool()
        let outcome = await execute(try executor([tool]), Fixtures.call("write_note", #"{"text":"x"}"#), approver: StubApprover(.deny))

        #expect(outcome.status == .denied)
        #expect(outcome.output.contains("Do not retry"))
        #expect(tool.calls.values.isEmpty)
    }

    @Test("a tool failure is reported to the model")
    func toolFailure() async throws {
        let outcome = await execute(try executor([FailingTool()]), Fixtures.call("fail"))
        #expect(outcome == .init(status: .failed, summary: "Tool failed: disk on fire",
                                 output: "Error: Tool failed: disk on fire", isInvalidCall: false))
    }

    @Test("a tool exceeding the timeout fails")
    func timeout() async throws {
        let outcome = await execute(try executor([SlowTool()], timeout: .milliseconds(50)), Fixtures.call("slow"))
        #expect(outcome.status == .failed)
        #expect(outcome.summary.contains("did not finish"))
    }

    @Test("large outputs are limited")
    func outputLimit() async throws {
        let long = String(repeating: "x", count: 500)
        let outcome = await execute(try executor([EchoTool()], maxOutput: 100), Fixtures.call("echo", #"{"text":"\#(long)"}"#))
        #expect(outcome.output.count < 200)
    }

    @Test("cancellation during a tool yields a cancelled outcome")
    func cancellation() async throws {
        let executor = try executor([SlowTool()])
        let task = Task { await execute(executor, Fixtures.call("slow")) }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        #expect(await task.value.status == .cancelled)
    }
}
