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
| Projects, sessions, messages, tool calls | SQLite (`AppDatabase`) | 5 ✅ |
| Agent limits (steps per run, tool timeout) | `UserDefaults` key `agent.v1`, JSON | 5 ✅ |
| Per-model settings (temperature, reasoning, context) | SQLite `modelSettings` | ✅ |
| Per-project settings (`CLAUDE.md` opt-in, command rules) | SQLite `project` | ✅ |
| Originals of files changed by the agent (Changes tab) | SQLite `changeOriginal` | ✅ |
| UI preferences (appearance, panel visibility) | `UserDefaults` | 1 |
| Provider settings (endpoints, enablement, Ollama context, idle timeout) | `UserDefaults` key `providers.v1`, JSON | 2 ✅ |
| API keys for remote OpenAI-compatible servers | Keychain | 2+ |

See [models.md](models.md), [persistence.md](persistence.md) and [migrations.md](migrations.md).
