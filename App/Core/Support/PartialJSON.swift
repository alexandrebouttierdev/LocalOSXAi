import Foundation

/// Reads values out of JSON that may still be incomplete (streaming).
enum PartialJSON {
    /// The string value of the first `"key": "…"` pair, if its value is
    /// complete in `text`. Handles escaped quotes; returns `nil` otherwise.
    static func string(forKey key: String, in text: String) -> String? {
        guard let keyRange = text.range(of: "\"\(key)\"") else { return nil }
        var rest = text[keyRange.upperBound...].drop { $0 == " " || $0 == "\n" || $0 == "\t" }
        guard rest.first == ":" else { return nil }
        rest = rest.dropFirst().drop { $0 == " " || $0 == "\n" || $0 == "\t" }
        guard rest.first == "\"" else { return nil }
        var value = ""
        var escaping = false
        for character in rest.dropFirst() {
            if escaping {
                value.append(character == "n" ? "\n" : character == "t" ? "\t" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "\"" {
                return value
            } else {
                value.append(character)
            }
        }
        return nil
    }

    /// Shortens long string values in a JSON object while keeping it valid
    /// JSON: `"content": "<5 000 characters>"` becomes a head plus a marker.
    /// Used to keep large tool-call arguments (whole files) from filling the
    /// context once the call has been executed. Non-objects are returned as is.
    static func compactingLongStrings(in json: String, maxLength: Int) -> String {
        guard json.count > maxLength, let object = (try? JSONValue.parse(json))?.objectValue else { return json }
        let compacted = object.mapValues { value -> JSONValue in
            guard let string = value.stringValue, string.count > maxLength else { return value }
            return .string(String(string.prefix(maxLength / 2)) + "… [\(string.count) characters, shortened to save context]")
        }
        return JSONValue.object(compacted).serialized()
    }
}
