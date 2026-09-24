# Model capabilities

## `AIModel`

| Field | Meaning |
|---|---|
| `provider` + `name` | Identity (`AIModel.ID`). The same name on two providers is two models |
| `displayName` | Shown in the UI, always next to the provider name (“Ollama · gpt-oss:20b”) |
| `contextWindow` | `advertisedTokens`, `loadedTokens`, `configuredTokens`, `effectiveTokens` |
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
effective = min(configured ?? loaded ?? 8_192, advertised ?? ∞)
```

- **Configured**: the user's choice (Settings → Providers → Ollama context length).
- **Loaded**: what the runtime reports as actually allocated for a loaded model (LM Studio
  `loaded_context_length`, Ollama `/api/ps`). It is reliable, and reusing it avoids an Ollama
  model reload ([ADR 0014](../decisions/0014-trust-loaded-context-size.md)).
- **8K fallback** otherwise, even if 128K is advertised. Being conservative costs some context.
  Being optimistic produces silently truncated prompts, which is much worse.
- The effective value is sent to runtimes that allocate on demand
  (`GenerationOptions.contextLength` → Ollama `num_ctx`), so it is also the allocated one.
- The inspector shows the effective value and, as a tooltip, the advertised maximum.

## Selection

- `ModelsViewModel.refresh()` keeps the current selection if it still exists. Otherwise it
  prefers the first tool-capable model, because the agent is much less useful without tools.
- The palette's “Change Model…” lists models grouped by provider.
- Per-session model memory: `Session.model` records the model used by the latest run.

## User-configurable

- Phase 2: provider endpoints and enablement, Ollama context length (Automatic or 8K–128K),
  and the network idle timeout. Model selection is in the inspector or with ⌘L.
- Per-model settings (inspector › Model Settings, saved in SQLite): temperature (0–2),
  reasoning effort (default/off/low/medium/high, only for models with `.reasoning`) and the
  context length (only when the provider can set it per request, `ProviderDescriptor.supportsContextLength`:
  Ollama; LM Studio fixes it at load time). A chosen context replaces the configured one and is
  still capped by the advertised maximum. The inspector's “ctx” chip shows the context actually
  used (`ContextWindow.effectiveTokens(choosing:)`, shared with the runtime).
