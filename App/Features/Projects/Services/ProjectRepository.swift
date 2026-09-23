import Foundation

/// Storage port for projects. Implemented in `Infrastructure/Persistence`.
///
/// The protocol is owned by the feature (not by the infrastructure) so the
/// feature defines what it needs and storage technology can change without
/// touching feature code. See docs/data/persistence.md.
protocol ProjectRepository: Sendable {
    func allProjects() async throws -> [Project]
    func project(withRootURL url: URL) async throws -> Project?
    func save(_ project: Project) async throws
    func deleteProject(id: Project.ID) async throws
}
