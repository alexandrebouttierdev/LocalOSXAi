import Foundation

/// A type-safe representation of an arbitrary JSON document.
///
/// Tool arguments, tool schemas and provider payloads are JSON whose shape is
/// only known at runtime (it is produced by a model). `JSONValue` lets that data
/// cross actor boundaries as a `Sendable` value and be inspected without
/// `[String: Any]` casts.
///
/// Numbers are stored as `Double`, matching JSON semantics. Integer accessors
/// on `ToolArguments` reject non-integral values explicitly.
enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Parsing and serialization

extension JSONValue {
    /// Parses a UTF-8 JSON string.
    ///
    /// - Throws: `DecodingError` when the text is not valid JSON.
    static func parse(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    /// Serializes the value with sorted keys so output is deterministic,
    /// which keeps tests and provider request logs stable.
    func serialized(prettyPrinted: Bool = false) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        // Encoding a JSONValue cannot fail: every case maps to a JSON primitive.
        guard let data = try? encoder.encode(self), let text = String(bytes: data, encoding: .utf8) else { return "null" }
        return text
    }
}

// MARK: - Accessors

extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var isNull: Bool { self == .null }
}

// MARK: - Codable

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Order matters: Bool must be tried before Double because some decoders
        // would otherwise coerce `true` to 1.
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

// MARK: - Literals

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral,
    ExpressibleByDictionaryLiteral {
    init(nilLiteral: ()) { self = .null }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(floatLiteral value: Double) { self = .number(value) }
    init(stringLiteral value: String) { self = .string(value) }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}
