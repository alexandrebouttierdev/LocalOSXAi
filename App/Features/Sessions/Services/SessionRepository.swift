import Foundation

/// Storage port for sessions. Implemented in `Infrastructure/Persistence`.
protocol SessionRepository: Sendable {
    func sessions(forProject projectID: Project.ID) async throws -> [Session]
    func recentSessions(limit: Int) async throws -> [Session]
    func session(id: Session.ID) async throws -> Session?
    func save(_ session: Session) async throws
    func deleteSession(id: Session.ID) async throws
}
