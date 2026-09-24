import Foundation
import Testing
@testable import LocalOSXAi

@Suite("SQLite repositories")
struct SQLiteRepositoryTests {
    private let database: AppDatabase
    private let projects: SQLiteProjectRepository
    private let sessions: SQLiteSessionRepository

    init() throws {
        database = try AppDatabase.inMemory()
        projects = SQLiteProjectRepository(database: database)
        sessions = SQLiteSessionRepository(database: database)
    }

    private func project(_ name: String = "Demo") -> Project {
        Project(id: UUID(), name: name, rootURL: URL(fileURLWithPath: "/tmp/\(name)", isDirectory: true),
                createdAt: Date(timeIntervalSinceReferenceDate: 1.25), lastOpenedAt: Date(timeIntervalSinceReferenceDate: 2.5))
    }

    private func transcript() -> [AgentMessage] {
        let call = ToolCallRecord(id: "c1", name: "read_file", argumentsJSON: #"{"path":"a.swift"}"#, status: .succeeded,
                                  summary: "Read 3 lines", output: "a\nb\nc")
        return [
            AgentMessage(role: .user, text: "Read a.swift", createdAt: Date(timeIntervalSinceReferenceDate: 10.123_456)),
            {
                var answer = AgentMessage(role: .assistant, text: "It has 3 lines.", reasoning: "Let me look.", toolCalls: [call],
                                          createdAt: Date(timeIntervalSinceReferenceDate: 11))
                answer.finishedAt = Date(timeIntervalSinceReferenceDate: 13.25)
                answer.outputTokens = 42
                return answer
            }(),
            AgentMessage(role: .error, text: "Model crashed", state: .failed, createdAt: Date(timeIntervalSinceReferenceDate: 12))
        ]
    }

    @Test("projects round-trip exactly, including the CLAUDE.md opt-in")
    func projectRoundTrip() async throws {
        var demo = project()
        demo.includesClaudeInstructions = true
        try await projects.save(demo)

        #expect(try await projects.allProjects() == [demo])
        #expect(try await projects.project(withRootURL: demo.rootURL) == demo)
        #expect(try await projects.project(withRootURL: URL(fileURLWithPath: "/elsewhere")) == nil)
    }

    @Test("saving an existing project updates it")
    func projectUpdate() async throws {
        var demo = project()
        try await projects.save(demo)
        demo.lastOpenedAt = Date(timeIntervalSinceReferenceDate: 99)
        try await projects.save(demo)
        #expect(try await projects.allProjects() == [demo])
    }

    @Test("a full session round-trips: transcript, tool calls, model and dates")
    func sessionRoundTrip() async throws {
        let demo = project()
        try await projects.save(demo)
        let session = Session(id: UUID(), projectID: demo.id, title: "Read a file",
                              createdAt: Date(timeIntervalSinceReferenceDate: 5), updatedAt: Date(timeIntervalSinceReferenceDate: 6),
                              model: AIModel.ID(provider: "ollama", name: "gemma4:26b"), messages: transcript(), toolCallCount: 1)
        try await sessions.save(session)

        #expect(try await sessions.session(id: session.id) == session)
    }

    @Test("lists return summaries, most recent first, without transcripts")
    func summaries() async throws {
        let demo = project()
        let other = project("Other")
        try await projects.save(demo)
        try await projects.save(other)
        let older = Session(id: UUID(), projectID: demo.id, title: "Old", createdAt: .distantPast,
                            updatedAt: Date(timeIntervalSinceReferenceDate: 1), model: nil, messages: transcript(), toolCallCount: 1)
        let newer = Session(id: UUID(), projectID: other.id, title: "New", createdAt: .distantPast,
                            updatedAt: Date(timeIntervalSinceReferenceDate: 2), model: nil, messages: [])
        try await sessions.save(older)
        try await sessions.save(newer)

        let listed = try await sessions.sessions(forProject: demo.id)
        #expect(listed == [older.summary])
        #expect(listed.first?.toolCallCount == 1)
        #expect(try await sessions.recentSessions(limit: 5).map(\.title) == ["New", "Old"])
        #expect(try await sessions.recentSessions(limit: 1).map(\.title) == ["New"])
    }

