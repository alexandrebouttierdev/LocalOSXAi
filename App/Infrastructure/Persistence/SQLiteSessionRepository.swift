import Foundation
import GRDB

/// Sessions and their transcripts stored in SQLite.
///
/// Lists read only the `session` table (summaries); a transcript is read
/// when one session is opened. Saving replaces the transcript in one
/// transaction, so a session is never stored half-updated.
struct SQLiteSessionRepository: SessionRepository {
    let database: AppDatabase

    func sessions(forProject projectID: Project.ID) async throws -> [Session] {
        try await database.writer.read { db in
            try SessionRecord
                .filter(Column("projectID") == projectID.uuidString)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
                .map { try $0.session(messages: []) }
        }
    }

    func recentSessions(limit: Int) async throws -> [Session] {
        try await database.writer.read { db in
            try SessionRecord
                .order(Column("updatedAt").desc)
                .limit(max(limit, 0))
                .fetchAll(db)
                .map { try $0.session(messages: []) }
        }
    }

    func session(id: Session.ID) async throws -> Session? {
        try await database.writer.read { db in
            guard let record = try SessionRecord.fetchOne(db, key: id.uuidString) else { return nil }
            let messages = try MessageRecord
                .filter(Column("sessionID") == id.uuidString)
                .order(Column("position"))
                .fetchAll(db)
                .map { try $0.message() }
            return try record.session(messages: messages)
        }
    }

    func save(_ session: Session) async throws {
        let record = SessionRecord(session)
        let messages = try session.messages.enumerated().map { try MessageRecord($1, sessionID: session.id, position: $0) }
        try await database.writer.write { db in
            try record.upsert(db)
            try MessageRecord.filter(Column("sessionID") == record.id).deleteAll(db)
            for message in messages { try message.insert(db) }
        }
    }

    func deleteSession(id: Session.ID) async throws {
        try await database.writer.write { db in
            _ = try SessionRecord.deleteOne(db, key: id.uuidString)
        }
    }

    func deleteSessions(forProject projectID: Project.ID) async throws {
        try await database.writer.write { db in
            _ = try SessionRecord.filter(Column("projectID") == projectID.uuidString).deleteAll(db)
        }
    }
}

/// Row of the `session` table.
struct SessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "session"

    var id: String
    var projectID: String
    var title: String
    var createdAt: Double
    var updatedAt: Double
    var modelProvider: String?
    var modelName: String?
    var toolCallCount: Int

    init(_ session: Session) {
        id = session.id.uuidString
        projectID = session.projectID.uuidString
        title = session.title
        createdAt = session.createdAt.timeIntervalSinceReferenceDate
        updatedAt = session.updatedAt.timeIntervalSinceReferenceDate
        modelProvider = session.model?.provider.rawValue
        modelName = session.model?.name
        toolCallCount = session.toolCallCount
    }

    func session(messages: [AgentMessage]) throws -> Session {
        guard let uuid = UUID(uuidString: id), let project = UUID(uuidString: projectID) else {
            throw PersistenceError.corruptData("session id \(id)")
        }
        let model = modelProvider.flatMap { provider in
            modelName.map { AIModel.ID(provider: ProviderID(rawValue: provider), name: $0) }
        }
        return Session(
            id: uuid,
            projectID: project,
            title: title,
            createdAt: Date(timeIntervalSinceReferenceDate: createdAt),
            updatedAt: Date(timeIntervalSinceReferenceDate: updatedAt),
            model: model,
            messages: messages,
            toolCallCount: toolCallCount
        )
    }
}

/// Row of the `message` table. Tool calls are a JSON array (ADR 0019).
struct MessageRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "message"

    var id: String
    var sessionID: String
    var position: Int
    var role: String
    var text: String
    var reasoning: String
    var state: String
    var createdAt: Double
    var toolCalls: String
    var finishedAt: Double?
    var outputTokens: Int?

    init(_ message: AgentMessage, sessionID: Session.ID, position: Int) throws {
        id = message.id.uuidString
        self.sessionID = sessionID.uuidString
        self.position = position
        role = message.role.rawValue
        text = message.text
        reasoning = message.reasoning
        state = message.state.rawValue
        createdAt = message.createdAt.timeIntervalSinceReferenceDate
        finishedAt = message.finishedAt?.timeIntervalSinceReferenceDate
        outputTokens = message.outputTokens
        guard let json = String(bytes: try JSONEncoder().encode(message.toolCalls), encoding: .utf8) else {
            throw PersistenceError.corruptData("tool calls of message \(id)")
        }
        toolCalls = json
    }

    func message() throws -> AgentMessage {
        guard let uuid = UUID(uuidString: id),
              let role = AgentMessage.Role(rawValue: role),
              let state = AgentMessage.State(rawValue: state) else {
            throw PersistenceError.corruptData("message \(id)")
        }
        let calls: [ToolCallRecord]
        do {
            calls = try JSONDecoder().decode([ToolCallRecord].self, from: Data(toolCalls.utf8))
        } catch {
            throw PersistenceError.corruptData("tool calls of message \(id)")
        }
        var message = AgentMessage(id: uuid, role: role, text: text, reasoning: reasoning, toolCalls: calls,
                                   state: state, createdAt: Date(timeIntervalSinceReferenceDate: createdAt))
        message.finishedAt = finishedAt.map(Date.init(timeIntervalSinceReferenceDate:))
        message.outputTokens = outputTokens
        return message
    }
}
