import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ProjectBoundary")
struct ProjectBoundaryTests {
    @Test("relative, dotted and absolute paths inside the project resolve")
    func insidePaths() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try temp.makeDirectory("Sources")
        let root = temp.url

        let relative = try ProjectBoundary.resolve("Sources/App.swift", in: root)
        #expect(ProjectBoundary.relativePath(of: relative, in: root) == "Sources/App.swift")
        #expect(try ProjectBoundary.resolve("./Sources/../README.md", in: root).lastPathComponent == "README.md")
        #expect(ProjectBoundary.relativePath(of: try ProjectBoundary.resolve("", in: root), in: root) == ".")
        let absolute = try ProjectBoundary.resolve(root.appending(path: "Sources").path, in: root)
        #expect(ProjectBoundary.relativePath(of: absolute, in: root) == "Sources")
    }

    @Test("escaping paths are refused", arguments: ["..", "../other", "Sources/../../x", "/etc/passwd", "~/.ssh/id_rsa"])
    func escapingPaths(path: String) throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try temp.makeDirectory("Sources")
        #expect(throws: ToolError.outsideProjectBoundary(path: path)) {
            try ProjectBoundary.resolve(path, in: temp.url)
        }
    }

    @Test("a sibling folder sharing the root's prefix is outside")
    func prefixSibling() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let root = try temp.makeDirectory("App")
        try temp.makeDirectory("App-secrets")
        #expect(throws: ToolError.self) { try ProjectBoundary.resolve("../App-secrets/key", in: root) }
    }

    @Test("symlinks pointing outside are refused, even for files that do not exist yet")
    func symlinkEscape() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let root = try temp.makeDirectory("App")
        let outside = try temp.makeDirectory("Outside")
        try FileManager.default.createSymbolicLink(at: root.appending(path: "link"), withDestinationURL: outside)

        #expect(throws: ToolError.self) { try ProjectBoundary.resolve("link", in: root) }
        #expect(throws: ToolError.self) { try ProjectBoundary.resolve("link/new-file.txt", in: root) }
    }

    @Test("a symlinked project root is resolved consistently")
    func symlinkedRoot() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let real = try temp.makeDirectory("Real")
        let alias = temp.url.appending(path: "Alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)
        let resolved = try ProjectBoundary.resolve("file.txt", in: alias)
        #expect(ProjectBoundary.relativePath(of: resolved, in: alias) == "file.txt")
    }
}

@Suite("ToolPermissionPolicy")
struct ToolPermissionPolicyTests {
    private let policy = ToolPermissionPolicy()
    private let root = URL(fileURLWithPath: "/tmp/Demo")

    @Test("reads are allowed, writes and commands need approval")
    func effects() {
        #expect(policy.permission(for: EchoTool(), arguments: ToolArguments(["text": "x"]), projectRoot: root) == .allowed)
        #expect(policy.permission(for: RecordingWriteTool(), arguments: ToolArguments(), projectRoot: root)
                == .requiresApproval(reason: "This changes files in your project."))
        var command = EchoTool()
        command.effect = .executesCommands
        guard case .requiresApproval = policy.permission(for: command, arguments: ToolArguments(), projectRoot: root) else {
            Issue.record("Commands must require approval")
            return
        }
    }

    @Test(
        "reading secret-looking files needs approval",
        arguments: [".env", "config/.env.production", "certs/server.pem", "id_rsa", "id_ed25519.pub", "App.KEY", ".npmrc"]
    )
    func sensitiveReads(path: String) {
        var reader = EchoTool()
        reader.parameters = ToolParameterSchema(properties: ["path": .init(.string, "p")])
        let arguments = ToolArguments(["path": .string(path)])
        guard case .requiresApproval = policy.permission(for: reader, arguments: arguments, projectRoot: root) else {
            Issue.record("\(path) should require approval")
            return
        }
    }

    @Test("ordinary files are not sensitive", arguments: ["README.md", "Sources/Environment.swift", "keyboard.swift", "env.md"])
    func ordinaryFiles(path: String) {
        #expect(!ToolPermissionPolicy.isSensitive(path: path))
    }
}

@Suite("OutputLimiter")
struct OutputLimiterTests {
    @Test("short text is unchanged; long text keeps head and tail")
    func limiting() {
        #expect(OutputLimiter.limit("short", maxCharacters: 10) == "short")
        let limited = OutputLimiter.limit(String(repeating: "a", count: 50) + String(repeating: "z", count: 50), maxCharacters: 20)
        #expect(limited.hasPrefix(String(repeating: "a", count: 10)))
        #expect(limited.hasSuffix(String(repeating: "z", count: 10)))
        #expect(limited.contains("80 characters omitted"))
    }
}
