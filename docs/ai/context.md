# Context management

**Status:** `ContextUsage`, `TokenEstimator` and the inspector meter (“38.4K / 100K context”)
are implemented. `ContextManager` is Phase 3. This is its design.

## Inputs, in priority order

| Priority | Input | Truncatable? |
|---|---|---|
| 1 | System prompt (agent role, tool-use rules, safety rules) | No |
| 2 | Project instructions (AGENTS.md etc.) | Only by an explicit, reported cap |
| 3 | Current task: the latest user message | No |
| 4 | Latest tool results of the current run | Yes: large outputs truncated with a marker |
| 5 | Git context (branch, short status) | Yes: dropped first |
| 6 | Relevant files explicitly attached by the user | Yes |
| 7 | Earlier conversation | Yes: summarized (compaction), then dropped oldest first |

## Budget

```
budget = model.contextWindow.effectiveTokens − reserved output (e.g. 25%, min 1K)
```

- The effective window comes from `ContextWindow` and is never the advertised maximum alone
  (see [model-capabilities.md](model-capabilities.md)).
- Counting uses `TokenEstimator`, a deliberately conservative heuristic of about 4 characters
  per token, plus 4 tokens of overhead per message. When a provider reports real usage
  (`LLMEvent.usage`), the manager recalibrates its ratio for that model for the rest of the session.
- The meter shows `used / budget`. It turns orange at 75% and red at 90%, and says “Over budget”
  in text.

## Project instructions

When a project opens, the manager loads instruction files, in this documented precedence:

1. `AGENTS.md` at the project root: **primary**, and the only one loaded by default.
2. `AGENTS.md` in subdirectories: loaded when the agent works on files under them. The nearest
   file wins on conflicts.
3. `CLAUDE.md` and `.cursor/rules/*.mdc`: **opt-in per project**, off by default. Mixing rule
   systems silently would make behavior unpredictable, so the user explicitly chooses to
   include them, and they are then appended *after* AGENTS.md, labelled with their source.

Every loaded file is listed in the inspector so the user knows what the model was told.

## Compaction

When the next request would exceed the budget:

1. truncate large tool outputs from earlier iterations (keep head and tail, add a marker);
2. summarize the oldest conversation turns with the same model into a “Conversation summary”
   message (the original messages remain in the session, and only the prompt changes);
3. if still over budget, fail the run with `contextOverflow` and suggest starting a new session.

Compaction never removes priorities 1–3.

## Required tests

Budget computation, priority ordering, truncation markers, summarization trigger, overflow
error, instruction precedence, and recalibration from reported usage.
