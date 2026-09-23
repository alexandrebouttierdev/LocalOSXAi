# Security and permissions

The application reads and writes files and runs commands **on behalf of a language model**.
The threat model is simple: **model output is untrusted input**, whether through mistakes,
hallucinations or prompt injection from files the model reads.

## Sandbox

The app is **not sandboxed** and uses the Hardened Runtime ([ADR 0009](../decisions/0009-no-app-sandbox.md)).
A coding agent must run the user's toolchain (`git`, `npm`, `swift`, `make`…). Processes
launched from a sandboxed app inherit its sandbox and fail on normal development tasks. The
protections below therefore replace the sandbox with explicit, auditable application rules.

## Project boundary

- A project root is standardized and symlink-resolved when the project opens (`ProjectService.normalized`).
- Every path argument is resolved against the root, symlink-resolved, and must remain inside
  it. Otherwise the tool fails with `ToolError.outsideProjectBoundary`.
- Resolving symlinks *before* the check prevents `ln -s / escape` tricks.
- Commands run with the project root as working directory. A command itself can still
  touch other paths, which is why commands go through the policy below.

## Permission model

Each tool declares its `ToolEffect`. The policy maps effect (and, for commands, the command
line) to a decision:

| Decision | Behavior |
|---|---|
| **Allowed** | Runs immediately. The call is still shown in the transcript |
| **Requires approval** | The run pauses. The user sees the exact action and approves once, approves for the session, or denies |
| **Blocked** | Refused, and the model receives a `denied` result explaining why |

Defaults:

| Effect | Default |
|---|---|
| `readOnly` (inside project) | Allowed |
| `writesFiles` | Requires approval, with the diff shown (Phase 4 review UI). Configurable to “allowed” per project |
| `executesCommands` | Per command: see [command-execution.md](command-execution.md) |

The policy is configurable per project and persisted (Phase 5). **Nothing is ever executed
silently**: every action appears in the transcript with its arguments and result.

## Secrets and credentials

- API keys (for remote OpenAI-compatible servers) are stored **only in the Keychain**
  (`kSecClassGenericPassword`, service `dev.localosxai.app.provider.<id>`), never in SQLite,
  `UserDefaults`, logs, crash reports or the prompt.
- Provider URLs are not secrets and live in `UserDefaults` (`providers.v1`). Only `http`/`https`
  URLs with a host are accepted. A warning for non-local URLs (prompts, including file
  contents, would leave the machine) is planned with remote-server support.
- Environment variables that look like secrets (`*_KEY`, `*_TOKEN`, `*_SECRET`, `PASSWORD`)
  are stripped from the command environment unless the user allowlists them (Phase 4).

## Logging and privacy

- `Logger(category:)` with categories `agent`, `provider`, `tools`, `terminal`, `git`,
  `persistence`, `ui`.
- Prompts, file contents, paths and command lines are logged only with the default `private`
  privacy level, which is redacted in Console unless a debugger is attached.
- API keys and tokens are **never** logged, not even as private.
- Error titles may be `.public`. Technical descriptions stay private.
