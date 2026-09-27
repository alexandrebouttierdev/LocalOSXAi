# 0021: Custom OpenAI-compatible servers declare what they cannot report

**Status:** Accepted

## Context
Many local runtimes other than Ollama and LM Studio implement the OpenAI chat completions API:
llama.cpp's `llama-server`, vLLM, Jan, LocalAI, a proxy on another machine. The
`OpenAICompatibleProvider` already spoke to them (`.generic` flavor), but nothing let the user
add one, and their `/v1/models` listing returns names only: no tool support, no context length.
The agent disables tools for a model without `.tools` and budgets an unknown context at 8K, so
such a server would have been a plain chat with a small context. Some of these servers also
require an API key (`llama-server --api-key`, `vllm serve --api-key`).

## Decision
- `ProviderSettings.customServers` (still `providers.v1`, the field is optional when decoding):
  a name, a URL, enablement, and two **declared** properties per server:
  - “Models support tool calling” (on by default): adds `.tools` to every model of the server.
    Tool calls are validated whatever a capability says, so a wrong declaration produces
    rejected calls or a server error (`unsupportedCapability`), never an unchecked action.
  - “Context length” (Unknown by default): the size the server was started with, used as
    `ContextWindow.configuredTokens`. Unknown keeps the 8K fallback.
- A server's `ProviderID` is `server-<uuid>`, derived from an identity created when it is
  added, so renaming it or changing its URL keeps its per-model settings and its API key.
- API keys are optional, stored only in the Keychain through the `ProviderSecretStore` port
  (`KeychainProviderSecretStore`), written on Apply and deleted when the server is removed.
  They are sent as `Authorization: Bearer`.
- Settings warn, next to the URL, when a server is not on this Mac (only loopback hosts
  count): prompts, including quoted file contents, go to that host. The warning says so too
  when an API key would travel over plain HTTP.

## Alternatives
- **Probe each server** (llama.cpp `/props`, vLLM `max_model_len` in `/v1/models`): more
  automatic, but server-specific and fragile; the declaration works for all of them. A probe
  can later fill the defaults without changing the model.
- **Always offer tools, or never**: always breaks servers that reject `tools`; never makes
  the agent useless with the servers that support them best.
- **Store keys in `UserDefaults`**: rejected by the security rules
  ([permissions.md](../security/permissions.md)).
- **Block non-local servers**: a server on the local network is a legitimate setup (a GPU
  machine). Informing is enough; the user configured the URL.

## Consequences
- Custom servers appear in the model picker and the inspector like any provider; the runtime
  is unchanged and still knows only `LLMProvider`.
- The Keychain implementation is not covered by automated tests (it would prompt on developer
  machines and fail on CI without a keychain); the view model and factory are tested with an
  in-memory store and a failing one.
- Development builds are signed ad hoc, so macOS may ask for Keychain access after a rebuild.
