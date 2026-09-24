import Foundation
import GRDB

/// The SQLite database holding projects, sessions and transcripts.
///
/// GRDB is used only in `Infrastructure/Persistence`: features see their
/// repository protocols, never SQL (docs/data/persistence.md, ADR 0006).
struct AppDatabase: Sendable {
    /// `DatabasePool` (WAL) on disk, `DatabaseQueue` in memory for tests.
    let writer: any DatabaseWriter

    /// Wraps an open database and brings its schema up to date.
    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        do {
            try Self.migrator.migrate(writer)
        } catch {
            throw PersistenceError.migrationFailed(String(describing: error))
        }
    }

    /// An empty database for tests and previews.
    static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    /// Opens (or creates) the database file at `url`.
    ///
    /// When an existing file needs migrations, it is first copied next to
    /// itself (`<name>.backup-<last migration>`), keeping the two most recent
    /// copies, so a failed or faulty migration never loses the user's history.
    static func open(at url: URL) throws -> AppDatabase {
        let fileManager = FileManager.default
        let existed = fileManager.fileExists(atPath: url.path)
        let pool: DatabasePool
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            pool = try DatabasePool(path: url.path)
        } catch {
            throw PersistenceError.openFailed(String(describing: error))
        }
        if existed {
            try backUpIfMigrationsArePending(pool, databaseURL: url)
        }
        return try AppDatabase(pool)
    }

    /// `~/Library/Application Support/LocalOSXAi/LocalOSXAi.sqlite`.
    static func defaultURL() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        return support.appending(path: "LocalOSXAi", directoryHint: .isDirectory).appending(path: "LocalOSXAi.sqlite")
    }

    static let backupsKept = 2

    private static func backUpIfMigrationsArePending(_ pool: DatabasePool, databaseURL: URL) throws {
        do {
            let (isUpToDate, applied) = try pool.read { db in
                (try migrator.hasCompletedMigrations(db), try migrator.appliedIdentifiers(db))
            }
            guard !isUpToDate else { return }
            let suffix = applied.max() ?? "empty"
            let backupURL = databaseURL.deletingLastPathComponent()
                .appending(path: "\(databaseURL.lastPathComponent).backup-\(suffix)")
            try? FileManager.default.removeItem(at: backupURL)
            try pool.backup(to: DatabaseQueue(path: backupURL.path))
            try pruneBackups(of: databaseURL)
        } catch {
            throw PersistenceError.migrationFailed("Backup before migration failed: \(error)")
        }
    }

    private static func pruneBackups(of databaseURL: URL) throws {
        let directory = databaseURL.deletingLastPathComponent()
        let prefix = "\(databaseURL.lastPathComponent).backup-"
        let backups = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { modificationDate($0) > modificationDate($1) }
        for old in backups.dropFirst(backupsKept) {
            try FileManager.default.removeItem(at: old)
        }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    // MARK: Schema

    /// Forward-only migrations. Never edit one that has shipped: add a new
    /// one (docs/data/migrations.md).
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "project") { table in
                table.primaryKey("id", .text)
                table.column("name", .text).notNull()
                table.column("rootPath", .text).notNull().unique()
                table.column("createdAt", .double).notNull()
                table.column("lastOpenedAt", .double).notNull()
                table.column("includesClaudeInstructions", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "session") { table in
                table.primaryKey("id", .text)
                // Removing a project from the list deletes its sessions (the
                // UI says so before removing); files on disk are never touched.
                table.column("projectID", .text).notNull().references("project", onDelete: .cascade)
                table.column("title", .text).notNull()
                table.column("createdAt", .double).notNull()
                table.column("updatedAt", .double).notNull()
                table.column("modelProvider", .text)
                table.column("modelName", .text)
                table.column("toolCallCount", .integer).notNull().defaults(to: 0)
            }
            try db.create(index: "session_on_projectID_updatedAt", on: "session", columns: ["projectID", "updatedAt"])
            try db.create(table: "message") { table in
                table.primaryKey("id", .text)
                table.column("sessionID", .text).notNull().references("session", onDelete: .cascade)
                table.column("position", .integer).notNull()
                table.column("role", .text).notNull()
                table.column("text", .text).notNull()
                table.column("reasoning", .text).notNull()
                table.column("state", .text).notNull()
                table.column("createdAt", .double).notNull()
                // Tool calls are always read and written with their message:
                // a JSON column, not a table (ADR 0019).
                table.column("toolCalls", .text).notNull()
                table.uniqueKey(["sessionID", "position"])
            }
        }
        return migrator
    }
}

/// Failures of the local database.
enum PersistenceError: Error, Hashable, Sendable {
    case openFailed(String)
    case migrationFailed(String)
    case corruptData(String)
}

extension PersistenceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .openFailed: "The history database could not be opened."
        case .migrationFailed: "The history database could not be updated to this version of the app."
        case .corruptData: "Part of the saved history could not be read."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .openFailed, .migrationFailed:
            "Your previous data was left untouched. Projects and sessions opened now will not be saved "
                + "until the app is restarted successfully."
        case .corruptData:
            "Details were written to the system log. The database file was not modified."
        }
    }
}
