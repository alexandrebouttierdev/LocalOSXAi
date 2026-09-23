import Foundation
import Testing
@testable import LocalOSXAi

@Suite("ToolArguments")
struct ToolArgumentsTests {
    @Test("empty or blank raw arguments mean no arguments", arguments: ["", "  ", "\n"])
    func emptyArguments(raw: String) throws {
        #expect(try ToolArguments.parse(raw) == ToolArguments())
    }

    @Test("malformed JSON is reported as malformedArguments")
    func malformedJSON() {
        #expect(throws: ToolError.malformedArguments(#"{"path":"#)) {
            try ToolArguments.parse(#"{"path": "#)
        }
    }

    @Test("non-object JSON is rejected")
    func nonObjectJSON() {
        #expect {
            try ToolArguments.parse("[1, 2]")
        } throws: { error in
            guard case ToolError.malformedArguments = error else { return false }
            return true
        }
    }

    @Test("typed accessors return present values")
    func typedAccess() throws {
        let arguments = try ToolArguments.parse(#"{"path": "a.swift", "limit": 20, "recursive": true}"#)
        #expect(try arguments.string("path") == "a.swift")
        #expect(try arguments.int("limit") == 20)
        #expect(try arguments.bool("recursive") == true)
    }

    @Test("missing required value throws missingArgument")
    func missingValue() {
        #expect(throws: ToolError.missingArgument("path")) { try ToolArguments().string("path") }
    }

    @Test("explicit null is treated as absent")
    func nullIsAbsent() throws {
        let arguments = ToolArguments(["limit": .null])
        #expect(try arguments.optionalInt("limit") == nil)
        #expect(throws: ToolError.missingArgument("limit")) { try arguments.int("limit") }
    }

    @Test("wrong types are rejected with the argument name")
    func wrongTypes() {
        let arguments = ToolArguments(["path": 3, "limit": "ten", "flag": "yes"])
        #expect(throws: ToolError.invalidArgument(name: "path", reason: "expected a string")) { try arguments.string("path") }
        #expect(throws: ToolError.invalidArgument(name: "limit", reason: "expected an integer")) { try arguments.int("limit") }
        #expect(throws: ToolError.invalidArgument(name: "flag", reason: "expected a boolean")) { try arguments.bool("flag") }
    }

    @Test("non-integral numbers are not integers")
    func nonIntegralNumber() {
        #expect(throws: ToolError.invalidArgument(name: "limit", reason: "expected an integer")) {
            try ToolArguments(["limit": 2.5]).int("limit")
        }
    }
}
