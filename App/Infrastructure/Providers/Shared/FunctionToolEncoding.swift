import Foundation

extension ToolDefinition {
    /// The `{"type": "function", "function": {...}}` tool format shared by the
    /// OpenAI API and Ollama's native API.
    var functionToolJSON: JSONValue {
        [
            "type": "function",
            "function": [
                "name": .string(name),
                "description": .string(description),
                "parameters": parameters.jsonSchema
            ]
        ]
    }
}