    @Test("saving replaces the stored transcript")
    func replaceTranscript() async throws {
        let demo = project()
        try await projects.save(demo)
        var session = Session(id: UUID(), projectID: demo.id, title: "T", createdAt: .distantPast, updatedAt: .distantPast,
                              model: nil, messages: transcript())
        try await sessions.save(session)
        session.messages = Array(session.messages.prefix(1))
        try await sessions.save(session)

        #expect(try await sessions.session(id: session.id)?.messages == session.messages)
    }

    @Test("deleting a project deletes its sessions and transcripts")
    func cascade() async throws {
        let demo = project()
        try await projects.save(demo)
        let session = Session(id: UUID(), projectID: demo.id, title: "T", createdAt: .distantPast, updatedAt: .distantPast,
                              model: nil, messages: transcript())
        try await sessions.save(session)

        try await projects.deleteProject(id: demo.id)

        #expect(try await projects.allProjects().isEmpty)
        #expect(try await sessions.session(id: session.id) == nil)
        #expect(try await sessions.recentSessions(limit: 10).isEmpty)
    }

    @Test("sessions can be deleted one by one or per project")
    func deleteSessions() async throws {
        let demo = project()
        try await projects.save(demo)
        let first = Session(id: UUID(), projectID: demo.id, title: "1", createdAt: .distantPast, updatedAt: .distantPast,
                            model: nil, messages: [])
        let second = Session(id: UUID(), projectID: demo.id, title: "2", createdAt: .distantPast, updatedAt: .distantPast,
                             model: nil, messages: [])
        try await sessions.save(first)
        try await sessions.save(second)

        try await sessions.deleteSession(id: first.id)
        #expect(try await sessions.sessions(forProject: demo.id).map(\.id) == [second.id])
        try await sessions.deleteSessions(forProject: demo.id)
        #expect(try await sessions.sessions(forProject: demo.id).isEmpty)
    }

    @Test("a session cannot reference a missing project")
    func foreignKey() async {
        let orphan = Session(id: UUID(), projectID: UUID(), title: "T", createdAt: .distantPast, updatedAt: .distantPast,
                             model: nil, messages: [])
        await #expect(throws: (any Error).self) { try await sessions.save(orphan) }
    }
}

@Suite("SQLite settings and change originals")
struct SQLiteSettingsTests {
    @Test("project command rules round-trip; the defaults are stored empty")
    func commandRules() async throws {
        let projects = SQLiteProjectRepository(database: try AppDatabase.inMemory())
        var project = Project(id: UUID(), name: "Demo", rootURL: URL(fileURLWithPath: "/tmp/Demo", isDirectory: true),
                              createdAt: .distantPast, lastOpenedAt: .distantPast)
        try await projects.save(project)
        #expect(try await projects.allProjects().first?.commandRules == CommandRules())

        project.commandRules = CommandRules(mode: .askForEverything, allowedPrefixes: ["npm install"])
        try await projects.save(project)
        #expect(try await projects.allProjects().first?.commandRules == project.commandRules)
    }

    @Test("model settings are saved per model, and saving the defaults removes them")
    func modelSettings() async throws {
        let repository = SQLiteModelSettingsRepository(database: try AppDatabase.inMemory())
        let gemma = AIModel.ID(provider: "ollama", name: "gemma4:26b")
        let qwen = AIModel.ID(provider: "lmstudio", name: "qwen3-8b")
        let custom = ModelSettings(temperature: 0.2, reasoning: .high, contextTokens: 32_768)

        try await repository.save(custom, for: gemma)
        try await repository.save(ModelSettings(temperature: 1.1), for: qwen)
        #expect(try await repository.allSettings() == [gemma: custom, qwen: ModelSettings(temperature: 1.1)])

        try await repository.save(.defaults, for: gemma)
        #expect(try await repository.allSettings().keys.sorted { $0.name < $1.name } == [qwen])
    }

