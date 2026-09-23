import Foundation

/// Process-lifetime project storage.
///
/// Used until the SQLite store lands in Phase 5, and by tests. An actor
/// serializes access, so concurrent callers never observe partial updates.
actor InMemoryProjectRepository: ProjectRepository {
    private var projects: [Project.ID: Project]

    init(projects: [Project] = []) {
        self.projects = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    func allProjects() -> [Project] {
        Array(projects.values)
    }

    func project(withRootURL url: URL) -> Project? {
        projects.values.first { $0.rootURL == url }
    }

    func save(_ project: Project) {
        projects[project.id] = project
    }

    func deleteProject(id: Project.ID) {
        projects[id] = nil
    }
}
