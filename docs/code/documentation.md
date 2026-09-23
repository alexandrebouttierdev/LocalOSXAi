# Documenting code

Document **why**, not **what**. Assume the reader knows Swift, but not this project's
history or constraints.

## Always document

- **Why an abstraction exists**, e.g. `LLMProvider`: "exists so the agent runtime stays
  provider-agnostic".
- **Invariants**, e.g. `ContextWindow.effectiveTokens` never exceeds the advertised size,
  and `TranscriptReducer` allows at most one streaming message.
- **Concurrency contracts**: isolation, cancellation behavior, what may be called from where.
- **Security-relevant behavior**: boundaries, validation, what is never logged.
- **Non-obvious behavior**, e.g. empty tool arguments are accepted because some models send `""`.
- **Provider quirks**, e.g. Ollama silently truncates to `num_ctx`.
- **Error recovery**: what the caller is expected to do with each failure.

## Never write

```swift
// Get the model
let model = models.first
```

A comment that restates the code is noise, and it becomes wrong the first time the code changes.

## Format

Use DocC comments (`///`) on types and non-trivial members:

```swift
/// Executes one agent iteration and returns the resulting events.
///
/// The method does not execute tools directly. Tool execution is delegated
/// to `ToolExecutor` so the agent runtime remains provider-independent.
```

- First line: a one-sentence summary.
- Then a blank line, then the reasoning, contracts and `- Throws:` / `- Parameters:` where useful.
- Link related docs with relative paths: `See docs/ai/tools.md.`

## Docs folder

Code-level comments explain local decisions, and `docs/` explains cross-cutting ones. When a
comment grows beyond about 10 lines, move the explanation to `docs/` and link to it.
