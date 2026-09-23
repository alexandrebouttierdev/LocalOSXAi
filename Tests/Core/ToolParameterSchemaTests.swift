import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ToolParameterSchema")
struct ToolParameterSchemaTests {
    private let schema = ToolParameterSchema(
        properties: [
            "path": .init(.string, "File path"),
            "limit": .init(.integer, "Maximum lines"),
            "ratio": .init(.number, "Ratio"),
            "recursive": .init(.boolean, "Recurse"),
            "mode": .init(.string, "Mode", allowedValues: ["fast", "full"]),
            "globs": .init(.stringArray, "Patterns")
        ],
        required: ["path"]
    )

    @Test("valid arguments pass")
    func validArguments() throws {
        try schema.validate(ToolArguments([
            "path": "a", "limit": 3, "ratio": 0.5, "recursive": false, "mode": "fast", "globs": ["*.swift"]
        ]))
    }

    @Test("missing required argument fails")
    func missingRequired() {
        #expect(throws: ToolError.missingArgument("path")) { try schema.validate(ToolArguments(["limit": 1])) }
    }

    @Test("null required argument counts as missing")
    func nullRequired() {
        #expect(throws: ToolError.missingArgument("path")) { try schema.validate(ToolArguments(["path": nil])) }
    }

    @Test("unknown arguments are rejected, not ignored")
    func unexpectedArgument() {
        #expect(throws: ToolError.unexpectedArgument("max_results")) {
            try schema.validate(ToolArguments(["path": "a", "max_results": 5]))
        }
    }

    @Test("null optional arguments are accepted")
    func nullOptional() throws {
        try schema.validate(ToolArguments(["path": "a", "limit": nil]))
    }

    @Test(
        "type mismatches are rejected",
        arguments: [
            ("limit", JSONValue.string("3")),
            ("limit", JSONValue.number(1.5)),
            ("ratio", JSONValue.bool(true)),
            ("recursive", JSONValue.number(1)),
            ("globs", JSONValue.array([1])),
            ("mode", JSONValue.string("slow"))
        ]
    )
    func typeMismatch(name: String, value: JSONValue) {
        #expect {
            try schema.validate(ToolArguments(["path": "a", name: value]))
        } throws: { error in
            guard case ToolError.invalidArgument(let failing, _) = error else { return false }
            return failing == name
        }
    }

    @Test("exports a JSON Schema object for providers")
    func jsonSchemaExport() throws {
        let exported = try #require(schema.jsonSchema.objectValue)
        #expect(exported["type"] == "object")
        #expect(exported["required"] == ["path"])
        let properties = try #require(exported["properties"]?.objectValue)
        #expect(properties["globs"] == ["type": "array", "items": ["type": "string"], "description": "Patterns"])
        #expect(properties["mode"]?.objectValue?["enum"] == ["fast", "full"])
    }
}
