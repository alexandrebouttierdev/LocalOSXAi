# 0014: Trust the runtime's loaded context size

**Status:** Accepted. Amends [0008](0008-context-management.md), whose conservative rule still
applies when nothing more reliable is known.

## Context
ADR 0008 set the effective context to `min(configured ?? 8K, advertised)`. In practice, runtimes
report the context they **actually allocated** for loaded models (LM Studio
`loaded_context_length`, Ollama `/api/ps` `context_length`). On Ollama, requesting a different
`num_ctx` forces a full model reload, which took 32 s in testing.

## Decision
`ContextWindow` gains `loadedTokens`. The effective context becomes
`min(configured ?? loaded ?? 8K, advertised)`, and it is what Ollama receives as `num_ctx`.
A loaded model is therefore reused at its current size, with no reload and no truncation risk,
because the size is the real allocation.

## Alternatives
- **Always send the fallback or a configured value**: forces reloads and discards known facts.
- **Trust the advertised maximum**: still rejected, for the reasons in ADR 0008.

## Consequences
- The budget can differ for the same model depending on whether it was loaded, and the
  inspector shows the effective value.
- LM Studio's context can only be changed in LM Studio itself. Settings says so.
