import Foundation
import Testing
@testable import LocalOSXAi

/// The agent loop, driven by scripted provider turns.
@Suite("AgentRuntime", .timeLimit(.minutes(1)))
struct AgentRuntimeTests {
    private func runtime(_ provider: FakeLLMProvider, tools: [any AgentTool] = [EchoTool()], model: AIModel = Fixtures.toolModel,
                         instructions: [ProjectInstruction] = [], limits: AgentLimits = AgentLimits()) throws -> AgentRuntime {
        AgentRuntime(resolver: StubResolver(model: model, provider: provider), tools: try ToolRegistry(tools),
                     instructionsLoader: StubInstructionsLoader(instructions: instructions), limits: limits)
    }

    private func finished(_ events: [AgentEvent]) -> [AgentEvent] {
        events.filter { if case .finished = $0 { true } else { false } }
    }

    private func toolResults(_ events: [AgentEvent]) -> [(ToolCallRecord.Status, String)] {
        events.compactMap { if case let .toolCallFinished(_, status, _, output) = $0 { (status, output) } else { nil } }
    }

    @Test("normal completion: a plain answer ends the run")
    func normalCompletion() async throws {
        let provider = FakeLLMProvider(turns: [.response("All good.")])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(), approver: StubApprover()))

        #expect(result.error == nil)
        #expect(result.elements.contains(.textDelta("All good.")))
        #expect(finished(result.elements) == [.finished(.completed)])
        #expect(provider.requests.first?.tools.map(\.name) == ["echo"])
    }

    @Test("a tool call is executed and its result sent back to the model")
    func singleToolCall() async throws {
        let provider = FakeLLMProvider(turns: [
            .toolCalls([Fixtures.call("echo", #"{"text":"hello"}"#, id: "c1")]),
            .response("The tool said hello.")
        ])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(), approver: StubApprover()))

        #expect(toolResults(result.elements).map(\.0) == [.succeeded])
        #expect(finished(result.elements) == [.finished(.completed)])
        let second = try #require(provider.requests.last)
        #expect(second.messages.suffix(2).map(\.role) == [.assistant, .tool])
        #expect(second.messages.last?.content == "hello")
        #expect(second.messages.last?.toolCallID == "c1")
        #expect(second.messages.last?.toolName == "echo")
    }

    @Test("multiple tool calls run in order within one iteration")
    func multipleToolCalls() async throws {
        let provider = FakeLLMProvider(turns: [
            .toolCalls([Fixtures.call("echo", #"{"text":"one"}"#), Fixtures.call("echo", #"{"text":"two"}"#)]),
            .response("Done")
        ])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(), approver: StubApprover()))

        #expect(toolResults(result.elements).map(\.1) == ["one", "two"])
        #expect(provider.requests.count == 2)
        #expect(provider.requests[1].messages.filter { $0.role == .tool }.count == 2)
    }

    @Test("an invalid tool call is reported to the model, which can recover")
    func invalidToolCall() async throws {
        let provider = FakeLLMProvider(turns: [
            .malformedToolCall(name: "echo", rawArguments: "{text:"),
            .toolCalls([Fixtures.call("echo", #"{"text":"fixed"}"#)]),
            .response("Recovered")
        ])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(), approver: StubApprover()))

        #expect(result.error == nil)
        #expect(toolResults(result.elements).map(\.0) == [.failed, .succeeded])
        #expect(provider.requests[1].messages.last?.content.hasPrefix("Error:") == true)
    }

    @Test("repeated invalid calls stop the run")
    func tooManyInvalidCalls() async throws {
        let provider = FakeLLMProvider(turns: Array(repeating: .toolCalls([Fixtures.call("nope")]), count: 5))
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(), approver: StubApprover()))
        #expect(result.error as? AgentError == .tooManyInvalidToolCalls(count: 3))
        #expect(provider.requests.count == 3)
    }

    @Test("a tool failure does not stop the run")
    func toolFailure() async throws {
        let provider = FakeLLMProvider(turns: [.toolCalls([Fixtures.call("fail")]), .response("It failed, sorry.")])
        let result = await collect(try runtime(provider, tools: [FailingTool()]).run(Fixtures.runRequest(), approver: StubApprover()))

        #expect(toolResults(result.elements).map(\.0) == [.failed])
        #expect(finished(result.elements) == [.finished(.completed)])
    }

    @Test("a provider failure ends the run with the provider's error")
    func providerFailure() async throws {
        let provider = FakeLLMProvider(turns: [.toolCalls([Fixtures.call("echo", #"{"text":"x"}"#)]), .failure(.modelNotFound("m"))])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(), approver: StubApprover()))
        #expect(result.error as? ProviderError == .modelNotFound("m"))
    }

    @Test("a provider timeout ends the run with a timeout error")
    func providerTimeout() async throws {
        let provider = FakeLLMProvider(turns: [.timeout(after: .milliseconds(10))])
        let result = await collect(try runtime(provider).run(Fixtures.runRequest(), approver: StubApprover()))
        #expect(result.error as? ProviderError == .timedOut)
    }

    @Test("a slow tool times out and the model is told")
    func toolTimeout() async throws {
        let provider = FakeLLMProvider(turns: [.toolCalls([Fixtures.call("slow")]), .response("Too slow.")])
        var limits = AgentLimits()
        limits.toolTimeout = .milliseconds(50)
        let runtime = try runtime(provider, tools: [SlowTool()], limits: limits)
        let result = await collect(runtime.run(Fixtures.runRequest(), approver: StubApprover()))

        #expect(toolResults(result.elements).first?.1.contains("did not finish") == true)
        #expect(finished(result.elements) == [.finished(.completed)])
    }

    @Test("the iteration limit ends a run that keeps calling tools")
    func maxIterations() async throws {
        let provider = FakeLLMProvider(turns: Array(repeating: .toolCalls([Fixtures.call("echo", #"{"text":"again"}"#)]), count: 5))
        var limits = AgentLimits()
        limits.maxIterations = 3
        let result = await collect(try runtime(provider, limits: limits).run(Fixtures.runRequest(), approver: StubApprover()))

        #expect(finished(result.elements) == [.finished(.reachedIterationLimit)])
        #expect(provider.requests.count == 3)
    }

    @Test("a prompt larger than the context fails before calling the model")
    func contextOverflow() async throws {
        let tiny = AIModel(provider: "fake", name: "tiny", displayName: "tiny",
                           contextWindow: ContextWindow(advertisedTokens: 2_048), capabilities: [.streaming, .tools])
        let provider = FakeLLMProvider()
        let request = Fixtures.runRequest(prompt: String(repeating: "word ", count: 2_000))
        let result = await collect(try runtime(provider, model: tiny).run(request, approver: StubApprover()))

        guard case AgentError.contextOverflow = try #require(result.error) else {
            Issue.record("Expected a context overflow")
            return
        }
        #expect(provider.requests.isEmpty)
    }

    @Test("cancellation during streaming cancels the model stream")
    func cancellationDuringStream() async throws {
        let provider = FakeLLMProvider(turns: [.hang])
        let stream = try runtime(provider).run(Fixtures.runRequest(), approver: StubApprover())
        let consumer = Task { await collect(stream) }
        for _ in 0..<200 where provider.requests.isEmpty { try await Task.sleep(for: .milliseconds(5)) }
        consumer.cancel()
        _ = await consumer.value
        for _ in 0..<200 where provider.cancelledStreams == 0 { try await Task.sleep(for: .milliseconds(5)) }
        #expect(provider.cancelledStreams == 1)
    }

    @Test("cancellation during a tool stops the run without calling the model again")
    func cancellationDuringTool() async throws {
        let provider = FakeLLMProvider(turns: [.toolCalls([Fixtures.call("slow")]), .response("never")])
        let stream = try runtime(provider, tools: [SlowTool()]).run(Fixtures.runRequest(), approver: StubApprover())
        let consumer = Task { await collect(stream) }
        try await Task.sleep(for: .milliseconds(100))
        consumer.cancel()
        let result = await consumer.value

        #expect(!result.elements.contains(.finished(.completed)))
        #expect(provider.requests.count == 1)
    }

    @Test("a denied write is not executed and the run continues")
    func deniedApproval() async throws {
        let tool = RecordingWriteTool()
        let provider = FakeLLMProvider(turns: [
            .toolCalls([Fixtures.call("write_note", #"{"text":"x"}"#, id: "w")]),
            .response("OK, I won't.")
        ])
        let result = await collect(try runtime(provider, tools: [tool]).run(Fixtures.runRequest(), approver: StubApprover(.deny)))

        #expect(result.elements.contains(.toolCallStatusChanged(id: "w", status: .awaitingApproval)))
        #expect(toolResults(result.elements).map(\.0) == [.denied])
        #expect(tool.calls.values.isEmpty)
        #expect(finished(result.elements) == [.finished(.completed)])
    }

    @Test("models without tool support get no tools and a chat-only prompt")
    func modelWithoutTools() async throws {
        let chatOnly = AIModel(provider: "fake", name: "chat", displayName: "chat",
                               contextWindow: ContextWindow(advertisedTokens: 32_768), capabilities: [.streaming])
        let provider = FakeLLMProvider(turns: [.response("Hi")])
        _ = await collect(try runtime(provider, model: chatOnly).run(Fixtures.runRequest(), approver: StubApprover()))

        let request = try #require(provider.requests.first)
        #expect(request.tools.isEmpty)
        #expect(request.messages.first?.content.contains("cannot read or modify files") == true)
    }

    @Test("project instructions reach the system prompt and are reported")
    func instructions() async throws {
        let provider = FakeLLMProvider(turns: [.response("ok")])
        let rules = ProjectInstruction(source: "AGENTS.md", content: "Always write tests.", isTruncated: false)
        let result = await collect(try runtime(provider, instructions: [rules]).run(Fixtures.runRequest(), approver: StubApprover()))

        #expect(result.elements.contains(.instructionsLoaded(["AGENTS.md"])))
        #expect(provider.requests.first?.messages.first?.content.contains("Always write tests.") == true)
    }

    @Test("no model or an unavailable model fail clearly")
    func modelErrors() async throws {
        let provider = FakeLLMProvider()
        let noModel = await collect(try runtime(provider).run(Fixtures.runRequest(model: nil), approver: StubApprover()))
        #expect(noModel.error as? AgentError == .noModelSelected)

        let unresolved = AgentRuntime(resolver: StubResolver(), tools: .empty, instructionsLoader: StubInstructionsLoader())
        let unavailable = await collect(unresolved.run(Fixtures.runRequest(), approver: StubApprover()))
        #expect(unavailable.error as? AgentError == .modelUnavailable(name: "tool-model"))
    }

    @Test("reads a real file end to end with the filesystem tools")
    func endToEndWithFileSystem() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try temp.makeFile("Package.swift", contents: "// swift-tools-version: 6.0\nlet name = \"Demo\"\n")
        let provider = FakeLLMProvider(turns: [
            .toolCalls([Fixtures.call("read_file", #"{"path":"Package.swift"}"#)]),
            .response("The package is called Demo.")
        ])
        let runtime = AgentRuntime(resolver: StubResolver(model: Fixtures.toolModel, provider: provider),
                                   tools: try ToolRegistry(FileSystemTools.all()), instructionsLoader: StubInstructionsLoader())
        let result = await collect(runtime.run(Fixtures.runRequest(root: temp.url), approver: StubApprover()))

        #expect(toolResults(result.elements).first?.0 == .succeeded)
        #expect(provider.requests[1].messages.last?.content.contains("let name = \"Demo\"") == true)
    }
}

@Suite("RunContext")
struct RunContextTests {
    private func history(_ count: Int) -> [LLMMessage] {
        (0..<count).map { $0.isMultiple(of: 2) ? .user("question \($0) " + String(repeating: "x", count: 400))
                                               : .assistant("answer \($0) " + String(repeating: "y", count: 400)) }
    }

    @Test("everything is kept when it fits, in order")
    func fits() throws {
        var context = RunContext(contextTokens: 32_768, systemPrompt: "S", history: history(4), prompt: "P")
        let (messages, _) = try context.fittedMessages()
        #expect(messages.map(\.role) == [.system, .user, .assistant, .user, .assistant, .user])
        #expect(messages.last?.content == "P")
    }

    @Test("old tool results are truncated before history is dropped")
    func compactsToolResults() throws {
        var context = RunContext(contextTokens: 4_096, systemPrompt: "S", history: history(2), prompt: "P")
        context.appendAssistant(text: "", toolCalls: [Fixtures.call("read_file", id: "a")])
        context.appendToolResult(String(repeating: "r", count: 14_000), callID: "a", toolName: "read_file")
        context.appendAssistant(text: "", toolCalls: [Fixtures.call("read_file", id: "b")])
        context.appendToolResult("latest", callID: "b", toolName: "read_file")

        let (messages, tokens) = try context.fittedMessages()
        #expect(tokens <= context.promptBudget)
        #expect(messages.contains { $0.content.contains("earlier output truncated") })
        #expect(messages.last?.content == "latest")
        #expect(messages.filter { $0.role == .user }.count == 2)
    }

    @Test("the oldest history is dropped next, never starting with an answer")
    func dropsHistory() throws {
        var context = RunContext(contextTokens: 2_048, systemPrompt: "S", history: history(10), prompt: "P")
        let (messages, tokens) = try context.fittedMessages()
        #expect(tokens <= context.promptBudget)
        #expect(messages.count < 12)
        #expect(messages[1].role == .user)
    }

    @Test("a quarter of the context, at least 1K, is reserved for the answer")
    func budget() {
        #expect(RunContext(contextTokens: 8_192, systemPrompt: "", history: [], prompt: "").promptBudget == 6_144)
        #expect(RunContext(contextTokens: 2_048, systemPrompt: "", history: [], prompt: "").promptBudget == 1_024)
    }

    @Test("history conversion summarizes earlier tool calls and skips failures")
    func historyConversion() {
        var assistant = AgentMessage(role: .assistant, text: "Done.", createdAt: Date())
        assistant.toolCalls = [
            ToolCallRecord(id: "1", name: "read_file", argumentsJSON: #"{"path":"a"}"#, status: .succeeded, summary: "Read a")
        ]
        let converted = AgentPrompt.history(from: [
            AgentMessage(role: .user, text: "Q", createdAt: Date()),
            assistant,
            AgentMessage(role: .assistant, text: "x", state: .failed, createdAt: Date()),
            AgentMessage(role: .error, text: "boom", createdAt: Date())
        ])
        #expect(converted.map(\.role) == [.user, .assistant])
        #expect(converted[1].content.contains(#"- read_file {"path":"a"} → Read a"#))
    }
}
