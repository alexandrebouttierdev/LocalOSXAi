# Providers

**Status:** implemented in Phase 2. Ollama and LM Studio were verified against real servers
(Ollama 0.34, LM Studio with `/api/v0`) with `make test-live`.

## Contract

```swift
protocol LLMProvider: Sendable {
    var descriptor: ProviderDescriptor { get }
    func listModels() async throws -> [AIModel]
    func stream(request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error>
}
```

`LLMRequest` (model name, messages, tool definitions, options) and `LLMEvent` (text delta,
reasoning delta, tool call, usage, finished) are independent of any wire format. Each provider
translates them to and from its own format.

## Provider agnosticism

The agent never receives a concrete provider. It receives an `AIModel.ID`, and resolves it
through `ModelResolving` (implemented by `ProviderRegistry`) into a `ResolvedModel` (model +
`any LLMProvider`). It must never:

- branch on `descriptor.id` or `displayName`;
- import or reference a concrete provider type;
- rely on a provider-specific field.

Provider-specific handling lives **inside the provider**. For example, Ollama may omit tool call
IDs, so the Ollama decoder generates them. `make architecture` checks that `Core/` code never
names a provider.

## Layout

```
Infrastructure/Providers/
├── Shared/            ProviderHTTP (requests, status/error mapping, idle-timeout session),
│                      StreamingProvider (bytes → lines → decoder → AsyncThrowingStream),
│                      FunctionToolEncoding (tool JSON shared by both APIs)
├── Ollama/            OllamaWire (payloads, request body), OllamaStreamDecoder, OllamaProvider
└── OpenAICompatible/  OpenAIWire, OpenAIStreamDecoder, OpenAICompatibleProvider (flavor .lmStudio / .generic)
```

**Decoders are pure** (`LLMStreamDecoder`: `decode(line:)`, `finish()`), with no I/O. They are
tested directly from recorded fixtures, and the HTTP layer is tested separately.

Providers are built from `ProviderSettings` by `ProviderFactory` in the composition root, and
rebuilt when the user applies new settings (`ModelsViewModel.reconfigure`).

## Ollama (`http://localhost:11434`, native API)

| Concern | Behavior |
|---|---|
| Model list | `GET /api/tags`. Since 0.12 it includes `capabilities` and `details.context_length`. For older servers, the provider falls back to `POST /api/show` per model (`model_info.<arch>.context_length`) |
| Loaded context | `GET /api/ps` → `context_length` of loaded models → `ContextWindow.loadedTokens`. This call is best effort |
| Capabilities | `completion` is required (embedding models are skipped). `tools` → `.tools`, `vision` → `.vision`, `thinking` → `.reasoning`, and `.streaming` is always set |
| Chat | `POST /api/chat`, `stream: true`, NDJSON (one JSON object per line) |
| Context | `options.num_ctx` = effective context. **A `num_ctx` different from the loaded one makes Ollama reload the model** (32 s measured for a 26B model). The effective context therefore reuses the loaded size unless the user configured one |
| Reasoning | `think: true/false` when `GenerationOptions.reasoning` is set. Text arrives in `message.thinking` |
| Tool calls | Arrive whole in `message.tool_calls`. Arguments are a JSON **object**, which is re-serialized to a string. An `id` is used when present and generated otherwise. Results are sent back with `tool_name` |
| Errors | `{"error": "..."}` in the body or as a stream line. A 404 or "model … not found" becomes `modelNotFound`, "does not support tools" becomes `unsupportedCapability` |

The native API is used rather than Ollama's OpenAI-compatible endpoint because only the native
API exposes capabilities, the loaded context and `num_ctx`.

## LM Studio (`http://localhost:1234`, OpenAI-compatible)

| Concern | Behavior |
|---|---|
| Model list | `GET /api/v0/models` (LM Studio native): `type` (`llm`/`vlm`/`embeddings`), `state`, `max_context_length`, `loaded_context_length`, `capabilities` (`tool_use`). Only `llm`/`vlm` are kept. The provider falls back to `GET /v1/models` if the native endpoint is missing |
| Loaded context | `loaded_context_length` of loaded models → `loadedTokens`, which is reliable. Unloaded models get the 8K fallback |
| Chat | `POST /v1/chat/completions`, `stream: true`, `stream_options.include_usage`. The response is Server-Sent Events (`data: {…}`, ending with `data: [DONE]`) |
| Context | Cannot be set through this API: it is fixed when LM Studio loads the model |
| Reasoning | `reasoning_effort` for low/medium/high. Deltas are read from `reasoning_content` or `reasoning` |
| Tool calls | **Streamed in fragments** by `index`. They are buffered and emitted once, complete, when the choice finishes. Results are sent back with `tool_call_id` |
| Errors | `{"error": {"message": "..."}}` in the body or as a stream event |

The `.generic` flavor (any OpenAI-compatible server) uses only `/v1/models`, with no capability
information. API keys (Keychain) will be added with remote servers, after Phase 2.

## Timeouts

`URLSessionConfiguration.timeoutIntervalForRequest` is an **idle** timeout: it fires when no
byte arrives for that long. That is exactly the "server stopped responding" condition, so no
custom timer is needed. It defaults to **300 s** and can be set in Settings (30–1800 s),
because loading a model or evaluating a long prompt can take minutes before the first token.
LM Studio was observed accepting a connection and sending nothing for more than 60 s while busy.

## Error mapping

| Transport / HTTP | `ProviderError` |
|---|---|
| Connection refused, host not found, connection lost | `.unreachable(endpoint:)` |
| `URLError.timedOut` | `.timedOut` |
| `URLError.cancelled` | `CancellationError` (the cancellation contract) |
| 404, "model … not found" | `.modelNotFound` |
| "does not support tools" | `.unsupportedCapability("tool calling")` |
| Other non-2xx | `.httpStatus(code:message:)`, with the server's message |
| Unparsable payload, stream cut before completion | `.invalidResponse` |

## Testing

| Level | How |
|---|---|
| Decoders and request encoding | Pure unit tests on fixtures (`Tests/Support/ProviderFixtures.swift`). The Ollama text stream is a real capture |
| HTTP behavior | `StubURLProtocol` answers a real `URLSession` per unique host: routing, bodies, lines split across chunks, HTTP errors, unreachable server, cancellation (`stopLoading` observed) |
| Real servers | `make test-live` (`LOCALOSXAI_LIVE_TESTS=1`): lists and streams with the local Ollama, lists LM Studio. Opt-in, never part of `make test` |
