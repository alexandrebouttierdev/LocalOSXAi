import Foundation
import Testing
@testable import LocalOSXAi

/// Filesystem tools against real temporary folders.
@Suite("Filesystem tools")
struct FileSystemToolsTests {
    private func run(_ tool: some AgentTool, _ arguments: JSONValue, in root: URL) async throws -> ToolResult {
        let parsed = ToolArguments(arguments.objectValue ?? [:])
        try tool.parameters.validate(parsed)
        return try await tool.execute(arguments: parsed, context: ToolContext(projectRoot: root))
    }

    private func project() throws -> TemporaryDirectory {
        let temp = try TemporaryDirectory()
        try temp.makeDirectory("Sources")
        try temp.makeFile("Sources/App.swift", contents: "import SwiftUI\n\nstruct App {\n    let name = \"Demo\"\n}\n")
        try temp.makeFile("README.md", contents: "# Demo\nA demo project.\n")
        try temp.makeDirectory("node_modules/lib")
        try temp.makeFile("node_modules/lib/index.js", contents: "struct App")
        try temp.makeFile(".env", contents: "API_KEY=secret App")
        return temp
    }

    // MARK: read_file

    @Test("reads an existing file with line numbers")
    func readExisting() async throws {
        let temp = try project()
        defer { temp.remove() }
        let result = try await run(ReadFileTool(), ["path": "Sources/App.swift"], in: temp.url)
        #expect(result.status == .success)
        #expect(result.output.contains("     1\timport SwiftUI"))
        #expect(result.output.contains("     4\t    let name = \"Demo\""))
        #expect(result.summary == "Read lines 1–5 of Sources/App.swift")
    }

    @Test("reads a range and says how to continue")
    func readRange() async throws {
        let temp = try project()
        defer { temp.remove() }
        let result = try await run(ReadFileTool(), ["path": "Sources/App.swift", "offset": 2, "limit": 2], in: temp.url)
        #expect(result.output.hasPrefix("     2\t"))
        #expect(result.output.contains("Continue with offset 4"))
    }

