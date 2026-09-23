import Foundation
import Testing
@testable import LocalOSXAi

@Suite("PartialJSON")
struct PartialJSONTests {
    @Test("reads a complete string value from partial JSON")
    func readsValues() {
        #expect(PartialJSON.string(forKey: "path", in: #"{"path": "src/a \"b\".html", "content": "<ht"#) == #"src/a "b".html"#)
        #expect(PartialJSON.string(forKey: "path", in: #"{"content":"x","path":"b.txt"}"#) == "b.txt")
    }

    @Test("an incomplete or missing value is nil")
    func incomplete() {
        #expect(PartialJSON.string(forKey: "path", in: #"{"path": "src/inde"#) == nil)
        #expect(PartialJSON.string(forKey: "path", in: #"{"content": "x"}"#) == nil)
        #expect(PartialJSON.string(forKey: "path", in: #"{"path": 3}"#) == nil)
    }

    @Test("long string values are shortened while the JSON stays valid")
    func compacting() throws {
        let json = JSONValue.object(["path": "index.html", "content": .string(String(repeating: "a", count: 5_000))]).serialized()
        let compacted = PartialJSON.compactingLongStrings(in: json, maxLength: 100)
        let object = try #require(try JSONValue.parse(compacted).objectValue)
        #expect(object["path"] == "index.html")
        #expect(object["content"]?.stringValue?.contains("5000 characters") == true)
        #expect(compacted.count < 300)
        #expect(PartialJSON.compactingLongStrings(in: "{broken", maxLength: 1) == "{broken")
    }
}
