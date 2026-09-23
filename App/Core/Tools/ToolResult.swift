import Foundation

/// Structured outcome of a tool execution.
///
/// `output` is what the model reads; `summary` is a one-line, human-oriented
/// description shown in the UI (“Read 120 lines from Package.swift”).
struct ToolResult: Sendable, Hashable {
    enum Status: String, Sendable, Hashable, Codable {
        case success
        case failure
    }

    var status: Status
    var output: String
    var summary: String

    static func success(_ output: String, summary: String) -> ToolResult {
        ToolResult(status: .success, output: output, summary: summary)
    }

    static func failure(_ output: String, summary: String) -> ToolResult {
        ToolResult(status: .failure, output: output, summary: summary)
    }
}
