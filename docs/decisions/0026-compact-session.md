# 0026: “Compact session” summarizes everything on request; the automatic threshold is a setting

**Status:** Accepted (extends [0022](0022-conversation-summaries.md))

## Context
Automatic summaries (ADR 0022) start only when a run would begin with more than half of the
prompt budget used, and always keep the last exchange. Users working with small local contexts
want to clear the context themselves before a new task, as `/compact` does in other agents, and
to choose how early automatic summaries start: a fixed 50 % summarizes too late for some models
and too early for others.

## Decision
- **A separate `AgentService.compact(_:)` operation**, not a flag on `run`: compacting sends no
  message, has no tools and no approvals, and must not start a run.
- **Everything since the latest summary is summarized**, including the last exchange, so the
  next run starts from the summary alone. It reuses 0022's request, size limit and placement.
- **At least one exchange** is required (`AgentError.nothingToCompact`); the button and command
  are disabled otherwise, and while a run or compaction is in progress.
- **Failure is reported** (the stream throws after `historySummaryDiscarded`), because the user
  asked for it; an automatic summary still fails silently. The error is shown under the button,
  not in the transcript, where an error entry would offer to retry the previous run.
- **Independent of the automatic switch**: turning summaries off in Settings disables only
  automatic ones.
- **The automatic threshold is a setting** (`AgentSettings.compactThresholdPercent`, 30–80 %,
  default 50 %), mapped to `AgentLimits.summaryStartRatio`. Above 80 % a run starts with too
  little room for its own tool results; below 30 % summaries become frequent model calls.

## Alternatives
- **Keep the last exchange verbatim, as automatic summaries do**: the context barely shrinks
  in a short session, which is when users press the button.
- **Delete the messages after summarizing**: frees nothing more for the model (it already only
  sees the summary) and loses what the user may want to reread.
- **Show failures as a transcript error entry**: consistent with runs, but makes the last user
  message “retryable”, and retrying would re-run it.
- **A global default context length as the “general limit”**: a different need, already
  covered per provider (Ollama, custom servers) and per model in the inspector.

## Consequences
- A compaction costs one model call with no visible answer other than the summary row.
- Settings saved by older versions decode with the 50 % default.
