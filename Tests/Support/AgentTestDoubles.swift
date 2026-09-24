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

/// Returns fixed instructions, plus `claudeInstructions` when the run opted in.
struct StubInstructionsLoader: ProjectInstructionsLoading {
    var instructions: [ProjectInstruction] = []
    var claudeInstructions: [ProjectInstruction] = []

    func instructions(for projectRoot: URL, includingClaudeInstructions: Bool) async -> [ProjectInstruction] {
        includingClaudeInstructions ? instructions + claudeInstructions : instructions
    }
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

/// A `CommandRunner` that replays scripted events and records requests.
final class StubCommandRunner: CommandRunner {
    private let events: [CommandEvent]
    private let hangs: Bool
    private let recorded = Recorder<CommandRequest>()

    init(_ events: [CommandEvent] = [.exited(CommandExit(code: 0, duration: .zero, timedOut: false))], hangs: Bool = false) {
        self.events = events
        self.hangs = hangs
    }

    var requests: [CommandRequest] { recorded.values }

    func run(_ request: CommandRequest) -> AsyncThrowingStream<CommandEvent, Error> {
        recorded.record(request)
        let events = events
        let hangs = hangs
        return AsyncThrowingStream { continuation in
            let task = Task {
                events.forEach { continuation.yield($0) }
                if hangs {
                    do { try await Task.sleep(for: .seconds(3_600)) } catch {
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// A `GitService` returning fixed data.
struct StubGitService: GitService {
    var status = GitStatus(branch: "main")
    var commits: [GitCommit] = []
    var error: GitError?

    func status(in root: URL) async throws -> GitStatus {
        if let error { throw error }
        return status
    }

    func diff(in root: URL, path: String?, staged: Bool) async throws -> String { "" }

    func log(in root: URL, limit: Int) async throws -> [GitCommit] {
        if let error { throw error }
        return Array(commits.prefix(limit))
    }
}

/// A `ProjectFileBrowsing` over an in-memory file table.
struct StubFileBrowser: ProjectFileBrowsing {
    var files: [String: String] = [:]

    func files(in projectRoot: URL) async throws -> [String] { files.keys.sorted() }

    func contents(of path: String, in projectRoot: URL) async throws -> String {
        guard let text = files[path] else { throw ToolError.executionFailed("No file at “\(path)”.") }
        return text
    }
}

extension WorkspaceServices {
    @MainActor
    static func stub(agent: any AgentService = StubAgentService(.events([.finished(.completed)])),
                     git: any GitService = StubGitService(), browser: any ProjectFileBrowsing = StubFileBrowser()) -> WorkspaceServices {
        WorkspaceServices(agentService: agent, commandRunner: StubCommandRunner(), git: git, changeTracker: ChangeTracker(),
                          fileBrowser: browser, toolDefinitions: [], isSimulated: false)
    }
}
