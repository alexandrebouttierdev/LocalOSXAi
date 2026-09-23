import Foundation

/// Use cases for opening and listing projects.
///
/// Holds the rules that do not belong in storage or UI: folder validation,
/// path normalization and de-duplication of re-opened folders.
struct ProjectService: Sendable {
    private let repository: any ProjectRepository
    private let now: @Sendable () -> Date

    init(repository: any ProjectRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    /// Opens `url` as a project, or re-opens the existing project for that folder.
    ///
    /// - Throws: `ProjectError` when the path is missing or not a folder, or a
    ///   repository error when the project cannot be saved.
    func openProject(at url: URL) async throws -> Project {
        let rootURL = Self.normalized(url)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            throw ProjectError.folderNotFound(path: rootURL.path)
        }
        guard isDirectory.boolValue else { throw ProjectError.notAFolder(path: rootURL.path) }

        let timestamp = now()
        if var existing = try await repository.project(withRootURL: rootURL) {
            existing.lastOpenedAt = timestamp
            try await repository.save(existing)
            return existing
        }

        let project = Project(
            id: UUID(),
            name: rootURL.lastPathComponent,
            rootURL: rootURL,
            createdAt: timestamp,
            lastOpenedAt: timestamp
        )
        try await repository.save(project)
        return project
    }

    /// All projects, most recently opened first.
    func recentProjects() async throws -> [Project] {
        try await repository.allProjects().sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    /// Forgets a project. The folder on disk is never touched.
    func removeProject(id: Project.ID) async throws {
        try await repository.deleteProject(id: id)
    }

    /// Canonical form used as the project boundary: absolute, standardized,
    /// symlinks resolved (so `/var/…` and `/private/var/…` are the same project).
    static func normalized(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
