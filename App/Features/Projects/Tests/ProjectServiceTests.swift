import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ProjectService")
struct ProjectServiceTests {
    @Test("opening a folder creates a project named after it")
    func opensFolder() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let folder = try temp.makeDirectory("MyApp")
        let clock = TestClock()
        let service = ProjectService(repository: InMemoryProjectRepository(), now: clock.provider)

        let project = try await service.openProject(at: folder)

        #expect(project.name == "MyApp")
        #expect(project.rootURL == ProjectService.normalized(folder))
        #expect(project.createdAt == clock.now)
    }

    @Test("re-opening the same folder, even through another spelling, reuses the project")
    func reopensExistingProject() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let folder = try temp.makeDirectory("MyApp")
        let clock = TestClock()
        let repository: any ProjectRepository = InMemoryProjectRepository()
        let service = ProjectService(repository: repository, now: clock.provider)

        let first = try await service.openProject(at: folder)
        clock.advance(by: 60)
        let alias = folder.appendingPathComponent("..").appendingPathComponent("MyApp")
        let second = try await service.openProject(at: alias)

        #expect(second.id == first.id)
        #expect(second.lastOpenedAt == clock.now)
        #expect(try await repository.allProjects().count == 1)
    }

    @Test("a symlink to a folder resolves to the same project")
    func symlinkResolvesToSameProject() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let folder = try temp.makeDirectory("Real")
        let link = temp.url.appendingPathComponent("Link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)
        let service = ProjectService(repository: InMemoryProjectRepository())

        let viaFolder = try await service.openProject(at: folder)
        let viaLink = try await service.openProject(at: link)

        #expect(viaFolder.id == viaLink.id)
    }

    @Test("a missing folder is rejected")
    func missingFolder() async throws {
        let service = ProjectService(repository: InMemoryProjectRepository())
        let missing = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")
        await #expect(throws: ProjectError.folderNotFound(path: missing.path)) {
            try await service.openProject(at: missing)
        }
    }

    @Test("a file is rejected")
    func fileIsNotAFolder() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let file = try temp.makeFile("notes.txt")
        let service = ProjectService(repository: InMemoryProjectRepository())
        await #expect {
            try await service.openProject(at: file)
        } throws: { error in
            guard case ProjectError.notAFolder = error else { return false }
            return true
        }
    }

    @Test("recent projects are ordered by last opening, and removal forgets a project")
    func recentAndRemove() async throws {
        let older = Fixtures.project(name: "Old", openedAt: Date(timeIntervalSinceReferenceDate: 1))
        let newer = Fixtures.project(name: "New", root: URL(fileURLWithPath: "/tmp/New"),
                                     openedAt: Date(timeIntervalSinceReferenceDate: 2))
        let service = ProjectService(repository: InMemoryProjectRepository(projects: [older, newer]))

        #expect(try await service.recentProjects().map(\.name) == ["New", "Old"])
        try await service.removeProject(id: newer.id)
        #expect(try await service.recentProjects().map(\.name) == ["Old"])
    }
}
