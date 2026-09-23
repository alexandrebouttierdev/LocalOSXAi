import Foundation

/// Arguments of a tool call, decoded from the model's raw JSON.
///
/// Typed accessors throw `ToolError` with a message meant to be sent back to
/// the model, so a tool implementation never needs to format validation
/// errors itself.
struct ToolArguments: Sendable, Hashable {
    let values: [String: JSONValue]

    init(_ values: [String: JSONValue] = [:]) {
        self.values = values
    }

    /// Parses arguments produced by a model.
    ///
    /// An empty or whitespace-only string is accepted as “no arguments”
    /// because several local models emit `""` for parameterless tools.
    ///
    /// - Throws: `ToolError.malformedArguments` when the text is not a JSON object.
    static func parse(_ raw: String) throws(ToolError) -> ToolArguments {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ToolArguments() }

        let value: JSONValue
        do {
            value = try JSONValue.parse(trimmed)
        } catch {
            throw .malformedArguments(String(trimmed.prefix(200)))
        }
        guard let object = value.objectValue else {
            throw .malformedArguments("expected a JSON object, got \(String(trimmed.prefix(200)))")
        }
        return ToolArguments(object)
    }

    // MARK: Typed access

    func string(_ key: String) throws(ToolError) -> String {
        guard let value = try optionalString(key) else { throw .missingArgument(key) }
        return value
    }

    func optionalString(_ key: String) throws(ToolError) -> String? {
        guard let value = present(key) else { return nil }
        guard let string = value.stringValue else { throw .invalidArgument(name: key, reason: "expected a string") }
        return string
    }

    func int(_ key: String) throws(ToolError) -> Int {
        guard let value = try optionalInt(key) else { throw .missingArgument(key) }
        return value
    }

    func optionalInt(_ key: String) throws(ToolError) -> Int? {
        guard let value = present(key) else { return nil }
        guard let number = value.numberValue, number.rounded() == number, abs(number) <= Double(Int32.max) else {
            throw .invalidArgument(name: key, reason: "expected an integer")
        }
        return Int(number)
    }

    func bool(_ key: String) throws(ToolError) -> Bool {
        guard let value = try optionalBool(key) else { throw .missingArgument(key) }
        return value
    }

    func optionalBool(_ key: String) throws(ToolError) -> Bool? {
        guard let value = present(key) else { return nil }
        guard let bool = value.boolValue else { throw .invalidArgument(name: key, reason: "expected a boolean") }
        return bool
    }

    /// Treats explicit `null` like an absent key: models often send `null`
    /// for optional parameters they do not want to set.
    private func present(_ key: String) -> JSONValue? {
        guard let value = values[key], !value.isNull else { return nil }
        return value
    }
}
