# Context management

**Status:** implemented in Phase 3 by `AgentPrompt` (system prompt, instructions, history
conversion) and `RunContext` (budget and compaction), with the inspector meter
(“38.4K / 100K context”) and the list of loaded instruction files. Summarizing old turns with
the model was added in Phase 8 (`HistoryCompaction`, see below). Git context and attached files
arrive with Phases 4 and 6.

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

- The reserved output (`RunContext.outputReserve`) is not just a margin for the prompt: it is
  also sent to the provider as `GenerationOptions.maxOutputTokens` when the effective size is
  known, not the fallback (`ContextWindow.isEffectiveSizeKnown`; `AgentRuntime.generationOptions`,
  [ADR 0029](../decisions/0029-bounded-generation-output.md)), so a model that ignores the
  "write in several steps" instruction hits this limit and fails fast with
  `toolCallCutOff`/`outputLimitReached` instead of generating silently until the provider's idle
  timeout (see [providers.md](providers.md#timeouts)).
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
3. `CLAUDE.md`: ✅ **opt-in per project** (“Also read CLAUDE.md” in the inspector, saved with the
   project), off by default. Mixing rule systems silently would make behavior unpredictable, so
   the user chooses. It is appended *after* AGENTS.md, labelled with its source, and applies
   from the next run. `.cursor/rules/*.mdc`: not supported yet.

Every loaded file is listed in the inspector so the user knows what the model was told.

## Compaction

When the next request would exceed the budget:

1. ✅ shorten large string arguments of tool calls already executed (typically a whole file
   passed to `write_file`) to 1,500 characters, keeping the JSON valid
   (`PartialJSON.compactingLongStrings`). The tool result already says what happened;
2. ✅ truncate tool outputs from earlier iterations of the run to 1,500 characters (head and
   tail, with a marker), keeping the latest result intact;
3. ✅ drop earlier conversation, oldest first, never leaving an answer without its question.
   Earlier runs' tool calls are already summarized to one line each in history;
4. ✅ before the run, summarize the oldest turns with the same model (see
   [Conversation summaries](#conversation-summaries)), so step 3 rarely has anything to drop;
5. ✅ if the run still does not fit, fail with `contextOverflow` and suggest a shorter message
   or a larger context.

Compaction never removes priorities 1–3.

## Conversation summaries

A long session eventually fills the context, and dropping its oldest messages makes the agent
forget decisions made at the start. So, **once, before a run**, `AgentRuntime` asks the same model
to summarize them ([ADR 0022](../decisions/0022-conversation-summaries.md)):

- **When**: the system prompt, the current summary, the earlier conversation and the new request
  exceed **half** of the prompt budget (`HistoryCompaction.defaultStartRatio`, adjustable in
  Settings › General › “Summarize when context is”: 30–80 % full, `AgentLimits.summaryStartRatio`).
  The rest stays free for this run's tool calls and results.
- **What**: the oldest messages, cut before a user message so kept history never starts with an
  answer. The last exchange is always kept verbatim, and at least one exchange must be summarized.
  The smallest cut that brings the run under the threshold is chosen, else the largest.
- **How**: a separate model call without tools. The request folds in the previous summary, so a
  single summary always covers everything before it. It asks for at most an eighth of the prompt
  budget (1K tokens at most) and a longer answer is shortened.
- **Where**: the summary is appended to the system prompt (“# Earlier conversation (summary)”),
  not sent as a message: many chat templates reject two user messages in a row.
- **Kept**: it is saved in the transcript as a `.summary` message, placed right after the last
  message it covers. The UI shows it there as a collapsible “Conversation summarized” row
  (“Summarizing the conversation… 12 s” while the model writes it). Later runs start from the
  latest summary and never summarize the same messages twice. The original messages stay in
  the session.
- **Failure**: an error or an empty summary is not a run failure. The summary row disappears, the
  run continues on the unsummarized history, and step 3 drops what does not fit. Stopping the
  run during the summary stops it like any other step.
- **Off switch**: Settings › General › “Summarize earlier conversation” (on by default). Off, the
  oldest messages are only dropped.

### Compact session

The user can also summarize **the whole conversation now**, like `/compact`: the “Compact
session” button of the inspector's Context section, or “Compact Session” in the palette and the
Go menu ([ADR 0026](../decisions/0026-compact-session.md)).

- `AgentService.compact(_:)` summarizes every message since the latest summary (at least one
  exchange, else `AgentError.nothingToCompact`), with the same request, size limit and
  placement as above: the summary goes after the last message, and the next run starts from it
  with no earlier message replayed. It then reports the new, much smaller context usage.
- It works with summaries turned off in Settings: the switch only concerns automatic summaries.
- While it runs, the session is busy (`AgentViewModel.isCompacting`): nothing can be sent, and
  ⌘. stops it, which removes the unfinished summary.
- **Failure is reported**, unlike an automatic summary: the transcript is left as it was and the
  inspector shows why under the button (`AgentViewModel.compactionError`), until the next
  compaction or message. It is not a transcript entry, so it never offers to retry the last run.

## Required tests

Budget computation, priority ordering, truncation markers, summarization trigger and threshold,
manual compaction (success, failure, cancellation, nothing to compact), overflow error,
instruction precedence, and recalibration from reported usage.
