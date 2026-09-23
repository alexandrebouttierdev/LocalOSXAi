import Foundation

/// The subset of JSON Schema used to describe tool parameters.
///
/// Only flat objects of primitive (or primitive-array) properties are
/// supported. That is deliberate: small local models follow flat schemas far
/// more reliably than nested ones, and a restricted schema can be validated
/// without a third-party JSON Schema library. See docs/ai/tools.md.
struct ToolParameterSchema: Sendable, Hashable {
    enum PropertyType: String, Sendable, Hashable {
        case string
        case integer
        case number
        case boolean
        case stringArray
    }

    struct Property: Sendable, Hashable {
        var type: PropertyType
        var description: String
        /// Allowed values for `.string` properties.
        var allowedValues: [String]?

        init(_ type: PropertyType, _ description: String, allowedValues: [String]? = nil) {
            self.type = type
            self.description = description
            self.allowedValues = allowedValues
        }
    }

    var properties: [String: Property]
    var required: [String]

    init(properties: [String: Property] = [:], required: [String] = []) {
        self.properties = properties
        self.required = required
    }

    static let empty = ToolParameterSchema()
}

// MARK: - Validation

extension ToolParameterSchema {
    /// Validates arguments before a tool executes.
    ///
    /// Unknown arguments are rejected rather than ignored: a misspelled
    /// optional parameter (`max_results` for `limit`) would otherwise be
    /// dropped silently while the model believes it was applied.
    func validate(_ arguments: ToolArguments) throws(ToolError) {
        for name in required {
            guard let value = arguments.values[name], !value.isNull else { throw .missingArgument(name) }
        }
        for (name, value) in arguments.values.sorted(by: { $0.key < $1.key }) {
            guard let property = properties[name] else { throw .unexpectedArgument(name) }
            if value.isNull { continue }
            try Self.check(value, against: property, name: name)
        }
    }

    private static func check(_ value: JSONValue, against property: Property, name: String) throws(ToolError) {
        switch property.type {
        case .string:
            guard let string = value.stringValue else { throw .invalidArgument(name: name, reason: "expected a string") }
            if let allowed = property.allowedValues, !allowed.contains(string) {
                throw .invalidArgument(name: name, reason: "expected one of \(allowed.joined(separator: ", "))")
            }
        case .integer:
            guard let number = value.numberValue, number.rounded() == number else {
                throw .invalidArgument(name: name, reason: "expected an integer")
            }
        case .number:
            guard value.numberValue != nil else { throw .invalidArgument(name: name, reason: "expected a number") }
        case .boolean:
            guard value.boolValue != nil else { throw .invalidArgument(name: name, reason: "expected a boolean") }
        case .stringArray:
            guard let array = value.arrayValue, array.allSatisfy({ $0.stringValue != nil }) else {
                throw .invalidArgument(name: name, reason: "expected an array of strings")
            }
        }
    }
}

// MARK: - JSON Schema export

extension ToolParameterSchema {
    /// JSON Schema representation sent to providers in tool definitions.
    var jsonSchema: JSONValue {
        var encodedProperties: [String: JSONValue] = [:]
        for (name, property) in properties {
            var entry: [String: JSONValue] = ["description": .string(property.description)]
            switch property.type {
            case .stringArray:
                entry["type"] = "array"
                entry["items"] = ["type": "string"]
            default:
                entry["type"] = .string(property.type.rawValue)
            }
            if let allowed = property.allowedValues {
                entry["enum"] = .array(allowed.map(JSONValue.string))
            }
            encodedProperties[name] = .object(entry)
        }
        return [
            "type": "object",
            "properties": .object(encodedProperties),
            "required": .array(required.map(JSONValue.string))
        ]
    }
}
