import Foundation
import Testing
@testable import LocalOSXAi

/// Per-run settings: project instructions and command rules, model settings, limits.
@Suite("AgentRuntime options", .timeLimit(.minutes(1)))
struct AgentRuntimeOptionsTests {
    private func runtime(_ provider: FakeLLMProvider, tools: [any AgentTool] = [EchoTool()]) throws -> AgentRuntime {
        AgentRuntime(resolver: StubResolver(model: Fixtures.toolModel, provider: provider), tools: try ToolRegistry(tools),
                     instructionsLoader: StubInstructionsLoader())
    }

    private func finished(_ events: [AgentEvent]) -> [AgentEvent] {
        events.filter { if case .finished = $0 { true } else { false } }
    }

    @Test("CLAUDE.md is only loaded for projects that opted in")
    func claudeInstructionsOptIn() async throws {
        let loader = StubInstructionsLoader(
            instructions: [ProjectInstruction(source: "AGENTS.md", content: "Write tests.", isTruncated: false)],
            claudeInstructions: [ProjectInstruction(source: "CLAUDE.md", content: "Use tabs.", isTruncated: false)]
        )
        func run(optIn: Bool) async throws -> [AgentEvent] {
            let provider = FakeLLMProvider(turns: [.response("ok")])
            let runtime = AgentRuntime(resolver: StubResolver(model: Fixtures.toolModel, provider: provider),
                                       tools: try ToolRegistry(), instructionsLoader: loader)
            var request = Fixtures.runRequest()
            request.options.includesClaudeInstructions = optIn
            return await collect(runtime.run(request, approver: StubApprover())).elements
        }
        #expect(try await run(optIn: false).contains(.instructionsLoaded(["AGENTS.md"])))
        #expect(try await run(optIn: true).contains(.instructionsLoaded(["AGENTS.md", "CLAUDE.md"])))
    }

    @Test("the model settings of the run reach the provider, and a chosen context sets the budget")
    func generationOptions() async throws {
        let provider = FakeLLMProvider(turns: [.response("ok")])
        var request = Fixtures.runRequest()
        request.options.generation = GenerationOptions(temperature: 0.2, contextLength: 16_384, reasoning: .low)

        let result = await collect(try runtime(provider).run(request, approver: StubApprover()))

        let sent = try #require(provider.requests.first?.options)
        #expect(sent == GenerationOptions(temperature: 0.2, contextLength: 16_384, reasoning: .low))
        #expect(result.elements.contains { if case .contextUsageUpdated(let usage) = $0 { usage.budgetTokens == 16_384 } else { false } })
    }

    @Test("project command rules apply to the run, and approvals offer a rule to add")
    func commandRulesApply() async throws {
        let runner = StubCommandRunner()
        func run(_ command: String, rules: CommandRules) async throws -> StubApprover {
            let provider = FakeLLMProvider(turns: [
                .toolCalls([Fixtures.call("run_command", "{\"command\":\"\(command)\"}")]), .response("done")
            ])
            let approver = StubApprover()
            var request = Fixtures.runRequest()
            request.options.commandRules = rules
            _ = await collect(try runtime(provider, tools: [RunCommandTool(runner: runner)]).run(request, approver: approver))
            return approver
        }

        let asked = try await run("npm install lodash", rules: CommandRules())
        #expect(asked.requests.first?.command == "npm install lodash")
        #expect(asked.requests.first?.suggestedCommandRule == "npm install")

        let allowed = try await run("npm install lodash", rules: CommandRules(allowedPrefixes: ["npm install"]))
        #expect(allowed.requests.isEmpty)
        #expect(runner.requests.count == 2)
    }

    @Test("a chosen context never exceeds what the model advertises")
    func chosenContextIsCapped() async throws {
        let provider = FakeLLMProvider(turns: [.response("ok")])
        var request = Fixtures.runRequest()
        request.options.generation = GenerationOptions(contextLength: 1_000_000)
        _ = await collect(try runtime(provider).run(request, approver: StubApprover()))
        #expect(provider.requests.first?.options.contextLength == Fixtures.toolModel.contextWindow.advertisedTokens)
    }

    @Test("limits are read at the start of each run, so a settings change applies to the next run")
    func limitsReadPerRun() async throws {
        let setting = LockedValue(1)
        let provider = FakeLLMProvider(turns: [
            .toolCalls([Fixtures.call("echo", #"{"text":"a"}"#)]), .toolCalls([Fixtures.call("echo", #"{"text":"b"}"#)]),
            .response("done")
        ])
        let runtime = AgentRuntime(resolver: StubResolver(model: Fixtures.toolModel, provider: provider),
                                   tools: try ToolRegistry([EchoTool()]), instructionsLoader: StubInstructionsLoader(),
                                   limits: { AgentLimits(maxIterations: setting.value) })
        let first = await collect(runtime.run(Fixtures.runRequest(), approver: StubApprover()))
        #expect(finished(first.elements) == [.finished(.reachedIterationLimit)])

        setting.value = 5
        let second = await collect(runtime.run(Fixtures.runRequest(), approver: StubApprover()))
        #expect(finished(second.elements) == [.finished(.completed)])
    }
}
