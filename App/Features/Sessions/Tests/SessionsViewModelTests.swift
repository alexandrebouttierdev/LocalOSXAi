import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("SessionsViewModel")
struct SessionsViewModelTests {
    @Test("recent sessions exclude the current project's sessions")
    func recentExcludesCurrentProject() async {
        let current = UUID()
        let other = UUID()
        let own = Fixtures.session(projectID: current, title: "Own", updatedAt: Date(timeIntervalSinceReferenceDate: 3))
        let foreign = Fixtures.session(projectID: other, title: "Foreign", updatedAt: Date(timeIntervalSinceReferenceDate: 2))
        let viewModel = SessionsViewModel(service: SessionService(repository: InMemorySessionRepository(sessions: [own, foreign])))

        await viewModel.load(projectID: current)

        #expect(viewModel.sessions.map(\.title) == ["Own"])
        #expect(viewModel.recentSessions.map(\.title) == ["Foreign"])
        #expect(viewModel.session(id: foreign.id) == foreign)
    }

    @Test("creating a session requires a loaded project")
    func createRequiresProject() async {
        let viewModel = SessionsViewModel(service: SessionService(repository: InMemorySessionRepository()))
        #expect(await viewModel.createSession(model: nil) == nil)

        let projectID = UUID()
        await viewModel.load(projectID: projectID)
        let session = await viewModel.createSession(model: nil)
        #expect(session?.projectID == projectID)
        #expect(viewModel.sessions.count == 1)
    }

    @Test("updating messages refreshes the list")
    func updateRefreshes() async throws {
        let projectID = UUID()
        let viewModel = SessionsViewModel(service: SessionService(repository: InMemorySessionRepository()))
        await viewModel.load(projectID: projectID)
        let session = try #require(await viewModel.createSession(model: nil))

        await viewModel.updateMessages([AgentMessage(role: .user, text: "Add tests", createdAt: Date())], model: nil, in: session.id)

        #expect(viewModel.sessions.first?.title == "Add tests")
    }

    @Test("deleting a session removes it")
    func delete() async throws {
        let projectID = UUID()
        let viewModel = SessionsViewModel(service: SessionService(repository: InMemorySessionRepository()))
        await viewModel.load(projectID: projectID)
        let session = try #require(await viewModel.createSession(model: nil))

        await viewModel.delete(session.id)

        #expect(viewModel.sessions.isEmpty)
    }
}
