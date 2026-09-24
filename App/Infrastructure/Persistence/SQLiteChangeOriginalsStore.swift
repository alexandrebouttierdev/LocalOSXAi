import Foundation
import GRDB

/// Originals of files changed by the agent, stored in SQLite (`changeOriginal`).
struct SQLiteChangeOriginalsStore: ChangeOriginalsStore {
    let database: AppDatabase

    func allOriginals() async throws -> [TrackedOriginal] {
        try await database.writer.read { db in
            try ChangeOriginalRecord.fetchAll(db).map(\.original)
        }
    }

    func save(_ original: TrackedOriginal) async throws {
        let record = ChangeOriginalRecord(original)
        try await database.writer.write { db in try record.upsert(db) }
    }

    func delete(file: URL) async throws {
        try await database.writer.write { db in
            _ = try ChangeOriginalRecord.deleteOne(db, key: file.path)
        }
    }
}

/// Row of the `changeOriginal` table.
struct ChangeOriginalRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "changeOriginal"

    var path: String
    var projectRoot: String
    var existed: Bool
    var content: Data?

    init(_ original: TrackedOriginal) {
        path = original.file.path
        projectRoot = original.projectRoot.path
        existed = original.content != nil
        content = original.content
    }

    var original: TrackedOriginal {
        TrackedOriginal(file: URL(fileURLWithPath: path), projectRoot: URL(fileURLWithPath: projectRoot, isDirectory: true),
                        content: existed ? (content ?? Data()) : nil)
    }
}
