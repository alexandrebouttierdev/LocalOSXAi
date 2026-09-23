import Foundation
import Observation

/// Session lists shown in the sidebar: the current project's sessions and
/// recent sessions from other projects.
@MainActor
@Observable
final class SessionsViewModel {
    static let recentLimit = 5

    private(set) var sessions: [Session] = []
    private(set) var recentSessions: [Session] = []
    var error: UserFacingError?

    private let service: SessionService
    private var projectID: Project.ID?

    init(service: SessionService) {
        self.service = service
    }

    func session(id: Session.ID?) -> Session? {
        guard let id else { return nil }
        return sessions.first { $0.id == id } ?? recentSessions.first { $0.id == id }
    }

    /// Loads sessions for `projectID` (or clears them when `nil`) and
    /// refreshes the recent list, excluding sessions already listed above.
    func load(projectID: Project.ID?) async {
        self.projectID = projectID
        do {
            sessions = if let projectID { try await service.sessions(in: projectID) } else { [] }
            let recent = try await service.recentSessions(limit: Self.recentLimit + sessions.count)
            recentSessions = Array(recent.filter { $0.projectID != projectID }.prefix(Self.recentLimit))
        } catch {
            self.error = UserFacingError(error, title: "Could not load sessions", category: .persistence)
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

    func delete(_ id: Session.ID) async {
        do {
            try await service.deleteSession(id: id)
            await load(projectID: projectID)
        } catch {
            self.error = UserFacingError(error, title: "Could not delete session", category: .persistence)
        }
    }
}
