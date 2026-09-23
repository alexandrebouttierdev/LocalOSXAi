import Foundation

/// Process-lifetime session storage. Replaced by the SQLite store in Phase 5.
actor InMemorySessionRepository: SessionRepository {
    private var sessions: [Session.ID: Session]

    init(sessions: [Session] = []) {
        self.sessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    }

    func sessions(forProject projectID: Project.ID) -> [Session] {
        sessions.values.filter { $0.projectID == projectID }
    }

    func recentSessions(limit: Int) -> [Session] {
        Array(sessions.values.sorted { $0.updatedAt > $1.updatedAt }.prefix(max(limit, 0)))
    }

    func session(id: Session.ID) -> Session? {
        sessions[id]
    }

    func save(_ session: Session) {
        sessions[session.id] = session
    }

    func deleteSession(id: Session.ID) {
        sessions[id] = nil
    }
}
