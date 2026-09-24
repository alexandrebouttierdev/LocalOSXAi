# 0019: Session storage shape — summaries for lists, tool calls as JSON

**Status:** Accepted (Phase 5)

## Context
Phase 5 moves projects and sessions to SQLite (ADR 0006). Until then, `Session` embedded its
whole transcript, and lists (sidebar, recent sessions) held full sessions. With persistent
history, a transcript can hold dozens of tool results of up to 16,000 characters each, and the
lists are reloaded after every run. Tool calls also had to find a place in the schema.

## Decision
- **Lists return summaries.** `SessionRepository.sessions(forProject:)` and
  `recentSessions(limit:)` return `Session` values whose `messages` is empty. Only
  `session(id:)` loads a transcript, when a session is opened. The sidebar's metadata
  ("4 tool calls") comes from a stored `toolCallCount`, updated by `SessionService` whenever
  the transcript is saved.
- **`save` replaces the transcript in one transaction.** It is only called with a full
  session (created, or loaded with `session(id:)`), never with a summary.
- **Tool calls are a JSON column of `message`**, not their own table. They are always read and
  written with their message, and nothing queries them on their own today.
- **Removing a project deletes its sessions**: explicitly through `SessionRepository`
  (so the in-memory store behaves the same), and by a foreign-key cascade in SQLite. The user
  confirms first. Files on disk are never touched.

## Alternatives
- **Separate `SessionSummary` type**: more type safety against saving a summary, but it would
  ripple through the sidebar, palette and workspace for one rule that a single service
  enforces. Can be introduced if more callers start saving sessions.
- **A `tool_call` table**: useful for audits across sessions (planned `CommandExecution`), but
  premature now. A later migration can extract it from the JSON column.
- **Paging messages** (`messages(in:before:limit:)`): not needed until transcripts get long
  enough to slow opening a session. The repository contract allows adding it.

## Consequences
- Code reading `Session.messages` from a list gets an empty array. Tests cover that lists are
  summaries and that opening a session loads the transcript.
- Searching inside tool outputs would need SQLite JSON functions or a later table.
