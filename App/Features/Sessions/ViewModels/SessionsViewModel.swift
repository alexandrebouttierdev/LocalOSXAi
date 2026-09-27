import Foundation
import Observation

/// The current project's sessions, shown in the sidebar.
@MainActor
@Observable
final class SessionsViewModel {
    private(set) var sessions: [Session] = []
    var error: UserFacingError?

    private let service: SessionService
    private var projectID: Project.ID?

    init(service: SessionService) {
        self.service = service
    }

    func session(id: Session.ID?) -> Session? {
        guard let id else { return nil }
        return sessions.first { $0.id == id }
    }

    /// Loads sessions for `projectID`, or clears them when `nil`.
    func load(projectID: Project.ID?) async {
        self.projectID = projectID
        do {
            sessions = if let projectID { try await service.sessions(in: projectID) } else { [] }
        } catch {
            self.error = UserFacingError(error, title: "Could not load sessions", category: .persistence)
        }
    }

    /// The full session, transcript included (lists hold summaries only).
    func fullSession(id: Session.ID) async -> Session? {
        do {
            return try await service.session(id: id)
        } catch {
            self.error = UserFacingError(error, title: "Could not open session", category: .persistence)
            return nil
        }
    }

    func createSession(model: AIModel.ID?) async -> Session? {
        guard let projectID else { return nil }
        do {
            let session = try await service.createSession(in: projectID, model: model)
            await load(projectID: projectID)
            return session
        } catch {
            self.error = UserFacingError(error, title: "Could not create session", category: .persistence)
            return nil
        }
    }

    func updateMessages(_ messages: [AgentMessage], model: AIModel.ID?, in sessionID: Session.ID) async {
        do {
            try await service.updateMessages(messages, model: model, in: sessionID)
            await load(projectID: projectID)
        } catch {
            self.error = UserFacingError(error, title: "Could not save session", category: .persistence)
        }
    }

    /// Deletes every session of a project, before the project itself is removed.
    /// Returns `false` (with an error to show) when they could not be deleted.
    func deleteAll(inProject projectID: Project.ID) async -> Bool {
        do {
            try await service.deleteSessions(inProject: projectID)
            return true
        } catch {
            self.error = UserFacingError(error, title: "Could not delete the project's sessions", category: .persistence)
            return false
        }
    }

    func delete(_ id: Session.ID) async {
        do {
            try await service.deleteSession(id: id)
            await load(projectID: projectID)
        } catch {
            self.error = UserFacingError(error, title: "Could not delete session", category: .persistence)
        }
    }
}
