# Data overview

## Principles

1. **Value types everywhere.** Domain models are `Sendable` structs, so they cross actors safely.
2. **Storage is a port.** Features declare repository protocols, and infrastructure implements
   them. ViewModels never see SQL or files.
3. **Two conversation models.** `AgentMessage` is what the user sees and what we persist.
   `LLMMessage` is what a provider receives. The context manager (Phase 3) derives the
   second from the first, which lets compaction and truncation happen without rewriting
   history.
4. **Secrets are not data.** API keys live in the Keychain, never in the database or
   `UserDefaults` (see [security](../security/permissions.md)).

## Where data lives

| Data | Store | Phase |
|---|---|---|
| Projects, sessions, messages, agent runs, tool calls | In memory → SQLite | 1 → 5 |
| Model configuration per model (context size, temperature) | SQLite | 5 |
| UI preferences (appearance, panel visibility) | `UserDefaults` | 1 |
| Provider endpoints | `UserDefaults` (not secret) | 2 |
| API keys for remote OpenAI-compatible servers | Keychain | 2+ |

See [models.md](models.md), [persistence.md](persistence.md) and [migrations.md](migrations.md).
