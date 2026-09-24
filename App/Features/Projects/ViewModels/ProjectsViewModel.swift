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

    func setIncludesClaudeInstructions(_ isIncluded: Bool, for id: Project.ID) async {
        await update(id) { $0.includesClaudeInstructions = isIncluded }
    }

    func setCommandMode(_ mode: CommandRules.Mode, for id: Project.ID) async {
        await update(id) { $0.commandRules.mode = mode }
    }

    /// Adds a prefix the agent may run without asking; ignores blanks and duplicates.
    func addAllowedCommandPrefix(_ prefix: String, for id: Project.ID) async {
        guard let normalized = CommandRules.normalizedPrefix(prefix) else { return }
        await update(id) { project in
            if !project.commandRules.allowedPrefixes.contains(normalized) {
                project.commandRules.allowedPrefixes.append(normalized)
            }
        }
    }

    func removeAllowedCommandPrefix(_ prefix: String, for id: Project.ID) async {
        await update(id) { $0.commandRules.allowedPrefixes.removeAll { $0 == prefix } }
    }

    /// Applies a settings change and saves it; the list only changes once saved.
    private func update(_ id: Project.ID, _ change: (inout Project) -> Void) async {
        guard var project = project(id: id) else { return }
        change(&project)
        guard project != self.project(id: id) else { return }
        do {
            try await service.update(project)
            if let index = projects.firstIndex(where: { $0.id == id }) { projects[index] = project }
        } catch {
            self.error = UserFacingError(error, title: "Could not save the project setting", category: .persistence)
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
