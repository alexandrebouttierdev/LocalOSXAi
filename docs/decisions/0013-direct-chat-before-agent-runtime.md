# 0013: Ship a direct streaming chat in Phase 2, before the tool runtime

**Status:** Accepted. Completed in Phase 3: `AgentRuntime` replaced `DirectChatAgentService` as planned.

## Context
Phase 2 delivers providers, model discovery and streaming. Without a consumer, streaming would
only be exercised by tests: the UI would keep running on the simulated agent until Phase 3,
and real-world issues (model loading latency, context reloads, reasoning output) would stay
invisible for a whole phase.

## Decision
Add `DirectChatAgentService`: an `AgentService` that resolves the selected model through
`ModelResolving`, fits the conversation into the context budget with `ConversationWindow`
(oldest turns dropped first), and streams the answer with **no tools**. Its system prompt tells
the model that it cannot read files, so it does not invent file contents. It becomes the live
default. `SimulatedAgentService` stays available with `LOCALOSXAI_SIMULATED=1` for UI work
without a model server.

## Alternatives
- **Keep the simulated agent until Phase 3**: no real feedback on providers from the UI.
- **Build the tool runtime now**: mixes two phases and their risks in one step.

## Consequences
- The app is usable with real local models from Phase 2.
- `ConversationWindow` is a deliberate, tested precursor of the Phase 3 `ContextManager`, which
  will replace it (compaction, instructions, tool results).
- Phase 3 replaces `DirectChatAgentService` in `AppEnvironment` without touching the UI.
