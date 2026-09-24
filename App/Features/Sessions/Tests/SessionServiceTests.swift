import Foundation
import Testing
@testable import LocalOSXAi

@Suite("SessionService")
struct SessionServiceTests {
    private let projectID = UUID()

    @Test("new sessions start empty with the default title")
    func createSession() async throws {
        let clock = TestClock()
        let service = SessionService(repository: InMemorySessionRepository(), now: clock.provider)
        let model = AIModel.ID(provider: "ollama", name: "gpt-oss:20b")

        let session = try await service.createSession(in: projectID, model: model)

        #expect(session.title == Session.defaultTitle)
        #expect(session.messages.isEmpty)
        #expect(session.model == model)
        #expect(session.createdAt == clock.now)
    }

    @Test("saving messages names the session after the first prompt and bumps updatedAt")
    func updateMessagesDerivesTitle() async throws {
        let clock = TestClock()
        let service = SessionService(repository: InMemorySessionRepository(), now: clock.provider)
        let session = try await service.createSession(in: projectID, model: nil)
        clock.advance(by: 30)

        let messages = [AgentMessage(role: .user, text: "Fix the failing login test\nwith details", createdAt: clock.now)]
        let updated = try #require(try await service.updateMessages(messages, model: nil, in: session.id))

        #expect(updated.title == "Fix the failing login test")
        #expect(updated.updatedAt == clock.now)
        #expect(updated.messages == messages)
    }

    @Test("a custom title is never overwritten")
    func keepsCustomTitle() async throws {
        let repository = InMemorySessionRepository(sessions: [Fixtures.session(projectID: projectID, title: "Refactor")])
        let service = SessionService(repository: repository)
        let session = try #require(try await service.sessions(in: projectID).first)

        let updated = try await service.updateMessages(
            [AgentMessage(role: .user, text: "Something else", createdAt: Date())], model: nil, in: session.id
        )

        #expect(updated?.title == "Refactor")
    }

    @Test("updating an unknown session returns nil")
    func unknownSession() async throws {
        let service = SessionService(repository: InMemorySessionRepository())
        #expect(try await service.updateMessages([], model: nil, in: UUID()) == nil)
    }

    @Test("sessions are listed most recent first")
    func ordering() async throws {
        let older = Fixtures.session(projectID: projectID, title: "Old", updatedAt: Date(timeIntervalSinceReferenceDate: 1))
        let newer = Fixtures.session(projectID: projectID, title: "New", updatedAt: Date(timeIntervalSinceReferenceDate: 2))
        let service = SessionService(repository: InMemorySessionRepository(sessions: [older, newer]))
        #expect(try await service.sessions(in: projectID).map(\.title) == ["New", "Old"])
    }

    @Test("derived titles are truncated on a word boundary")
    func titleTruncation() throws {
        let prompt = String(repeating: "word ", count: 30)
        let title = try #require(SessionService.derivedTitle(from: [AgentMessage(role: .user, text: prompt, createdAt: Date())]))
        #expect(title.hasSuffix("…"))
        #expect(title.count <= SessionService.maxDerivedTitleLength + 1)
        #expect(!title.contains("wor…"))
    }

    @Test("no title is derived without a user message")
    func noUserMessage() {
        #expect(SessionService.derivedTitle(from: []) == nil)
        #expect(SessionService.derivedTitle(from: [AgentMessage(role: .user, text: "   ", createdAt: Date())]) == nil)
    }

    @Test("the tool call count spans every message")
    func toolCallCount() {
        let call = ToolCallRecord(id: "1", name: "read_file", argumentsJSON: "{}", status: .succeeded)
        var session = Fixtures.session(projectID: projectID, title: "T", updatedAt: Date())
        #expect(session.toolCallCount == 0)
        session.messages = [
            AgentMessage(role: .assistant, text: "", toolCalls: [call, call], createdAt: Date()),
            AgentMessage(role: .user, text: "go", createdAt: Date()),
            AgentMessage(role: .assistant, text: "", toolCalls: [call], createdAt: Date())
        ]
        #expect(session.toolCallCount == 3)
    }
}
