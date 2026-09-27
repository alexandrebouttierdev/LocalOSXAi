import Foundation
import Testing
@testable import LocalOSXAi

/// Files attached to the draft and sent with a message.
@MainActor
@Suite("AgentViewModel attachments", .timeLimit(.minutes(1)))
struct AgentViewModelAttachmentTests {
    private let root = URL(fileURLWithPath: "/tmp/Demo")

    private func makeViewModel(_ service: StubAgentService = StubAgentService(.events([.finished(.completed)])),
                               files: [String: String] = ["a.swift": "let a = 1", "b.md": "# B"]) -> AgentViewModel {
        AgentViewModel(sessionID: UUID(), projectRoot: root, messages: [], agentService: service,
                       currentModel: { nil }, persist: { _, _ in },
                       attachmentLoader: StubAttachmentLoader(files: files))
    }

    @Test("attaching reads the files once each and keeps them in the draft until removed")
    func attachAndRemove() async throws {
        let viewModel = makeViewModel()
        #expect(viewModel.canAttach)

        await viewModel.attach([root.appending(path: "a.swift"), root.appending(path: "b.md"), root.appending(path: "a.swift")])
        #expect(viewModel.draftAttachments.map(\.path) == ["a.swift", "b.md"])
        #expect(viewModel.attachmentError == nil)

        viewModel.removeAttachment(try #require(viewModel.draftAttachments.first).id)
        #expect(viewModel.draftAttachments.map(\.name) == ["b.md"])
    }

    @Test("a file that cannot be attached is reported, and the others are kept")
    func failure() async {
        let viewModel = makeViewModel()
        await viewModel.attach([root.appending(path: "tool"), root.appending(path: "a.swift")])

        #expect(viewModel.draftAttachments.map(\.name) == ["a.swift"])
        #expect(viewModel.attachmentError?.message == AttachmentError.notText(name: "tool").errorDescription)
        viewModel.dismissAttachmentError()
        #expect(viewModel.attachmentError == nil)
    }

    @Test("a message has at most a fixed number of files")
    func limit() async {
        let names = (0...MessageAttachment.maxPerMessage).map { "f\($0).txt" }
        let viewModel = makeViewModel(files: Dictionary(uniqueKeysWithValues: names.map { ($0, "x") }))
        await viewModel.attach(names.map { root.appending(path: $0) })

        #expect(viewModel.draftAttachments.count == MessageAttachment.maxPerMessage)
        #expect(viewModel.attachmentError?.message == AttachmentError.tooMany(limit: MessageAttachment.maxPerMessage).errorDescription)
    }

    @Test("files alone can be sent; they go with the message and the request, and the draft is cleared")
    func sendWithAttachments() async throws {
        let service = StubAgentService(.events([.finished(.completed)]))
        let viewModel = makeViewModel(service)
        #expect(!viewModel.canSend)
        await viewModel.attach([root.appending(path: "a.swift")])
        #expect(viewModel.canSend)

        viewModel.send()
        await viewModel.waitUntilIdle()

        let request = try #require(service.requests.first)
        #expect(request.prompt.isEmpty)
        #expect(request.attachments.map(\.name) == ["a.swift"])
        #expect(viewModel.messages.first?.attachments.map(\.name) == ["a.swift"])
        #expect(viewModel.draftAttachments.isEmpty)
    }

    @Test("retrying sends the same attachments again")
    func retry() async throws {
        let service = StubAgentService(sequence: [.failAfter([], ProviderError.timedOut), .events([.finished(.completed)])])
        let viewModel = makeViewModel(service)
        await viewModel.attach([root.appending(path: "b.md")])
        viewModel.draft = "Summarize"
        viewModel.send()
        await viewModel.waitUntilIdle()

        viewModel.retry()
        await viewModel.waitUntilIdle()

        #expect(service.requests.count == 2)
        #expect(service.requests.last?.attachments.map(\.name) == ["b.md"])
        #expect(viewModel.messages.first?.attachments.map(\.name) == ["b.md"])
    }

    @Test("without a loader, attaching is unavailable")
    func noLoader() async {
        let viewModel = AgentViewModel(sessionID: UUID(), projectRoot: root, messages: [],
                                       agentService: StubAgentService(.events([])), currentModel: { nil }, persist: { _, _ in })
        #expect(!viewModel.canAttach)
        await viewModel.attach([root.appending(path: "a.swift")])
        #expect(viewModel.draftAttachments.isEmpty)
    }
}
