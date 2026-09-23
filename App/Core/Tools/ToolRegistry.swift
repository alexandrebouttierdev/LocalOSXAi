import Foundation

/// The immutable set of tools available to an agent run.
///
/// Building a registry validates tool names once, up front, so a bad tool
/// definition fails at composition time rather than in the middle of a run.
struct ToolRegistry: Sendable {
    /// Whether `name` is accepted by every supported provider: 1–64 ASCII
    /// letters, digits, `_` or `-` (OpenAI's function-name rule is the strictest).
    static func isValidName(_ name: String) -> Bool {
        (1...64).contains(name.count)
            && name.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-") }
    }

    private let toolsByName: [String: any AgentTool]
    /// Registration order, kept so tool definitions are sent in a stable order.
    let names: [String]

    init(_ tools: [any AgentTool] = []) throws(ToolError) {
        var toolsByName: [String: any AgentTool] = [:]
        var names: [String] = []
        for tool in tools {
            guard Self.isValidName(tool.name) else { throw .invalidToolName(tool.name) }
            guard toolsByName[tool.name] == nil else { throw .duplicateTool(tool.name) }
            toolsByName[tool.name] = tool
            names.append(tool.name)
        }
        self.toolsByName = toolsByName
        self.names = names
    }

    static let empty: ToolRegistry = {
        // An empty list cannot violate any registration rule.
        guard let registry = try? ToolRegistry([]) else { preconditionFailure("Empty registry must be valid") }
        return registry
    }()

    var isEmpty: Bool { names.isEmpty }

    var definitions: [ToolDefinition] {
        names.compactMap { toolsByName[$0]?.definition }
    }

    func tool(named name: String) throws(ToolError) -> any AgentTool {
        guard let tool = toolsByName[name] else { throw .unknownTool(name) }
        return tool
    }
}
