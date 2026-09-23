import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ToolRegistry")
struct ToolRegistryTests {
    @Test("registers tools and keeps registration order")
    func registrationOrder() throws {
        let registry = try ToolRegistry([EchoTool(name: "b_tool"), EchoTool(name: "a_tool")])
        #expect(registry.names == ["b_tool", "a_tool"])
        #expect(registry.definitions.map(\.name) == ["b_tool", "a_tool"])
        #expect(try registry.tool(named: "a_tool").name == "a_tool")
    }

    @Test("duplicate names are rejected")
    func duplicateNames() {
        #expect(throws: ToolError.duplicateTool("echo")) { try ToolRegistry([EchoTool(), EchoTool()]) }
    }

    @Test("invalid names are rejected", arguments: ["", "read file", "lire_fichier_é", String(repeating: "a", count: 65)])
    func invalidNames(name: String) {
        #expect(throws: ToolError.invalidToolName(name)) { try ToolRegistry([EchoTool(name: name)]) }
    }

    @Test("valid names are accepted", arguments: ["read_file", "git-diff", "Tool42", String(repeating: "a", count: 64)])
    func validNames(name: String) {
        #expect(ToolRegistry.isValidName(name))
    }

    @Test("unknown tools are reported")
    func unknownTool() throws {
        let registry = try ToolRegistry([EchoTool()])
        #expect(throws: ToolError.unknownTool("rm")) { try registry.tool(named: "rm") }
    }

    @Test("the empty registry has no definitions")
    func emptyRegistry() {
        #expect(ToolRegistry.empty.isEmpty)
        #expect(ToolRegistry.empty.definitions.isEmpty)
    }

    @Test("a registered tool validates and executes end to end")
    func executesRegisteredTool() async throws {
        let tool = try ToolRegistry([EchoTool()]).tool(named: "echo")
        let arguments = try ToolArguments.parse(#"{"text": "hello"}"#)
        try tool.parameters.validate(arguments)
        let result = try await tool.execute(arguments: arguments, context: ToolContext(projectRoot: URL(fileURLWithPath: "/tmp")))
        #expect(result == .success("hello", summary: "Echoed 5 characters"))
    }
}
