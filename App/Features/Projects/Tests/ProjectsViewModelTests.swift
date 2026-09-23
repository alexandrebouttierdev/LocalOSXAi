import Foundation
import Testing
@testable import LocalOSXAi

@MainActor
@Suite("ProjectsViewModel")
struct ProjectsViewModelTests {
    @Test("opening a folder adds it to the list")
    func openAddsProject() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let folder = try temp.makeDirectory("App")
        let viewModel = ProjectsViewModel(service: ProjectService(repository: InMemoryProjectRepository()))

        let project = await viewModel.open(folder)

        #expect(project?.name == "App")
        #expect(viewModel.projects.map(\.name) == ["App"])
        #expect(viewModel.error == nil)
    }

    @Test("a failure is published as a user-facing error")
    func openFailurePublishesError() async {
        let viewModel = ProjectsViewModel(service: ProjectService(repository: InMemoryProjectRepository()))

        let project = await viewModel.open(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))

        #expect(project == nil)
        #expect(viewModel.error?.title == "Could not open project")
        #expect(viewModel.error?.recoverySuggestion != nil)
    }

    @Test("load and remove keep the list in sync with storage")
    func loadAndRemove() async {
        let project = Fixtures.project()
        let viewModel = ProjectsViewModel(service: ProjectService(repository: InMemoryProjectRepository(projects: [project])))

        await viewModel.load()
        #expect(viewModel.projects == [project])
        #expect(viewModel.project(id: project.id) == project)

        await viewModel.remove(project.id)
        #expect(viewModel.projects.isEmpty)
    }
}
