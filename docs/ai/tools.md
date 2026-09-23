# Tools

## Separation of concerns

| Concern | Where | Status |
|---|---|---|
| Definition: name, description, parameter schema, effect | `AgentTool` properties | ✅ |
| Registry: unique, valid names, stable order | `ToolRegistry` | ✅ |
| Parsing: raw model JSON → arguments | `ToolArguments.parse` | ✅ |
| Validation: required, types, enums, unknown keys | `ToolParameterSchema.validate` | ✅ |
| Permission: allowed / approval / blocked | `ToolPermissionPolicy`, applied by `ToolExecutor` | ✅ (command policy: Phase 4) |
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
| `run_command` | executesCommands | Phase 4 | Goes through `CommandPolicy` |
| `git_status`, `git_diff`, `git_log` | readOnly | Phase 4 | Through `GitService` |

Listing and searching skip hidden files and folders, and a fixed set of folders that are never
useful to an agent (`.git`, `.build`, `DerivedData`, `node_modules`, `Pods`, `dist`, `.venv`, `target`…).
`.gitignore` rules are **not** applied yet: that is planned for Phase 4, alongside Git.
`search_text` never searches files that look like secrets (see the security docs).

Write tools describe themselves for the approval banner (“Edit notes.md”, “Write a.txt (12 lines)”).

## Boundary

All path arguments are resolved against `ToolContext.projectRoot`, standardized, and
**symlink-resolved before the check**. Anything outside the root throws
`ToolError.outsideProjectBoundary`. See [security/permissions.md](../security/permissions.md).
