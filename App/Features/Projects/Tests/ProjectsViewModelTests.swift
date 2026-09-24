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

    @Test("the CLAUDE.md opt-in is saved per project")
    func claudeOptIn() async throws {
        let project = Fixtures.project()
        let repository = InMemoryProjectRepository(projects: [project])
        let viewModel = ProjectsViewModel(service: ProjectService(repository: repository))
        await viewModel.load()

        await viewModel.setIncludesClaudeInstructions(true, for: project.id)

        #expect(viewModel.project(id: project.id)?.includesClaudeInstructions == true)
        #expect(await repository.allProjects().first?.includesClaudeInstructions == true)
    }

    @Test("command rules are edited per project: normalized, without duplicates")
    func commandRules() async throws {
        let project = Fixtures.project()
        let repository = InMemoryProjectRepository(projects: [project])
        let viewModel = ProjectsViewModel(service: ProjectService(repository: repository))
        await viewModel.load()

        await viewModel.addAllowedCommandPrefix("  npm   install ", for: project.id)
        await viewModel.addAllowedCommandPrefix("npm install", for: project.id)
        await viewModel.addAllowedCommandPrefix("   ", for: project.id)
        await viewModel.addAllowedCommandPrefix("git commit", for: project.id)
        await viewModel.setCommandMode(.askForEverything, for: project.id)
        await viewModel.removeAllowedCommandPrefix("git commit", for: project.id)

        let expected = CommandRules(mode: .askForEverything, allowedPrefixes: ["npm install"])
        #expect(viewModel.project(id: project.id)?.commandRules == expected)
        #expect(await repository.allProjects().first?.commandRules == expected)
    }
}
