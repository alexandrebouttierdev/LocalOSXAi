# Persistence

## Current state (Phase 1)

`InMemoryProjectRepository` and `InMemorySessionRepository` are actors that hold data for the
lifetime of the process. **Nothing survives a relaunch yet.** This is deliberate: persistence is
Phase 5, and the in-memory implementations let every feature be built and tested against the
final repository protocols now.

## Design

```
ViewModel ─▶ ProjectService ─▶ ProjectRepository (protocol, owned by the feature)
                                      ▲
               InMemoryProjectRepository (now) · SQLiteProjectRepository (Phase 5)
```

- Repository protocols live in the feature (`Features/<Name>/Services/`) and describe what the
  feature needs, not what the database can do.
- All repository methods are `async throws`. The in-memory versions never throw, but SQLite
  will, and callers must already handle it.
- Repositories return domain values, never database rows or managed objects.

## Decision: SQLite via GRDB (Phase 5)

See [ADR 0006](../decisions/0006-persistence.md). In short:

- **SQLite** is the right store for relational, append-heavy data (sessions → messages → tool
  calls) that must be queried (recent sessions, search).
- **GRDB** provides a thread-safe `DatabasePool` (WAL mode, concurrent reads), a first-class
  `DatabaseMigrator`, and `Codable` record mapping, without hiding SQL.
- SwiftData was rejected: its model objects are not `Sendable`, it ties the domain model to
  persistence macros, and its migrations are opaque.

The database file will live in `~/Library/Application Support/LocalOSXAi/LocalOSXAi.sqlite`.

## Rules

- Never put SQL or GRDB types in ViewModels or Views (checked by `make architecture`).
- Never store secrets in the database.
- Writes that must be atomic (e.g. finishing a run: messages + tool calls + run record) go
  through one repository method that uses one transaction.
