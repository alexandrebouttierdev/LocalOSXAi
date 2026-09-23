# Providers

## Contract

```swift
protocol LLMProvider: Sendable {
    var descriptor: ProviderDescriptor { get }
    func listModels() async throws -> [AIModel]
    func stream(request: LLMRequest) -> AsyncThrowingStream<LLMEvent, Error>
}
```

`LLMRequest` (model name, messages, tool definitions, options) and `LLMEvent` (text delta,
reasoning delta, tool call, usage, finished) are wire-independent. Each provider translates them
to and from its own format.

## Provider agnosticism

The agent runtime (Phase 3) receives an `any LLMProvider` and an `AIModel`. It must never:

- branch on `descriptor.id` or `displayName`;
- import or reference a concrete provider type;
- rely on a provider-specific field in `LLMRequest`.

When a provider needs special handling, the handling belongs **inside that provider**. For
example, Ollama does not assign tool call IDs, so `OllamaProvider` generates them. Adding
Anthropic or OpenAI later must require no change to the agent. `make architecture` checks that
`Core/` code never names a provider.

## Planned implementations (Phase 2)

Folder: `App/Infrastructure/Providers/{Ollama,LMStudio,OpenAICompatible}/`.

### Ollama (`http://localhost:11434`)

- Models: `GET /api/tags`, then `POST /api/show` per model to read `capabilities`
  (`tools`, `vision`, `thinking`) and `model_info.<arch>.context_length` (advertised context).
- Chat: `POST /api/chat` with `stream: true`, which returns **NDJSON** (one JSON object per line).
- Tool calls arrive as whole objects in `message.tool_calls`, with **no id** and arguments as a
  JSON **object**, not a string. The provider generates ids and re-serializes the arguments to
  keep `LLMToolCall.rawArguments` uniform.
- Context: set `options.num_ctx` from `GenerationOptions.contextLength`. **Without it, Ollama
  uses a small default and silently truncates the prompt.** This is why the effective context is
  always sent explicitly.
- Reasoning: `think: true` for models with the `thinking` capability. Reasoning arrives in
  `message.thinking`.

### LM Studio (`http://localhost:1234/v1`)

- OpenAI-compatible API: `GET /v1/models`, `POST /v1/chat/completions` with `stream: true`, which
  returns **SSE** (`data: {…}` lines, ending with `data: [DONE]`).
- Tool call arguments are **streamed in fragments** across chunks, keyed by `index`. The
  provider accumulates them and emits one complete `LLMToolCall` when the call ends. This is
  required by the streaming contract.
- The LM Studio REST API (`/api/v0/models`) additionally exposes `max_context_length` and a
  loaded/unloaded state. It is used when available and falls back to `/v1/models`.

### OpenAI-compatible

The LM Studio implementation, generalized: a configurable base URL and optional API key (from
the Keychain). The LM Studio provider becomes a thin configuration of it.

## Testing providers

- Unit tests decode **recorded fixtures** (NDJSON/SSE files) through a `URLProtocol` stub. They
  never contact a real server.
- Required cases: text stream, reasoning stream, one and several tool calls, fragmented tool
  arguments, malformed chunk, HTTP 404/500, unreachable host, cancellation mid-stream.
- An opt-in integration suite (`LOCALOSXAI_LIVE_TESTS=1`) runs against a local Ollama/LM Studio.
