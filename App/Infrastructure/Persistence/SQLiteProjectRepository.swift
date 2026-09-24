import Foundation
import GRDB

/// Projects stored in SQLite.
struct SQLiteProjectRepository: ProjectRepository {
    let database: AppDatabase

    func allProjects() async throws -> [Project] {
        try await database.writer.read { db in
            try ProjectRecord.fetchAll(db).map { try $0.project() }
        }
    }

    func project(withRootURL url: URL) async throws -> Project? {
        try await database.writer.read { db in
            try ProjectRecord.filter(Column("rootPath") == url.path).fetchOne(db)?.project()
        }
    }

    func save(_ project: Project) async throws {
        let record = try ProjectRecord(project)
        try await database.writer.write { db in try record.upsert(db) }
    }

    /// Also deletes the project's sessions and transcripts (foreign-key cascade).
    func deleteProject(id: Project.ID) async throws {
        try await database.writer.write { db in
            _ = try ProjectRecord.deleteOne(db, key: id.uuidString)
        }
    }
}

/// Row of the `project` table. Dates are stored as seconds since the
/// reference date so they round-trip exactly.
struct ProjectRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "project"

    var id: String
    var name: String
    var rootPath: String
    var createdAt: Double
    var lastOpenedAt: Double
    var includesClaudeInstructions: Bool
    /// `CommandRules` as JSON; empty for the defaults (rows from before v2).
    var commandRules: String

    init(_ project: Project) throws {
        id = project.id.uuidString
        name = project.name
        rootPath = project.rootURL.path
        createdAt = project.createdAt.timeIntervalSinceReferenceDate
        lastOpenedAt = project.lastOpenedAt.timeIntervalSinceReferenceDate
        includesClaudeInstructions = project.includesClaudeInstructions
        if project.commandRules == CommandRules() {
            commandRules = ""
        } else {
            let data = try JSONEncoder().encode(project.commandRules)
            guard let json = String(bytes: data, encoding: .utf8) else { throw PersistenceError.corruptData("command rules") }
            commandRules = json
        }
    }

    func project() throws -> Project {
        guard let uuid = UUID(uuidString: id) else { throw PersistenceError.corruptData("project id \(id)") }
        var rules = CommandRules()
        if !commandRules.isEmpty {
            do {
                rules = try JSONDecoder().decode(CommandRules.self, from: Data(commandRules.utf8))
            } catch {
                throw PersistenceError.corruptData("command rules of project \(id)")
            }
        }
        return Project(
            id: uuid,
            name: name,
            rootURL: URL(fileURLWithPath: rootPath, isDirectory: true),
            createdAt: Date(timeIntervalSinceReferenceDate: createdAt),
            lastOpenedAt: Date(timeIntervalSinceReferenceDate: lastOpenedAt),
            includesClaudeInstructions: includesClaudeInstructions,
            commandRules: rules
        )
    }
}
