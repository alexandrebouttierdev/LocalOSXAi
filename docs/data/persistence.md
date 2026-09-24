# Persistence

## Current state (Phase 5)

Projects, sessions and transcripts are stored in SQLite through GRDB:
`SQLiteProjectRepository` and `SQLiteSessionRepository` over `AppDatabase` (a `DatabasePool` in
WAL mode). `InMemoryProjectRepository` and `InMemorySessionRepository` remain for simulated
mode and tests, with the same contract.

If the database cannot be opened or migrated at launch, the app runs on the in-memory
repositories and says so in an alert (“History is not being saved”). The file is left untouched
so the next launch can try again.

## Design

```
ViewModel ─▶ ProjectService ─▶ ProjectRepository (protocol, owned by the feature)
                                      ▲
               SQLiteProjectRepository (app) · InMemoryProjectRepository (simulated mode, tests)
```

- Repository protocols live in the feature (`Features/<Name>/Services/`) and describe what the
  feature needs, not what the database can do.
- All repository methods are `async throws`. The in-memory versions never throw, but SQLite
  will, and callers must already handle it.
- Repositories return domain values, never database rows or managed objects.

## Schema (`v1_initial`, `v2_…`)

| Table | Columns | Notes |
|---|---|---|
| `project` | `id`, `name`, `rootPath` (unique), `createdAt`, `lastOpenedAt`, `includesClaudeInstructions` | |
| `session` | `id`, `projectID` → `project` (cascade), `title`, `createdAt`, `updatedAt`, `modelProvider`, `modelName`, `toolCallCount` | Index on (`projectID`, `updatedAt`) |
| `message` | `id`, `sessionID` → `session` (cascade), `position`, `role`, `text`, `reasoning`, `state`, `createdAt`, `toolCalls` (JSON) | Unique (`sessionID`, `position`) |
| `project.commandRules` (v2) | JSON of `CommandRules`, empty for the defaults | |
| `modelSettings` (v2) | `provider`, `name` (primary key), `temperature`, `reasoning`, `contextTokens` | Defaults are not stored |
| `changeOriginal` (v2) | `path` (primary key), `projectRoot`, `existed`, `content` (blob) | Removed when a change is accepted or reverted |

Dates are stored as seconds since the reference date (`Double`), so they round-trip exactly.
Session lists read only the `session` table; a transcript is read when a session is opened
([ADR 0019](../decisions/0019-session-storage-shape.md)).

## Decision: SQLite via GRDB

See [ADR 0006](../decisions/0006-persistence.md). In short:

- **SQLite** is the right store for relational, append-heavy data (sessions → messages → tool
  calls) that must be queried (recent sessions, search).
- **GRDB** provides a thread-safe `DatabasePool` (WAL mode, concurrent reads), a first-class
  `DatabaseMigrator`, and `Codable` record mapping, without hiding SQL.
- SwiftData was rejected: its model objects are not `Sendable`, it ties the domain model to
  persistence macros, and its migrations are opaque.

The database file lives in `~/Library/Application Support/LocalOSXAi/LocalOSXAi.sqlite`.

## Rules

- GRDB and SQL stay in `App/Infrastructure/Persistence` (checked by `make architecture`).
- Never store secrets in the database.
- Writes that must be atomic (e.g. finishing a run: messages + tool calls + run record) go
  through one repository method that uses one transaction.
