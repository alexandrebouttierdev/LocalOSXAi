import Foundation

/// Failures of tool definition, validation or execution.
///
/// Validation errors are *expected*: local models regularly produce invalid
/// calls. The agent runtime converts them into tool results so the model can
/// correct itself, instead of aborting the run. See docs/ai/tools.md.
enum ToolError: Error, Hashable, Sendable {
    // Registry
    case duplicateTool(String)
    case invalidToolName(String)
    case unknownTool(String)

    // Validation
    case malformedArguments(String)
    case missingArgument(String)
    case invalidArgument(name: String, reason: String)
    case unexpectedArgument(String)

    // Execution
    case permissionDenied(String)
    case outsideProjectBoundary(path: String)
    case executionFailed(String)
    case timedOut(seconds: Double)
}

extension ToolError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .duplicateTool(let name): "A tool named “\(name)” is already registered."
        case .invalidToolName(let name): "“\(name)” is not a valid tool name."
        case .unknownTool(let name): "Unknown tool “\(name)”."
        case .malformedArguments(let detail): "Tool arguments are not valid JSON: \(detail)"
        case .missingArgument(let name): "Missing required argument “\(name)”."
        case .invalidArgument(let name, let reason): "Invalid argument “\(name)”: \(reason)"
        case .unexpectedArgument(let name): "Unexpected argument “\(name)”."
        case .permissionDenied(let reason): "Permission denied: \(reason)"
        case .outsideProjectBoundary(let path): "“\(path)” is outside the project folder."
        case .executionFailed(let detail): "Tool failed: \(detail)"
        case .timedOut(let seconds): "Tool did not finish within \(Int(seconds)) seconds."
        }
    }
}
