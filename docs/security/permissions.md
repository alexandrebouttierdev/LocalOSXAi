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
  it (`ProjectBoundary`). Otherwise the tool fails with `ToolError.outsideProjectBoundary`.
- Resolving symlinks *before* the check prevents `ln -s / escape` tricks, including for files
  that do not exist yet: the deepest existing ancestor is resolved with `realpath(3)`.
- `~` is refused rather than expanded. A sibling folder sharing the root's name prefix
  (`App-secrets` next to `App`) is outside.
- Commands run with the project root as working directory. A command itself can still
  touch other paths, which is why commands go through the policy below.
- **Attachments are the exception, by design**: a file the user attaches to a message is read
  wherever it is, because the user chose it ([attachments](../ai/attachments.md)). The model
  cannot trigger such a read.

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
| `readOnly` on a secret-looking file (`.env*`, `*.pem`, `*.key`, `id_rsa*`, `.npmrc`, `credentials*`…) | Requires approval |
| `writesFiles` | Requires approval. The banner shows the **diff before anything is written**. Every change is then kept in the Changes tab, where it can be reverted. “Allow for Session” stops asking for that tool |
| `executesCommands` | Per command, by `CommandPolicy`: read-only and test commands run, others need approval, dangerous ones are blocked. See [command-execution.md](command-execution.md) |

Approvals are answered in the banner above the composer (⌘↩ to allow, ⌘⌫ to deny). Stopping
the run denies a pending request. Listing and searching never include hidden files, and
`search_text` never reads secret-looking files, so their contents cannot reach the model
without an explicit, approved `read_file`.

Each project can tune command approvals (Project Settings, ⌥⌘,): ask before every command, or
let listed prefixes run without asking. Blocked commands stay blocked
([ADR 0020](../decisions/0020-per-project-command-rules.md)). **Nothing is ever executed silently**:
every action appears in the transcript with its arguments and result.

## Secrets and credentials

- API keys of custom OpenAI-compatible servers are stored **only in the Keychain**
  (`KeychainProviderSecretStore`: `kSecClassGenericPassword`, service
  `dev.localosxai.app.provider.<id>`), never in SQLite, `UserDefaults`, logs, crash reports or
  the prompt. They are written when settings are applied and deleted with their server. A
  Keychain error message carries the operation and status, never the key.
- Provider URLs are not secrets and live in `UserDefaults` (`providers.v1`). Only `http`/`https`
  URLs with a host are accepted. ✅ A URL whose host is not this Mac (anything but `localhost`,
  `127.x.x.x`, `::1`) shows a warning in Settings: prompts, including file contents, leave the
  machine. The warning also says when an API key would be sent over plain HTTP.
- ✅ Besides the model servers, the app makes one request on its own: at launch, an anonymous
  `GET` of the latest release from `api.github.com`, carrying only the app's version
  ([ADR 0030](../decisions/0030-update-check.md)). Settings › General › Updates turns it off.
  The page it opens is always on the app's GitHub releases.
- Environment variables whose names contain `KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD` or
  `CREDENTIAL` are removed from the environment of every command. An allowlist is planned
  (not implemented yet).

## Logging and privacy

- `Logger(category:)` with categories `agent`, `provider`, `tools`, `terminal`, `git`,
  `persistence`, `ui`.
- Prompts, file contents, paths and command lines are logged only with the default `private`
  privacy level, which is redacted in Console unless a debugger is attached.
- API keys and tokens are **never** logged, not even as private.
- Error titles may be `.public`. Technical descriptions stay private.
