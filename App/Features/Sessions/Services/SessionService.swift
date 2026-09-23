import Foundation

/// Use cases for creating, listing and updating sessions.
struct SessionService: Sendable {
    /// Maximum length of a title derived from the first prompt.
    static let maxDerivedTitleLength = 60

    private let repository: any SessionRepository
    private let now: @Sendable () -> Date

    init(repository: any SessionRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    func createSession(in projectID: Project.ID, model: AIModel.ID?) async throws -> Session {
        let timestamp = now()
        let session = Session(
            id: UUID(),
            projectID: projectID,
            title: Session.defaultTitle,
            createdAt: timestamp,
            updatedAt: timestamp,
            model: model,
            messages: []
        )
        try await repository.save(session)
        return session
    }

    /// Sessions of a project, most recently updated first.
    func sessions(in projectID: Project.ID) async throws -> [Session] {
        try await repository.sessions(forProject: projectID).sorted { $0.updatedAt > $1.updatedAt }
    }

    func recentSessions(limit: Int) async throws -> [Session] {
        try await repository.recentSessions(limit: limit)
    }

    func session(id: Session.ID) async throws -> Session? {
        try await repository.session(id: id)
    }

    /// Stores a new transcript and, while the session still has the default
    /// title, names it after its first user message.
    @discardableResult
    func updateMessages(_ messages: [AgentMessage], model: AIModel.ID?, in sessionID: Session.ID) async throws -> Session? {
        guard var session = try await repository.session(id: sessionID) else { return nil }
        session.messages = messages
        session.model = model ?? session.model
        session.updatedAt = now()
        if session.title == Session.defaultTitle, let title = Self.derivedTitle(from: messages) {
            session.title = title
        }
        try await repository.save(session)
        return session
    }

    func deleteSession(id: Session.ID) async throws {
        try await repository.deleteSession(id: id)
    }

    /// First line of the first user message, truncated on a word boundary.
    static func derivedTitle(from messages: [AgentMessage]) -> String? {
        guard let prompt = messages.first(where: { $0.role == .user })?.text else { return nil }
        let firstLine = prompt.split(whereSeparator: \.isNewline).first.map(String.init) ?? prompt
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count > maxDerivedTitleLength else { return trimmed }

        let prefix = trimmed.prefix(maxDerivedTitleLength)
        let cut = prefix.lastIndex(of: " ").map { prefix[..<$0] } ?? prefix
        return cut.trimmingCharacters(in: .whitespaces) + "…"
    }
}