    @Test("a missing file fails clearly")
    func readMissing() async throws {
        let temp = try project()
        defer { temp.remove() }
        await #expect(throws: ToolError.executionFailed("No file at “nope.swift”.")) {
            try await run(ReadFileTool(), ["path": "nope.swift"], in: temp.url)
        }
    }

    @Test("binary files and folders are refused")
    func readBinaryAndFolder() async throws {
        let temp = try project()
        defer { temp.remove() }
        try Data([0x89, 0x50, 0x00, 0x47]).write(to: temp.url.appending(path: "logo.png"))
        await #expect(throws: ToolError.executionFailed("“logo.png” is a binary file.")) {
            try await run(ReadFileTool(), ["path": "logo.png"], in: temp.url)
        }
        await #expect(throws: ToolError.self) { try await run(ReadFileTool(), ["path": "Sources"], in: temp.url) }
    }

    @Test("paths outside the project are refused")
    func readOutside() async throws {
        let temp = try project()
        defer { temp.remove() }
        await #expect(throws: ToolError.outsideProjectBoundary(path: "/etc/hosts")) {
            try await run(ReadFileTool(), ["path": "/etc/hosts"], in: temp.url)
        }
    }

    @Test("unreadable files report a permission error")
    func readPermissionError() async throws {
        let temp = try project()
        defer { temp.remove() }
        let file = try temp.makeFile("locked.txt", contents: "secret")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
        await #expect {
            try await run(ReadFileTool(), ["path": "locked.txt"], in: temp.url)
        } throws: { error in
            guard case ToolError.executionFailed(let message) = error else { return false }
            return message.hasPrefix("Cannot read")
        }
    }

    // MARK: write_file / edit_file

    @Test("writes a new file, creating folders, then replaces it")
    func writeFile() async throws {
        let temp = try project()
        defer { temp.remove() }
        let created = try await run(WriteFileTool(), ["path": "Docs/Notes.md", "content": "one\ntwo"], in: temp.url)
        #expect(created.summary == "Created Docs/Notes.md")
        let replaced = try await run(WriteFileTool(), ["path": "Docs/Notes.md", "content": "three"], in: temp.url)
        #expect(replaced.summary == "Replaced Docs/Notes.md")
        #expect(try String(contentsOf: temp.url.appending(path: "Docs/Notes.md"), encoding: .utf8) == "three")
    }

    @Test("writing outside the project is refused")
    func writeOutside() async throws {
        let temp = try project()
        defer { temp.remove() }
        await #expect(throws: ToolError.self) {
            try await run(WriteFileTool(), ["path": "../escape.txt", "content": "x"], in: temp.url)
        }
        #expect(!FileManager.default.fileExists(atPath: temp.url.deletingLastPathComponent().appending(path: "escape.txt").path))
    }

    @Test("edits a unique fragment")
    func editUnique() async throws {
        let temp = try project()
        defer { temp.remove() }
        let arguments: JSONValue = ["path": "Sources/App.swift", "old_string": "\"Demo\"", "new_string": "\"Shop\""]
        let result = try await run(EditFileTool(), arguments, in: temp.url)
        #expect(result.summary == "Edited Sources/App.swift")
        #expect(try String(contentsOf: temp.url.appending(path: "Sources/App.swift"), encoding: .utf8).contains("\"Shop\""))
    }

    @Test("edit fails when the fragment is missing or ambiguous, unless replace_all")
    func editFailures() async throws {
        let temp = try project()
        defer { temp.remove() }
        try temp.makeFile("dup.txt", contents: "a\na\n")
        await #expect(throws: ToolError.self) {
            try await run(EditFileTool(), ["path": "dup.txt", "old_string": "zzz", "new_string": "b"], in: temp.url)
        }
        await #expect(throws: ToolError.self) {
            try await run(EditFileTool(), ["path": "dup.txt", "old_string": "a", "new_string": "b"], in: temp.url)
        }
        _ = try await run(EditFileTool(), ["path": "dup.txt", "old_string": "a", "new_string": "b", "replace_all": true], in: temp.url)
        #expect(try String(contentsOf: temp.url.appending(path: "dup.txt"), encoding: .utf8) == "b\nb\n")
        await #expect(throws: ToolError.self) {
            try await run(EditFileTool(), ["path": "dup.txt", "old_string": "", "new_string": "b"], in: temp.url)
        }
    }

    @Test("write and edit describe themselves for approval")
    func descriptions() {
        #expect(WriteFileTool().describe(arguments: ToolArguments(["path": "a.txt", "content": "1\n2"])) == "Write a.txt (2 lines)")
        #expect(EditFileTool().describe(arguments: ToolArguments(["path": "a.txt", "replace_all": true])) == "Edit a.txt (all occurrences)")
    }

    // MARK: list / search

    @Test("lists a folder, skipping dependencies and hidden files")
    func listDirectory() async throws {
        let temp = try project()
        defer { temp.remove() }
        let flat = try await run(ListDirectoryTool(), [:], in: temp.url)
        #expect(flat.output.components(separatedBy: "\n") == ["README.md", "Sources/"])

        let recursive = try await run(ListDirectoryTool(), ["recursive": true], in: temp.url)
        #expect(recursive.output.contains("Sources/App.swift"))
        #expect(!recursive.output.contains("node_modules"))
        #expect(!recursive.output.contains(".env"))
    }

    @Test("finds files by glob pattern")
    func searchFiles() async throws {
        let temp = try project()
        defer { temp.remove() }
        #expect(try await run(SearchFilesTool(), ["pattern": "*.swift"], in: temp.url).output == "Sources/App.swift")
        let both = try await run(SearchFilesTool(), ["pattern": "**/*.{md,swift}"], in: temp.url)
        #expect(both.output.components(separatedBy: "\n").count == 2)
        #expect(try await run(SearchFilesTool(), ["pattern": "*.rb"], in: temp.url).output.hasPrefix("No files"))
    }

    @Test("searches text, never in dependencies or secret files")
    func searchText() async throws {
        let temp = try project()
        defer { temp.remove() }
        let literal = try await run(SearchTextTool(), ["query": "struct app"], in: temp.url)
        #expect(literal.output == "Sources/App.swift:3: struct App {")
        #expect(literal.summary == "1 match for struct app")

        let regex = try await run(SearchTextTool(), ["query": "^#\\s+\\w+", "is_regex": true], in: temp.url)
        #expect(regex.output == "README.md:1: # Demo")

        let caseSensitive = try await run(SearchTextTool(), ["query": "struct app", "case_sensitive": true], in: temp.url)
        #expect(caseSensitive.output.hasPrefix("No matches"))

        let secret = try await run(SearchTextTool(), ["query": "API_KEY"], in: temp.url)
        #expect(secret.output.hasPrefix("No matches"))
    }

    @Test("invalid regular expressions are reported")
    func invalidRegex() async throws {
        let temp = try project()
        defer { temp.remove() }
        await #expect(throws: ToolError.invalidArgument(name: "query", reason: "not a valid regular expression")) {
            try await run(SearchTextTool(), ["query": "(unclosed", "is_regex": true], in: temp.url)
        }
    }

    // MARK: Support

    @Test("glob patterns", arguments: [
        ("*.swift", "Sources/App.swift", true), ("*.swift", "README.md", false),
        ("Sources/*.swift", "Sources/App.swift", true), ("Sources/*.swift", "Sources/Deep/A.swift", false),
        ("**/*.swift", "Sources/Deep/A.swift", true), ("**/*.swift", "A.swift", true),
        ("*View*.{swift,md}", "Features/AgentView.swift", true), ("?.md", "a.md", true), ("?.md", "ab.md", false)
    ])
    func glob(pattern: String, path: String, matches: Bool) {
        #expect(GlobMatcher(pattern).matches(path: path) == matches)
    }

    @Test("AGENTS.md is loaded and capped")
    func instructions() async throws {
        let temp = try project()
        defer { temp.remove() }
        #expect(await FileProjectInstructionsLoader().instructions(for: temp.url).isEmpty)

        try temp.makeFile("AGENTS.md", contents: "Always write tests.")
        #expect(await FileProjectInstructionsLoader().instructions(for: temp.url)
                == [ProjectInstruction(source: "AGENTS.md", content: "Always write tests.", isTruncated: false)])

        try temp.makeFile("AGENTS.md", contents: String(repeating: "x", count: FileProjectInstructionsLoader.maxCharacters + 10))
        #expect(await FileProjectInstructionsLoader().instructions(for: temp.url).first?.isTruncated == true)
    }

    @Test("the built-in registry is valid and complete")
    @MainActor
    func builtInTools() {
        #expect(AppEnvironment.builtInTools().names
                == ["read_file", "list_directory", "search_files", "search_text", "edit_file", "write_file"])
    }
}
