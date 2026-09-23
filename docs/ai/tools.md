# Tools

## Separation of concerns

| Concern | Where | Status |
|---|---|---|
| Definition: name, description, parameter schema, effect | `AgentTool` properties | ✅ |
| Registry: unique, valid names, stable order | `ToolRegistry` | ✅ |
| Parsing: raw model JSON → arguments | `ToolArguments.parse` | ✅ |
| Validation: required, types, enums, unknown keys | `ToolParameterSchema.validate` | ✅ |
| Permission: allowed / approval / blocked | `ToolExecutor` + policy | Phase 3–4 |
| Execution | `AgentTool.execute` | Phase 3–4 |
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

## Execution pipeline (Phase 3)

```
LLMToolCall ─▶ registry.tool(named:)          unknownTool ─┐
            ─▶ ToolArguments.parse            malformed  ──┤
            ─▶ tool.parameters.validate       invalid    ──┼─▶ failed ToolResult to the model
            ─▶ policy.decision(tool, args)    blocked    ──┤
               └ approval? ─▶ ApprovalHandler  denied    ──┘
            ─▶ withTimeout(tool.execute)      timedOut / error ─▶ failed ToolResult
            ─▶ ToolResult (output truncated to a budget, e.g. 16K characters, with a marker)
```

## Initial catalog

| Tool | Effect | Phase | Notes |
|---|---|---|---|
| `read_file` | readOnly | 3 | `path`, optional `offset`/`limit` lines; refuses binaries; caps size |
| `list_directory` | readOnly | 3 | `path`, optional `recursive`, respects `.gitignore` |
| `search_files` | readOnly | 3 | glob on paths |
| `search_text` | readOnly | 3 | regex/literal content search, capped results |
| `write_file` | writesFiles | 3 (review in 4) | creates or replaces; produces a `FileChange` |
| `edit_file` | writesFiles | 3 (review in 4) | exact-match `old_string` → `new_string`; fails if not unique |
| `run_command` | executesCommands | 4 | goes through `CommandPolicy` |
| `git_status`, `git_diff`, `git_log` | readOnly | 4 | through `GitService` |

## Boundary

All path arguments are resolved against `ToolContext.projectRoot`, standardized, and
**symlink-resolved before the check**. Anything outside the root throws
`ToolError.outsideProjectBoundary`. See [security/permissions.md](../security/permissions.md).
