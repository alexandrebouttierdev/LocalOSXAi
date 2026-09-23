import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("FilesViewModel")
struct FilesViewModelTests {
    private let browser = StubFileBrowser(files: [
        "Sources/App/AgentView.swift": "struct AgentView {}", "Sources/App/AgentViewModel.swift": "final class A {}",
        "README.md": "# Demo", "guides/agent.md": "Agent guide"
    ])

    @Test("loads files and ranks file-name matches first")
    func search() async {
        let viewModel = FilesViewModel(projectRoot: URL(fileURLWithPath: "/tmp"), browser: browser)
        await viewModel.load()
        #expect(viewModel.results.count == 4)

        viewModel.query = "agentview"
        #expect(viewModel.results.first == "Sources/App/AgentView.swift")
        #expect(!viewModel.results.contains("README.md"))
    }

    @Test("selecting a file loads its preview, or explains why not")
    func preview() async {
        let viewModel = FilesViewModel(projectRoot: URL(fileURLWithPath: "/tmp"), browser: browser)
        await viewModel.select("README.md")
        #expect(viewModel.preview == .text("# Demo"))

        await viewModel.select("missing.swift")
        #expect(viewModel.preview == .unavailable("Tool failed: No file at “missing.swift”."))
    }
}

@Suite("GitIgnore and LocalFileBrowser")
struct GitIgnoreTests {
    @Test("common .gitignore rules", arguments: [
        ("build/", "build", true, true), ("build/", "build", false, false), ("*.log", "logs/app.log", false, true),
        ("/dist", "dist", true, true), ("/dist", "src/dist", true, false), ("docs/*.pdf", "docs/a.pdf", false, true),
        ("docs/*.pdf", "other/docs/a.pdf", false, false), ("secret.txt", "a/b/secret.txt", false, true)
    ])
    func rules(pattern: String, path: String, isDirectory: Bool, ignored: Bool) {
        #expect(GitIgnore(contents: pattern).isIgnored(path, isDirectory: isDirectory) == ignored)
    }

    @Test("negation re-includes a path, comments and blanks are ignored")
    func negation() {
        let ignore = GitIgnore(contents: "# comment\n\n*.env\n!example.env\n")
        #expect(ignore.isIgnored("prod.env", isDirectory: false))
        #expect(!ignore.isIgnored("example.env", isDirectory: false))
    }

    @Test("the browser and the agent's tools skip ignored files")
    func browserSkipsIgnored() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try temp.makeFile(".gitignore", contents: "generated/\n*.log\n")
        try temp.makeDirectory("generated")
        try temp.makeFile("generated/out.swift", contents: "x")
        try temp.makeFile("debug.log", contents: "x")
        try temp.makeFile("main.swift", contents: "print(1)")

        #expect(try await LocalFileBrowser().files(in: temp.url) == ["main.swift"])
        #expect(try await LocalFileBrowser().contents(of: "main.swift", in: temp.url) == "print(1)")
        await #expect(throws: ToolError.self) { try await LocalFileBrowser().contents(of: "../x", in: temp.url) }
    }
}
