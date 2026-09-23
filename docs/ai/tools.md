# Tools

## Separation of concerns

| Concern | Where | Status |
|---|---|---|
| Definition: name, description, parameter schema, effect | `AgentTool` properties | ✅ |
| Registry: unique, valid names, stable order | `ToolRegistry` | ✅ |
| Parsing: raw model JSON → arguments | `ToolArguments.parse` | ✅ |
| Validation: required, types, enums, unknown keys | `ToolParameterSchema.validate` | ✅ |
| Permission: allowed / approval / blocked | `ToolPermissionPolicy` (+ `CommandPolicy` for commands), applied by `ToolExecutor` | ✅ |
| Approval | `ToolApprover` (`AgentViewModel` + `ApprovalBanner`) | ✅ |
| Execution with timeout and output limit | `ToolExecutor` | ✅ |
| Presentation | `ToolCallRecord` + `ToolCallView` (Agent feature) | ✅ |

A tool never decides its own permission and never renders UI. The executor never contains
tool-specific logic.

## Contract

```swift
protocol AgentTool: Sendable {
    var name: String { get }                    // snake_case, [A-Za-z0-9_-]{1,64}
    var description: String { get }             // written for the model
    var parameters: ToolParameterSchema { get }
    var effect: ToolEffect { get }              // .readOnly / .writesFiles / .executesCommands
    func execute(arguments: ToolArguments, context: ToolContext) async throws -> ToolResult
}
```

`ToolResult` carries `status`, `output` (what the model reads) and `summary` (one line for
the UI).

## Validation decisions

- **Flat schemas only** (string, integer, number, boolean, string array). Small local models
  follow flat schemas much more reliably, and validation needs no JSON Schema library.
- **Unknown arguments are rejected.** Ignoring them would silently drop a misspelled optional
  parameter (`max_results` instead of `limit`) while the model believes it was applied.
- **Empty arguments (`""`) mean `{}`.** Several local models send an empty string for
  parameterless tools.
- **`null` means absent** for optional parameters.
- Validation errors are **returned to the model** as tool results, not thrown out of the run.

## Execution pipeline

```
LLMToolCall ─▶ registry.tool(named:)          unknownTool ─┐
            ─▶ ToolArguments.parse            malformed  ──┤
            ─▶ tool.parameters.validate       invalid    ──┼─▶ failed ToolResult to the model
            ─▶ policy.permission(tool, args)  blocked    ──┤
               └ approval? ─▶ ToolApprover     denied    ──┘
            ─▶ proposedChange (writes only)   cannot apply ─▶ failed ToolResult
            ─▶ policy.permission …            (the approval request carries the diff preview)
            ─▶ recorder.willModify (writes)
            ─▶ withTimeout(tool.execute)      timedOut / error ─▶ failed ToolResult
            ─▶ ToolResult (output truncated to a budget, e.g. 16K characters, with a marker)
```

## Catalog

| Tool | Effect | Status | Notes |
|---|---|---|---|
| `read_file` | readOnly | ✅ | `path`, `offset` (1-based), `limit` (default 400, max 2000). Numbered lines. Refuses folders, binaries (NUL byte), non-UTF-8 files and files over 2 MB |
| `list_directory` | readOnly | ✅ | `path`, `recursive`. At most 500 entries |
| `search_files` | readOnly | ✅ | Glob `pattern` (`*`, `**`, `?`, `{a,b}`; a pattern without `/` matches file names), `path`. At most 200 results |
| `search_text` | readOnly | ✅ | `query`, `is_regex`, `case_sensitive`, `path`, `file_pattern`. At most 200 matches, lines capped at 300 characters, files over 1 MB skipped |
| `edit_file` | writesFiles | ✅ | Exact `old_string` → `new_string`. Fails if the string is not found or not unique, unless `replace_all` is set |
| `write_file` | writesFiles | ✅ | Creates parent folders, atomic write |
| `run_command` | executesCommands | ✅ | `command`. zsh in the project folder, 120 s limit; allowed / approval / blocked by `CommandPolicy` |
| `git_status`, `git_diff`, `git_log` | readOnly | ✅ | Through `GitService` (`git_diff`: `path`, `staged`; `git_log`: `limit` 1–50) |

Listing and searching skip hidden files and folders, and a fixed set of folders that are never
useful to an agent (`.git`, `.build`, `DerivedData`, `node_modules`, `Pods`, `dist`, `.venv`, `target`…).
The root `.gitignore` is applied too (`name`, `*.ext`, `dir/`, `/anchored`, `**`, `!negation`).
Nested `.gitignore` files are not read yet.
`search_text` never searches files that look like secrets (see the security docs).

Write tools describe themselves for the approval banner (“Edit notes.md”, “Write a.txt (12 lines)”)
and implement `proposedChange`: the change is computed **without writing**, so the executor can
show its diff before approval and fail an edit that cannot apply without bothering the user.
Around each write, the executor asks the `FileChangeRecording` (the `ChangeTracker`) to keep the
original content, for review and revert in the Changes tab ([ADR 0018](../decisions/0018-change-review-before-and-after.md)).

## Boundary

All path arguments are resolved against `ToolContext.projectRoot`, standardized, and
**symlink-resolved before the check**. Anything outside the root throws
`ToolError.outsideProjectBoundary`. See [security/permissions.md](../security/permissions.md).
