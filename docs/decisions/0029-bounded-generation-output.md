# 0029: Send the context's reserved output margin as the model's output cap (amends 0008)

**Status:** Accepted

## Context

[ADR 0008](0008-context-management.md) reserves a share of the context window (25%, at least
1,024 tokens) as margin for the model's answer, but that reserve (`RunContext.outputReserve`)
was only ever used to size the *prompt* budget — nothing told the provider to actually stop
generating there. `GenerationOptions.maxOutputTokens` existed on the request type and both
providers already forwarded it (`max_tokens` for OpenAI-compatible servers, `num_predict` for
Ollama), but no caller ever set it, so a model's answer was bounded only by its own defaults.

The system prompt and the `write_file` description ask models to write long files in several
steps, but a local model that ignores this can generate for as long as it likes. One run against
LM Studio (`gemma-4-26b-a4b-qat`) generated roughly 16,000 tokens for a single `write_file` call
and still finished without the required `path` argument. Because LM Studio buffers a whole tool
call and sends no bytes while building it (docs/ai/providers.md § Timeouts), the run looked hung
for over 20 minutes and then failed with the generic `ProviderError.timedOut`, instead of the
fast, actionable `AgentError.toolCallCutOff`/`outputLimitReached` the runtime already implements
for a response cut by length (docs/ai/agent.md § Error recovery). The idle-timeout ceiling
(1,800 s) cannot fix this: raising it only makes a runaway generation more expensive before it
still fails.

## Decision

`AgentRuntime.generationOptions` sends `RunContext.outputReserve(contextTokens:)` as
`GenerationOptions.maxOutputTokens`, unless the run already set one (a future per-model override
stays possible), **and only when the effective context is known**
(`ContextWindow.isEffectiveSizeKnown`): the runtime allocates the size sent with each request
(Ollama's `num_ctx`, `allocatesRequestedTokens`), or the size was chosen, configured, or reported
for the loaded model. When it is only the 8K fallback, no cap is sent: LM Studio unloads idle
models and loads them again on demand with a size of its own (80K in the run that showed this),
and a 2K cap derived from the guess cut a landing page that the model could write in 11K tokens.

The cap applies to every model call the runtime makes, including the summary request (`AgentRuntime.summary`): the reserve is always larger than the ~1K tokens a summary asks
for, so it never cuts a summary short.

## Alternatives

- **Keep relying on the idle timeout and the prompting alone**: the status quo; leaves a model
  that ignores the "write in several steps" instruction to fail slowly (minutes of silent
  generation) and unhelpfully (`timedOut` names no cause), the exact bug this ADR fixes.
- **A separate, independently configured cap**: more surface (another Settings control) to
  duplicate or contradict a number already computed for the same purpose (bounding a single
  turn's answer).
- **A fixed constant (e.g. 4,096 tokens) regardless of context size**: simpler, but wrong at both
  ends — it starves a 2K-context model of any real answer, and needlessly limits a 128K-context
  one that could legitimately use more room.

## Consequences

- A tool call or answer that would have run away now fails fast with `toolCallCutOff` or
  `outputLimitReached`, both of which already tell the model (and the user, via
  `recoverySuggestion`) to split the work into smaller steps or use a larger context.
- A run on a model whose runtime has not loaded it yet (fallback context) keeps the old
  behavior for that run: no cap, and the idle timeout as the only guard.
- Very small context windows (near the 1,024-token floor) leave little room for a real answer;
  this was already true of the prompt budget before this change, so no new failure mode is
  introduced, only a faster one.
- `docs/ai/context.md`, `docs/ai/agent.md` and `docs/ai/providers.md` document the cap.
