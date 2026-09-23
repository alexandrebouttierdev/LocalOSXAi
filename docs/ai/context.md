# Context management

**Status:** implemented in Phase 3 by `AgentPrompt` (system prompt, instructions, history
conversion) and `RunContext` (budget and compaction), with the inspector meter
(“38.4K / 100K context”) and the list of loaded instruction files. **Not implemented yet:**
summarizing old turns with the model (see the compaction steps below). History is dropped instead.
Git context and attached files arrive with Phases 4 and 6.

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

1. `AGENTS.md` at the project root: **primary**, and the only file loaded today
   (`FileProjectInstructionsLoader`, capped at 16,000 characters with a reported truncation).
2. `AGENTS.md` in subdirectories: planned. It will be loaded when the agent works on files under
   them, and the nearest file will win on conflicts.
3. `CLAUDE.md` and `.cursor/rules/*.mdc`: planned as **opt-in per project** (project settings,
   Phase 5), off by default. Mixing rule systems silently would make behavior unpredictable, so
   the user will explicitly choose to include them. They will be appended *after* AGENTS.md,
   labelled with their source.

Every loaded file is listed in the inspector so the user knows what the model was told.

## Compaction

When the next request would exceed the budget:

1. ✅ truncate tool outputs from earlier iterations of the run to 1,500 characters (head and
   tail, with a marker), keeping the latest result intact;
2. ✅ drop earlier conversation, oldest first, never leaving an answer without its question.
   Earlier runs' tool calls are already summarized to one line each in history;
3. *planned*: summarize the oldest turns with the same model into a “Conversation summary”
   message instead of dropping them (the session keeps the originals);
4. ✅ if the run still does not fit, fail with `contextOverflow` and suggest a shorter message
   or a larger context.

Compaction never removes priorities 1–3.

## Required tests

Budget computation, priority ordering, truncation markers, summarization trigger, overflow
error, instruction precedence, and recalibration from reported usage.
