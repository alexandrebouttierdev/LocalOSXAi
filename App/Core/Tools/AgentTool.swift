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
}

extension AgentTool {
    var definition: ToolDefinition {
        ToolDefinition(name: name, description: description, parameters: parameters)
    }
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
}

/// The provider-facing description of a tool.
struct ToolDefinition: Sendable, Hashable {
    let name: String
    let description: String
    let parameters: ToolParameterSchema
}
