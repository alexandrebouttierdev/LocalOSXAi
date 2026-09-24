import Foundation

/// Process-lifetime session storage, for simulated mode and tests. Mirrors
/// the SQLite store's contract: lists return summaries.
actor InMemorySessionRepository: SessionRepository {
    private var sessions: [Session.ID: Session]

    init(sessions: [Session] = []) {
        self.sessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    }

    func sessions(forProject projectID: Project.ID) -> [Session] {
        sessions.values.filter { $0.projectID == projectID }.map(\.summary)
    }

    func recentSessions(limit: Int) -> [Session] {
        Array(sessions.values.sorted { $0.updatedAt > $1.updatedAt }.prefix(max(limit, 0))).map(\.summary)
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

    func deleteSessions(forProject projectID: Project.ID) {
        sessions = sessions.filter { $0.value.projectID != projectID }
    }
}
