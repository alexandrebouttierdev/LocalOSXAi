import Foundation
import Testing
@testable import LocalOSXAi

@Suite("In-memory repositories")
struct InMemoryRepositoryTests {
    @Test("project repository saves, finds by root and deletes")
    func projectRepository() async throws {
        let repository: any ProjectRepository = InMemoryProjectRepository()
        let project = Fixtures.project()
        try await repository.save(project)

        #expect(try await repository.allProjects() == [project])
        #expect(try await repository.project(withRootURL: project.rootURL) == project)
        #expect(try await repository.project(withRootURL: URL(fileURLWithPath: "/elsewhere")) == nil)

        try await repository.deleteProject(id: project.id)
        #expect(try await repository.allProjects().isEmpty)
    }

    @Test("session repository filters by project and orders recent sessions")
    func sessionRepository() async throws {
        let repository: any SessionRepository = InMemorySessionRepository()
        let projectA = UUID()
        let projectB = UUID()
        let old = Fixtures.session(projectID: projectA, updatedAt: Date(timeIntervalSinceReferenceDate: 10))
        let new = Fixtures.session(projectID: projectB, updatedAt: Date(timeIntervalSinceReferenceDate: 20))
        try await repository.save(old)
        try await repository.save(new)

        #expect(try await repository.sessions(forProject: projectA) == [old])
        #expect(try await repository.recentSessions(limit: 10) == [new, old])
        #expect(try await repository.recentSessions(limit: 1) == [new])
        #expect(try await repository.recentSessions(limit: -1).isEmpty)

        try await repository.deleteSession(id: old.id)
        #expect(try await repository.session(id: old.id) == nil)
    }
}
