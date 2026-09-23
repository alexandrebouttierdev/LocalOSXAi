import Foundation

/// A capability the agent can invoke: read a file, run a command, query Git…
///
/// Responsibilities are split on purpose (docs/ai/tools.md):
/// - **definition**: `name`, `description`, `parameters`, `effect`;
/// - **validation**: `ToolParameterSchema.validate`, run by the executor
///   before `execute` is ever called;
/// - **execution**: `execute`, which may assume arguments passed validation;
/// - **permission**: decided by the executor from `effect`, never by the tool;
/// - **UI**: rendered by the Agent feature from `ToolCallRecord`, never here.
protocol AgentTool: Sendable {
    /// Unique, model-facing identifier. Must satisfy `ToolRegistry.isValidName`.
    var name: String { get }
    /// Model-facing explanation of when and how to use the tool.
    var description: String { get }
    var parameters: ToolParameterSchema { get }
    /// What the tool can change. Drives the permission policy.
    var effect: ToolEffect { get }

    /// Executes the tool with already-validated arguments.
    ///
    /// Implementations must check `Task.isCancelled` (or use cancellable APIs)
    /// during long operations, and must refuse paths outside
    /// `context.projectRoot` by throwing `ToolError.outsideProjectBoundary`.
    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult

    /// Human description of a call, used in approval prompts. Has a default.
    func describe(arguments: ToolArguments) -> String

    /// Execution time limit for this tool, when it needs more (or less) than
    /// the executor's default. `nil` uses the default.
    var timeout: Duration? { get }

    /// For tools that write files: the change a call would make, computed
    /// without writing, so the user can see the diff before approving.
    func proposedChange(arguments: ToolArguments, context: ToolContext) async throws -> ProposedFileChange?
}

extension AgentTool {
    var definition: ToolDefinition {
        ToolDefinition(name: name, description: description, parameters: parameters)
    }

    /// One line describing what a call will do, shown when asking the user
    /// for approval (“Write Sources/App.swift (42 lines)”). Tools with side
    /// effects should override it with something more precise.
    func describe(arguments: ToolArguments) -> String {
        "\(name) \(JSONValue.object(arguments.values).serialized())"
    }

    var timeout: Duration? { nil }

    func proposedChange(arguments: ToolArguments, context: ToolContext) async throws -> ProposedFileChange? { nil }
}

/// The side effects a tool may have, from least to most dangerous.
///
/// The permission policy maps each effect to “allowed”, “requires approval”
/// or “blocked”; see docs/security/permissions.md.
enum ToolEffect: Int, Sendable, Hashable, Comparable, CaseIterable {
    /// Reads project data only.
    case readOnly
    /// Creates or modifies files inside the project.
    case writesFiles
    /// Runs arbitrary processes.
    case executesCommands

    static func < (lhs: ToolEffect, rhs: ToolEffect) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Environment given to a tool for one execution.
struct ToolContext: Sendable {
    /// Absolute, symlink-resolved project root. Tools must not escape it.
    let projectRoot: URL
    /// Records files the agent changes, so the user can review and revert them.
    var changeRecorder: (any FileChangeRecording)?

    init(projectRoot: URL, changeRecorder: (any FileChangeRecording)? = nil) {
        self.projectRoot = projectRoot
        self.changeRecorder = changeRecorder
    }
}

/// Keeps the original content of files before the agent modifies them.
///
/// The executor calls it around every `writesFiles` tool, so tools stay
/// unaware of change tracking (docs/ai/tools.md).
protocol FileChangeRecording: Sendable {
    func willModify(_ file: URL, in projectRoot: URL) async
    func didModify(_ file: URL, in projectRoot: URL) async
}

/// What a file-writing tool is about to do, for review before approval.
struct ProposedFileChange: Hashable, Sendable {
    let file: URL
    /// Path relative to the project root.
    let path: String
    /// `nil` when the file does not exist yet.
    let currentContent: String?
    let proposedContent: String
}

/// The provider-facing description of a tool.
struct ToolDefinition: Sendable, Hashable {
    let name: String
    let description: String
    let parameters: ToolParameterSchema
}
