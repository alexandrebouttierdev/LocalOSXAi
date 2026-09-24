import Foundation

/// Storage port for sessions. Implemented in `Infrastructure/Persistence`.
///
/// Lists return summaries (`messages` empty) so the sidebar never loads
/// transcripts; `session(id:)` returns the full session.
protocol SessionRepository: Sendable {
    /// Summaries of a project's sessions.
    func sessions(forProject projectID: Project.ID) async throws -> [Session]
    /// Summaries of the most recently updated sessions, across projects.
    func recentSessions(limit: Int) async throws -> [Session]
    /// The full session, transcript included.
    func session(id: Session.ID) async throws -> Session?
    /// Saves a full session: its stored transcript is replaced by `session.messages`.
    /// Never pass a summary.
    func save(_ session: Session) async throws
    func deleteSession(id: Session.ID) async throws
    func deleteSessions(forProject projectID: Project.ID) async throws
}
