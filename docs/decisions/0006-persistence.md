# 0006: SQLite via GRDB behind repositories

**Status:** Accepted, implemented in Phase 5 (GRDB 7.9). Storage shape: [ADR 0019](0019-session-storage-shape.md)

## Context
Projects, sessions, messages, agent runs, tool calls and model configurations must persist.
The data is relational, append-heavy, and queried (recent sessions, later search). It must
be accessed from actors without data races, and the schema will evolve.

## Decision
Use SQLite through GRDB (`DatabasePool` in WAL mode, `DatabaseMigrator`, `Codable` records),
behind feature-owned repository protocols. Domain models remain plain `Sendable` structs.
Until Phase 5, `InMemory…Repository` actors implement the same protocols.

## Alternatives
- **SwiftData**: its model classes are not `Sendable`, it couples the domain to persistence
  macros, and its migrations are opaque. It fits poorly with the actor-based design.
- **Core Data**: the same coupling and concurrency friction, and more boilerplate.
- **Raw SQLite C API**: no dependency, but we would rebuild migrations, pooling and row
  mapping: a premature internal framework.
- **JSON files**: simple, but no querying, poor for append-heavy data, and hard to migrate
  safely.

## Consequences
- The project gains its first third-party dependency in Phase 5 (via SPM in `project.yml`).
- Migrations are explicit and testable (docs/data/migrations.md).
- Repositories stay the only place that knows about SQL.
