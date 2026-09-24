# Migrations

Implemented in `AppDatabase` (Phase 5). The shipped migrations are: `v1_initial`.

## Strategy

- **Forward-only, append-only migrations**, registered in order with GRDB's `DatabaseMigrator`:
  `v1_initial`, `v2_agent_runs`, …
- **Never edit a migration that has shipped.** Fix mistakes with a new migration.
- Each migration runs in a transaction. If one fails, the app keeps the previous database
  untouched and shows a recoverable error. It never deletes user data automatically.
- **Backup before migrating:** when pending migrations exist, copy the database file to
  `LocalOSXAi.sqlite.backup-<version>` first. Keep the last two backups.
- In `DEBUG`, `eraseDatabaseOnSchemaChange` may be used locally, never in release builds.

## Testing

Every migration gets a test that:

1. creates a database at the previous version with fixture data;
2. runs the migrator;
3. asserts the fixture data is intact and the new schema is usable.

## Non-database data

- `UserDefaults` keys are versioned by name (`appearance`, then `appearance.v2` if the meaning
  changes), and old keys are read once and converted.
- Keychain items carry a version in their `kSecAttrService` suffix if their format changes.
