import Foundation
import Synchronization
@testable import LocalOSXAi

/// Answers approval requests with a fixed decision and records them.
final class StubApprover: ToolApprover {
    private let decision: ToolApprovalDecision
    private let recorded = Mutex<[ToolApprovalRequest]>([])

    init(_ decision: ToolApprovalDecision = .allowOnce) {
        self.decision = decision
    }

    var requests: [ToolApprovalRequest] { recorded.withLock { $0 } }

    func decide(_ request: ToolApprovalRequest) async -> ToolApprovalDecision {
        recorded.withLock { $0.append(request) }
        return decision
    }
}

/// Resolves every model id to one fixed model and provider (or to nothing).
struct StubResolver: ModelResolving {
    let resolved: ResolvedModel?

    init(model: AIModel, provider: any LLMProvider) {
        resolved = ResolvedModel(model: model, provider: provider)
    }

    init(nothing: Void = ()) {
        resolved = nil
    }

    func resolve(_ id: AIModel.ID) async -> ResolvedModel? { resolved }
}

/// Returns fixed instructions.
struct StubInstructionsLoader: ProjectInstructionsLoading {
    var instructions: [ProjectInstruction] = []

    func instructions(for projectRoot: URL) async -> [ProjectInstruction] { instructions }
}

/// A tool that sleeps (cooperatively) before succeeding, for timeouts and cancellation.
struct SlowTool: AgentTool {
    var name = "slow"
    var description = "Waits."
    var parameters = ToolParameterSchema.empty
    var effect = ToolEffect.readOnly
    var delay: Duration = .seconds(3_600)

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        try await Task.sleep(for: delay)
        return .success("done", summary: "Done")
    }
}

/// A tool that always throws.
struct FailingTool: AgentTool {
    var name = "fail"
    var description = "Fails."
    var parameters = ToolParameterSchema.empty
    var effect = ToolEffect.readOnly

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        throw ToolError.executionFailed("disk on fire")
    }
}

/// A file-writing tool that only records it was called.
struct RecordingWriteTool: AgentTool {
    var name = "write_note"
    var description = "Writes a note."
    var parameters = ToolParameterSchema(properties: ["text": .init(.string, "Text")], required: ["text"])
    var effect = ToolEffect.writesFiles
    let calls = Recorder<String>()

    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult {
        let text = try arguments.string("text")
        calls.record(text)
        return .success("Wrote note", summary: "Wrote note")
    }
}

extension Fixtures {
    static let toolModel = AIModel(
        provider: "fake", name: "tool-model", displayName: "tool-model",
        contextWindow: ContextWindow(advertisedTokens: 32_768), capabilities: [.streaming, .tools]
    )

    static func call(_ name: String, _ arguments: String = "{}", id: String = UUID().uuidString) -> LLMToolCall {
        LLMToolCall(id: id, name: name, rawArguments: arguments)
    }

    static func runRequest(root: URL = URL(fileURLWithPath: "/tmp/Demo"), prompt: String = "Do it",
                           history: [AgentMessage] = [], model: AIModel.ID? = toolModel.id) -> AgentRunRequest {
        AgentRunRequest(sessionID: UUID(), projectRoot: root, prompt: prompt, history: history, model: model)
    }
}
