# 0004: Provider abstraction and a provider-agnostic agent

**Status:** Accepted

## Context
The app targets Ollama and LM Studio first, then any OpenAI-compatible server, and possibly
hosted providers later. Their wire formats differ: NDJSON vs SSE, tool calls whole vs
fragmented, IDs present vs absent, and different context settings.

## Decision
Define `LLMProvider` (`listModels`, `stream(request:)`) with wire-independent `LLMRequest`
and `LLMEvent` types in `Core`. Every provider-specific behavior is absorbed inside the
provider (assembling fragmented tool arguments, generating missing IDs, mapping context
options). The agent depends only on `LLMProvider` and on `AIModel` capabilities. Core code
must not name a provider, and a script checks this.

## Alternatives
- **Use an OpenAI-compatible API for everything**: Ollama offers one, but it loses native
  features (capabilities from `/api/show`, `num_ctx`, `think`) that matter for local models.
- **A third-party multi-provider SDK**: adds a dependency whose abstractions leak and whose
  concurrency model we do not control.

## Consequences
- Adding a provider means adding a folder in `Infrastructure/Providers` and a line in `AppEnvironment`.
- Providers must be tested with recorded stream fixtures, including malformed input.
- Some provider-specific features need an abstract capability first (e.g. `.reasoning`) before
  the agent can use them.
