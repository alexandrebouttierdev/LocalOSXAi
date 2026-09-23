import Foundation
import Observation

/// State of the project list shown in the sidebar and welcome screen.
///
/// Selection is not stored here: it is navigation state owned by
/// `WorkspaceViewModel`, which coordinates projects and sessions.
@MainActor
@Observable
final class ProjectsViewModel {
    private(set) var projects: [Project] = []
    private(set) var isLoading = false
    var error: UserFacingError?

    private let service: ProjectService

    init(service: ProjectService) {
        self.service = service
    }

    func project(id: Project.ID?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await service.recentProjects()
        } catch {
            self.error = UserFacingError(error, title: "Could not load projects", category: .persistence)
        }
    }

    /// Opens a folder and returns the resulting project, or `nil` after
    /// publishing a user-facing error.
    func open(_ url: URL) async -> Project? {
        do {
            let project = try await service.openProject(at: url)
            projects = try await service.recentProjects()
            return project
        } catch {
            self.error = UserFacingError(error, title: "Could not open project", category: .ui)
            return nil
        }
    }

    func remove(_ id: Project.ID) async {
        do {
            try await service.removeProject(id: id)
            projects.removeAll { $0.id == id }
        } catch {
            self.error = UserFacingError(error, title: "Could not remove project", category: .persistence)
        }
    }
}