    @Test("change originals round-trip, including created files and empty files")
    func changeOriginals() async throws {
        let store = SQLiteChangeOriginalsStore(database: try AppDatabase.inMemory())
        let root = URL(fileURLWithPath: "/tmp/Demo", isDirectory: true)
        let edited = TrackedOriginal(file: root.appending(path: "a.txt"), projectRoot: root, content: Data("before".utf8))
        let created = TrackedOriginal(file: root.appending(path: "new.txt"), projectRoot: root, content: nil)
        let emptied = TrackedOriginal(file: root.appending(path: "empty.txt"), projectRoot: root, content: Data())
        for original in [edited, created, emptied] { try await store.save(original) }

        let restored = try await store.allOriginals()
        #expect(Set(restored.map(\.file.path)) == Set([edited, created, emptied].map(\.file.path)))
        #expect(restored.first { $0.file.lastPathComponent == "a.txt" }?.content == Data("before".utf8))
        #expect(restored.first { $0.file.lastPathComponent == "new.txt" }?.content == nil)
        #expect(restored.first { $0.file.lastPathComponent == "empty.txt" }?.content == Data())

        try await store.delete(file: edited.file)
        #expect(try await store.allOriginals().count == 2)
    }

    @Test("migrating v1 to v2 keeps projects, sessions and transcripts")
    func migrationFromV1() async throws {
        let database = try AppDatabase.inMemory(upTo: "v1_initial")
        let projectID = UUID().uuidString
        let sessionID = UUID().uuidString
        try database.executeForTesting("""
            INSERT INTO project (id, name, rootPath, createdAt, lastOpenedAt, includesClaudeInstructions)
            VALUES ('\(projectID)', 'Demo', '/tmp/Demo', 1, 2, 1);
            INSERT INTO session (id, projectID, title, createdAt, updatedAt, modelProvider, modelName, toolCallCount)
            VALUES ('\(sessionID)', '\(projectID)', 'Old session', 3, 4, 'ollama', 'gemma4:26b', 1);
            INSERT INTO message (id, sessionID, position, role, text, reasoning, state, createdAt, toolCalls)
            VALUES ('\(UUID().uuidString)', '\(sessionID)', 0, 'user', 'Hello', '', 'complete', 5, '[]');
            """)

        try database.migrate()

        let project = try #require(try await SQLiteProjectRepository(database: database).allProjects().first)
        #expect(project.name == "Demo")
        #expect(project.includesClaudeInstructions)
        #expect(project.commandRules == CommandRules())
        let session = try await SQLiteSessionRepository(database: database).session(id: try #require(UUID(uuidString: sessionID)))
        #expect(session?.title == "Old session")
        #expect(session?.messages.map(\.text) == ["Hello"])
        #expect(try await SQLiteModelSettingsRepository(database: database).allSettings().isEmpty)
    }
}

@Suite("AppDatabase")
struct AppDatabaseTests {
    @Test("a new file is created with the current schema, and reopening needs no backup")
    func createAndReopen() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let url = temp.url.appending(path: "Nested/LocalOSXAi.sqlite")

        let database = try AppDatabase.open(at: url)
        try await SQLiteProjectRepository(database: database).save(
            Project(id: UUID(), name: "Demo", rootURL: URL(fileURLWithPath: "/tmp/Demo"), createdAt: .now, lastOpenedAt: .now)
        )
        let reopened = try AppDatabase.open(at: url)

        #expect(try await SQLiteProjectRepository(database: reopened).allProjects().map(\.name) == ["Demo"])
        #expect(try backups(in: url.deletingLastPathComponent()).isEmpty)
    }

    @Test("an existing database is backed up before migrating, keeping the two latest backups")
    func backupBeforeMigrating() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let url = temp.url.appending(path: "LocalOSXAi.sqlite")
        for (index, name) in ["LocalOSXAi.sqlite.backup-a", "LocalOSXAi.sqlite.backup-b"].enumerated() {
            let file = try temp.makeFile(name)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: Double(index) - 100)],
                                                  ofItemAtPath: file.path)
        }
        // An existing file without our schema: every migration is pending.
        try temp.makeFile("LocalOSXAi.sqlite")

        _ = try AppDatabase.open(at: url)

        #expect(try backups(in: temp.url) == ["LocalOSXAi.sqlite.backup-b", "LocalOSXAi.sqlite.backup-empty"])
    }

    @Test("an unreadable file fails with a persistence error instead of being replaced")
    func unreadableFile() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let url = try temp.makeFile("LocalOSXAi.sqlite", contents: String(repeating: "not a database ", count: 200))

        #expect(throws: PersistenceError.self) { try AppDatabase.open(at: url) }
        #expect(try String(contentsOf: url, encoding: .utf8).hasPrefix("not a database"))
    }

    private func backups(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.contains(".backup-") }.sorted()
    }
}
