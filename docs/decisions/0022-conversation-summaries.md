# 0022: Summarize old conversation once per run, keep the summary in the transcript

**Status:** Accepted (amends 0008, which planned summaries without deciding how)

## Context
Local models often run with 8K–32K tokens of context. A session of a few dozen exchanges fills
it, and `RunContext` then drops the oldest messages: the agent forgets the goal, decisions and
constraints stated at the start, which is exactly what makes a long session useful. ADR 0008
planned to summarize old turns before dropping them. Summaries cost a model call, which can
take tens of seconds on a local model, and the model can fail or write nonsense.

## Decision
- **Once, before the run.** Summarizing happens only at the start of a run, when the conversation
  exceeds half of the prompt budget, leaving the other half for the run's own tool calls. Within
  a run, the existing steps (shorten arguments, truncate old outputs, drop history) still apply.
- **Stored in the transcript** as an `AgentMessage` with role `.summary`, inserted right after
  the last message it covers. Its position is its scope: the model sees the latest summary, then
  the messages after it. No schema change is needed (the role is a text column), the summary is
  saved with the session like any message, and a later run reuses it instead of paying again.
- **Cumulative.** A new summary is written from the previous one plus the messages after it, so
  one summary always covers everything before it.
- **In the system prompt**, not as a message, because many chat templates require strictly
  alternating user and assistant roles.
- **Never a failure.** If the summary call fails or returns nothing, the run continues and drops
  old messages as before. Only cancellation ends the run.
- **Visible and optional.** The transcript shows the summary where it applies, collapsed, and a
  progress row while it is written. Settings › General can turn summaries off.

## Alternatives
- **Summarize at every iteration when over budget**: the tightest fit, but it can add a model call
  per step and change what the model knows in the middle of a task.
- **Store the summary on the session** (new column, “covers through message X”): works, but needs
  a migration and a second source of truth for what the model sees; the transcript position says
  the same thing and is visible.
- **Send the summary as a user message**: breaks templates that reject consecutive user messages.
- **A dedicated, smaller summarization model**: faster, but needs a second model loaded, which
  local setups rarely have memory for.

## Consequences
- The first run that crosses the threshold takes longer; the row in the transcript says why.
- Summaries are written by the model and can be wrong. They stay readable in the transcript, and
  the original messages are never deleted.
- Older app versions cannot read a transcript containing a summary (unknown role). History is
  forward-only, like the database migrations.
