import Foundation

// Stream lines cannot be wrapped without changing the wire format under test.
// swiftlint:disable line_length

/// Recorded or specification-derived provider payloads.
///
/// `OllamaFixtures.textStream` was captured from Ollama 0.34 (`gemma4:26b`);
/// tool-call and OpenAI streams follow the documented wire formats.
enum OllamaFixtures {
    static let textStream = """
        {"model":"gemma4:26b","created_at":"2026-09-23T12:18:14.672801Z","message":{"role":"assistant","content":"Hello"},"done":false}
        {"model":"gemma4:26b","created_at":"2026-09-23T12:18:14.739395Z","message":{"role":"assistant","content":" to"},"done":false}
        {"model":"gemma4:26b","created_at":"2026-09-23T12:18:14.8085Z","message":{"role":"assistant","content":" you"},"done":false}
        {"model":"gemma4:26b","created_at":"2026-09-23T12:18:14.808515Z","message":{"role":"assistant","content":"!"},"done":false}
        {"model":"gemma4:26b","created_at":"2026-09-23T12:18:14.879676Z","message":{"role":"assistant","content":""},"done":true,\
        "done_reason":"stop","total_duration":32559726917,"load_duration":32101892500,"prompt_eval_count":20,\
        "prompt_eval_cached_count":0,"prompt_eval_duration":234242000,"eval_count":5,"eval_duration":212356000}

        """

    static let thinkingToolStream = """
        {"model":"m","message":{"role":"assistant","content":"","thinking":"I should read it."},"done":false}
        {"model":"m","message":{"role":"assistant","content":"","tool_calls":[{"function":{"name":"read_file","arguments":{"path":"README.md"}}}]},"done":false}
        {"model":"m","message":{"role":"assistant","content":""},"done":true,"done_reason":"stop","prompt_eval_count":40,"eval_count":12}

        """

    static let tags = """
        {"models":[
          {"name":"gemma4:26b","details":{"context_length":262144},"capabilities":["completion","vision","tools","thinking"]},
          {"name":"nomic-embed-text","details":{"context_length":2048},"capabilities":["embedding"]}
        ]}
        """

    static let running = """
        {"models":[{"name":"gemma4:26b","context_length":65536}]}
        """
}

enum OpenAIFixtures {
    static let textStream = """
        data: {"id":"1","choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}

        data: {"id":"1","choices":[{"index":0,"delta":{"reasoning_content":"Thinking."},"finish_reason":null}]}

        data: {"id":"1","choices":[{"index":0,"delta":{"content":"Hi"},"finish_reason":null}]}

        data: {"id":"1","choices":[{"index":0,"delta":{"content":" there"},"finish_reason":null}]}

        data: {"id":"1","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

        data: {"id":"1","choices":[],"usage":{"prompt_tokens":12,"completion_tokens":3,"total_tokens":15}}

        data: [DONE]


        """

    /// Two tool calls whose arguments arrive in interleaved fragments.
    static let fragmentedToolCalls = """
        : keep-alive

        data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_a","type":"function","function":{"name":"read_file","arguments":""}}]}}]}

        data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"id":"call_b","type":"function","function":{"name":"list_directory","arguments":"{\\"pa"}}]}}]}

        data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"path\\":"}}]}}]}

        data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\\"a.swift\\"}"}}]}}]}

        data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":1,"function":{"arguments":"th\\":\\".\\"}"}}]}}]}

        data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}

        data: [DONE]


        """

    static let lmStudioModels = """
        {"data":[
          {"id":"google/gemma-4-26b-a4b-qat","object":"model","type":"vlm","state":"loaded",
           "max_context_length":262144,"loaded_context_length":80128,"capabilities":["tool_use"]},
          {"id":"qwen3-8b","object":"model","type":"llm","state":"not-loaded","max_context_length":32768},
          {"id":"text-embedding-nomic-embed-text-v1.5","object":"model","type":"embeddings","state":"not-loaded",
           "max_context_length":2048}
        ]}
        """

    static let openAIModels = """
        {"object":"list","data":[{"id":"llama-3.2-3b","object":"model"},{"id":"text-embedding-3-small","object":"model"}]}
        """
}

// swiftlint:enable line_length

extension String {
    /// The lines of a stream, blank separators included (decoders must ignore them).
    var streamLines: [String] {
        split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}
