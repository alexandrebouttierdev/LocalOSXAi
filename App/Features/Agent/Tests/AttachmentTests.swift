import Foundation
import Testing
@testable import LocalOSXAi

@Suite("Attachments")
struct AttachmentTests {
    private let root = URL(fileURLWithPath: "/tmp/Demo")

    @Test("long files keep their beginning and say they were truncated")
    func truncation() {
        let short = MessageAttachment.make(name: "a.swift", path: "a.swift", text: "let a = 1", byteCount: 9)
        #expect(short.content == "let a = 1")
        #expect(!short.isTruncated)
        let long = MessageAttachment.make(name: "log.txt", path: "log.txt",
                                          text: String(repeating: "x", count: MessageAttachment.maxCharacters + 5),
                                          byteCount: MessageAttachment.maxCharacters + 5)
        #expect(long.content.count == MessageAttachment.maxCharacters)
        #expect(long.isTruncated)
    }

    @Test("project files are shown relative to the project, others by their full path")
    func displayPath() {
        #expect(MessageAttachment.displayPath(of: root.appending(path: "Sources/App.swift"), projectRoot: root) == "Sources/App.swift")
        #expect(MessageAttachment.displayPath(of: URL(fileURLWithPath: "/tmp/DemoOther/a.txt"), projectRoot: root)
                == "/tmp/DemoOther/a.txt")
        #expect(MessageAttachment.displayPath(of: URL(fileURLWithPath: "/Users/me/notes.md"), projectRoot: root)
                == "/Users/me/notes.md")
    }

    @Test("the model reads the text, then each file in a block with its path")
    func userContent() {
        let file = MessageAttachment(name: "a.swift", path: "Sources/a.swift", content: "let a = 1", byteCount: 9)
        #expect(AgentPrompt.userContent("Review this", attachments: []) == "Review this")
        #expect(AgentPrompt.userContent("Review this", attachments: [file])
                == "Review this\n\nAttached file:\n\n<file path=\"Sources/a.swift\">\nlet a = 1\n</file>")
        let truncated = MessageAttachment(name: "log.txt", path: "/var/log.txt", content: "x", byteCount: 1, isTruncated: true)
        let content = AgentPrompt.userContent("", attachments: [file, truncated])
        #expect(content.hasPrefix("Attached files:\n\n<file path=\"Sources/a.swift\">"))
        #expect(content.hasSuffix("[Only the first \(MessageAttachment.maxCharacters) characters of log.txt were attached.]"))
    }

    @Test("earlier messages are replayed with their attachments")
    func history() {
        var question = AgentMessage(role: .user, text: "Explain", createdAt: Date())
        question.attachments = [MessageAttachment(name: "a.swift", path: "a.swift", content: "let a = 1", byteCount: 9)]
        let history = AgentPrompt.history(from: [question])
        #expect(history.messages.first?.content.contains("<file path=\"a.swift\">\nlet a = 1\n</file>") == true)
    }

    @Test("a run sends the attachments with the new message")
    func runSendsAttachments() async throws {
        let provider = FakeLLMProvider(turns: [.response("ok")])
        let runtime = AgentRuntime(resolver: StubResolver(model: Fixtures.toolModel, provider: provider),
                                   tools: try ToolRegistry(), instructionsLoader: StubInstructionsLoader())
        var request = Fixtures.runRequest(prompt: "What does it do?")
        request.attachments = [MessageAttachment(name: "a.swift", path: "a.swift", content: "print(1)", byteCount: 8)]

        _ = await collect(runtime.run(request, approver: StubApprover()))

        let last = try #require(provider.requests.first?.messages.last)
        #expect(last.role == .user)
        #expect(last.content.hasPrefix("What does it do?\n\nAttached file:"))
        #expect(last.content.contains("print(1)"))
    }
}

@Suite("LocalAttachmentLoader")
struct LocalAttachmentLoaderTests {
    private let loader = LocalAttachmentLoader()

    @Test("a text file is read with its size and project-relative path")
    func textFile() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        try temp.makeDirectory("Sources")
        let file = try temp.makeFile("Sources/main.swift", contents: "print(\"hi\")\n")

        let attachment = try await loader.attachment(from: file, projectRoot: temp.url)

        #expect(attachment.name == "main.swift")
        #expect(attachment.path == "Sources/main.swift")
        #expect(attachment.content == "print(\"hi\")\n")
        #expect(attachment.byteCount == 12)
    }

    @Test("images, binaries, folders and missing files are refused with a reason")
    func refused() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let image = try temp.makeFile("shot.PNG", contents: "not really")
        let binary = temp.url.appending(path: "tool")
        try Data([0x7F, 0x45, 0x00, 0x01]).write(to: binary)
        let folder = try temp.makeDirectory("folder")

        await #expect(throws: AttachmentError.image(name: "shot.PNG")) { try await loader.attachment(from: image, projectRoot: temp.url) }
        await #expect(throws: AttachmentError.notText(name: "tool")) { try await loader.attachment(from: binary, projectRoot: temp.url) }
        await #expect(throws: AttachmentError.notAFile(name: "folder")) {
            try await loader.attachment(from: folder, projectRoot: temp.url)
        }
        await #expect(throws: AttachmentError.notAFile(name: "gone.txt")) {
            try await loader.attachment(from: temp.url.appending(path: "gone.txt"), projectRoot: temp.url)
        }
    }

    @Test("files over the size limit are refused before being read")
    func tooLarge() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = temp.url.appending(path: "big.log")
        try Data(repeating: 0x61, count: MessageAttachment.maxFileBytes + 1).write(to: file)

        await #expect(throws: AttachmentError.tooLarge(name: "big.log", bytes: MessageAttachment.maxFileBytes + 1)) {
            try await loader.attachment(from: file, projectRoot: temp.url)
        }
    }
}
