import Foundation
import Testing
@testable import LocalOSXAi

@Suite("JSONValue")
struct JSONValueTests {
    @Test("parses every JSON primitive")
    func parsesPrimitives() throws {
        #expect(try JSONValue.parse("null") == .null)
        #expect(try JSONValue.parse("true") == .bool(true))
        #expect(try JSONValue.parse("42") == .number(42))
        #expect(try JSONValue.parse("4.5") == .number(4.5))
        #expect(try JSONValue.parse(#""hi""#) == .string("hi"))
    }

    @Test("keeps booleans distinct from numbers")
    func booleansAreNotNumbers() throws {
        let value = try JSONValue.parse(#"{"flag": true, "count": 1}"#)
        #expect(value.objectValue?["flag"] == .bool(true))
        #expect(value.objectValue?["count"] == .number(1))
    }

    @Test("parses nested structures")
    func parsesNested() throws {
        let value = try JSONValue.parse(#"{"a": [1, {"b": null}], "c": "d"}"#)
        #expect(value == ["a": [1, ["b": nil]], "c": "d"])
    }

    @Test("rejects invalid JSON")
    func rejectsInvalidJSON() {
        #expect(throws: (any Error).self) { try JSONValue.parse("{not json") }
    }

    @Test("serializes with sorted keys for deterministic output")
    func serializesDeterministically() {
        let value: JSONValue = ["b": 1, "a": "x", "c": [true, nil]]
        #expect(value.serialized() == #"{"a":"x","b":1,"c":[true,null]}"#)
    }

    @Test("round-trips through Codable")
    func roundTrips() throws {
        let value: JSONValue = ["name": "read_file", "args": ["path": "README.md", "limit": 10]]
        let data = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(JSONValue.self, from: data) == value)
    }
}
