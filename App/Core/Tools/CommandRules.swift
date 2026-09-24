import Foundation

/// A project's own rules for commands the agent runs, on top of
/// `CommandPolicy` (docs/security/command-execution.md).
///
/// They can only move commands between “allowed” and “requires approval”:
/// a blocked command stays blocked whatever the rules say.
struct CommandRules: Hashable, Sendable, Codable {
    enum Mode: String, Hashable, Sendable, Codable, CaseIterable {
        /// Read-only and test commands run; others ask first.
        case standard
        /// Every command asks first, even read-only ones.
        case askForEverything
    }

    var mode: Mode = .standard
    /// Command prefixes that run without asking in this project, compared
    /// word by word: `npm install` allows `npm install lodash`, not `npm ci`.
    var allowedPrefixes: [String] = []

    /// Normalizes a prefix typed by the user: single spaces, no surrounding
    /// blanks. Returns `nil` for an empty prefix.
    static func normalizedPrefix(_ prefix: String) -> String? {
        let words = prefix.split(whereSeparator: \.isWhitespace)
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    /// True when `words` (a parsed command segment) starts with an allowed prefix.
    func allows(words: [String]) -> Bool {
        allowedPrefixes.contains { prefix in
            let prefixWords = prefix.split(separator: " ").map(String.init)
            return !prefixWords.isEmpty && words.starts(with: prefixWords)
        }
    }

    /// True when every segment of `command` starts with an allowed prefix.
    func allows(command: String) -> Bool {
        guard let parsed = ShellCommandParser.parse(command), !parsed.segments.isEmpty else { return false }
        return parsed.segments.allSatisfy { allows(words: $0.words) }
    }

    /// The rule to offer when the user approves `command`: its program and,
    /// for tools with subcommands, the subcommand (`npm install`, `git commit`).
    /// `nil` when the command is not a single plain invocation.
    static func suggestedPrefix(for command: String) -> String? {
        guard let parsed = ShellCommandParser.parse(command), !parsed.hasDynamicSyntax,
              parsed.segments.count == 1, let segment = parsed.segments.first,
              segment.redirections.isEmpty, let program = segment.words.first,
              !program.contains("=") else { return nil }
        if segment.words.count > 1, let subcommand = segment.words.dropFirst().first,
           !subcommand.hasPrefix("-"), !subcommand.contains("/"), !subcommand.contains(".") {
            return "\(program) \(subcommand)"
        }
        return program
    }
}
