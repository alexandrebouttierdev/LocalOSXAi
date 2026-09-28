import Foundation

/// A dotted version such as “0.0.0.1”, read from the app's Info.plist or a
/// release tag (“v0.0.0.1”), compared number by number.
///
/// Any number of components is accepted, and missing ones count as zero, so
/// “1.2” equals “1.2.0” and “0.0.1” is newer than “0.0.0.1”. Text after a
/// hyphen (“-build.12” in a pre-release tag) is kept as `suffix` but ignored
/// when comparing: the update check only ever sees full releases.
struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    let components: [Int]
    let suffix: String?

    /// Returns `nil` for anything that is not dotted non-negative numbers,
    /// optionally prefixed with “v” — a malformed tag never counts as newer.
    init?(_ text: String) {
        var trimmed = Substring(text.trimmingCharacters(in: .whitespaces))
        if trimmed.first == "v" || trimmed.first == "V" { trimmed = trimmed.dropFirst() }
        let parts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = parts.first, !core.isEmpty else { return nil }
        var numbers: [Int] = []
        for part in core.split(separator: ".", omittingEmptySubsequences: false) {
            // ASCII digits only: `Int` alone would accept “+1”.
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        components = numbers
        suffix = parts.count > 1 ? String(parts[1]) : nil
    }

    /// “0.0.0.1”, without the suffix.
    var description: String { components.map(String.init).joined(separator: ".") }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let (left, right) = padded(lhs, rhs)
        return left.lexicographicallyPrecedes(right)
    }

    /// Equal numbers, whatever the suffix or trailing zeros.
    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let (left, right) = padded(lhs, rhs)
        return left == right
    }

    func hash(into hasher: inout Hasher) {
        var significant = components
        while significant.last == 0 { significant.removeLast() }
        hasher.combine(significant)
    }

    private static func padded(_ lhs: AppVersion, _ rhs: AppVersion) -> ([Int], [Int]) {
        let count = max(lhs.components.count, rhs.components.count)
        return (lhs.components + Array(repeating: 0, count: count - lhs.components.count),
                rhs.components + Array(repeating: 0, count: count - rhs.components.count))
    }
}
