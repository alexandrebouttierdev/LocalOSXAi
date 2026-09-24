# Errors

## Taxonomy

| Error | Layer | Examples | Status |
|---|---|---|---|
| `ProviderError` | Core / providers | unreachable, HTTP status, invalid response, model not found, unsupported capability, timed out | ✅ |
| `ToolError` | Core / tools | duplicate/invalid/unknown tool, malformed/missing/invalid/unexpected argument, permission denied, outside project, execution failed, timed out | ✅ |
| `ProjectError` | Projects | folder not found, not a folder | ✅ |
| `AgentError` | Agent | no model selected, model unavailable, context overflow, too many invalid tool calls, empty response, output limit reached | ✅ |
| `TerminalError` | Terminal | launch failed (timeouts are reported in `CommandExit`) | ✅ |
| `GitError` | Git | not a repository, command failed | ✅ |
| `PersistenceError` | Persistence | open failed, migration failed, corrupt data | ✅ |

Typed errors exist where the caller can *act differently* on the case. Where it cannot, a
descriptive error is enough. We do not create error types for the sake of it.

## Presentation

- Every typed error conforms to `LocalizedError`: `errorDescription` is a sentence a user
  understands, and `recoverySuggestion` says what to do.
- ViewModels convert errors with `UserFacingError(error, title:, category:)`. This logs the
  **technical** description (`String(describing:)`) to the relevant log category, and exposes
  only the user-facing text.
- Unknown errors show a generic message (“Details were written to the system log”). Internal
  details never leak into the UI.
- Run failures appear inline in the transcript (an error entry). Other failures use a
  single workspace alert (`WorkspaceViewModel.currentError`).

## Not hiding errors

- `try?` is allowed only where failure is expected and harmless, with a comment.
- Validation failures during a run are not hidden. They are shown on the tool call and sent
  back to the model.
