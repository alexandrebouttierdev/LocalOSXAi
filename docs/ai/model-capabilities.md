# Model capabilities

## `AIModel`

| Field | Meaning |
|---|---|
| `provider` + `name` | Identity (`AIModel.ID`). The same name on two providers is two models |
| `displayName` | Shown in the UI, always next to the provider name (“Ollama · gpt-oss:20b”) |
| `contextWindow` | `advertisedTokens`, `configuredTokens`, `effectiveTokens` |
| `capabilities` | `ModelCapabilities` option set: `.tools`, `.vision`, `.streaming`, `.reasoning` |
| `supportsTools/Vision/Streaming/Reasoning` | Convenience accessors |

## Declared, not trusted

Capabilities are *declared* by providers and are often wrong for local models:

- A model can advertise tool support and still emit malformed calls. So **every tool call is
  validated**, whatever the capability says.
- The advertised context length is the model's theoretical maximum, **not** what the runtime
  allocated. Ollama silently truncates to its `num_ctx`, and LM Studio uses the context length
  chosen when the model was loaded.

## Effective context rule

```
effective = min(configured ?? 8_192, advertised ?? ∞)
```

- Without user configuration, the app assumes **8K** even if 128K is advertised. Being
  conservative costs some context. Being optimistic produces silently truncated prompts,
  which is much worse.
- The user raises the value per model (Settings, Phase 2/5). The app then sends it to the
  runtime (`GenerationOptions.contextLength` → Ollama `num_ctx`), so the configured value is
  also the allocated one.
- The inspector shows the effective value and, as a tooltip, the advertised maximum.

## Selection

- `ModelsViewModel.refresh()` keeps the current selection if it still exists. Otherwise it
  prefers the first tool-capable model, because the agent is much less useful without tools.
- The palette's “Change Model…” lists models grouped by provider.
- Per-session model memory: `Session.model` records the model used by the latest run.

## User-configurable (Phase 2/5)

Provider, model, context size, temperature and reasoning effort (`ReasoningEffort`:
off/low/medium/high, shown only for models with `.reasoning`).
