import Foundation

/// A shell command line split into simple commands, as the shell would.
struct ParsedCommand: Hashable, Sendable {
    /// One simple command: its words after quote removal, and where its
    /// output is redirected.
    struct Segment: Hashable, Sendable {
        var words: [String] = []
        var redirections: [String] = []
        /// True when this segment receives the previous segment's output (`|`).
        var isPiped = false
    }

    var segments: [Segment]
    /// Syntax the policy cannot reason about safely: command or process
    /// substitution, variable expansion, here-documents, subshells.
    var hasDynamicSyntax: Bool
}

/// Splits command lines with POSIX shell quoting rules.
///
/// It is not a shell: it only needs to tell the command policy *which
/// programs run with which arguments*. Anything whose meaning depends on
/// runtime expansion is flagged as dynamic so the policy asks the user
/// instead of guessing (docs/security/command-execution.md).
enum ShellCommandParser {
    /// Returns `nil` for unbalanced quotes or an empty command.
    static func parse(_ command: String) -> ParsedCommand? {
        var tokenizer = Tokenizer(characters: Array(command)[...])
        guard tokenizer.run() else { return nil }
        var parsed = tokenizer.parsed
        parsed.segments.removeAll { $0.words.isEmpty && $0.redirections.isEmpty }
        return parsed.segments.isEmpty ? nil : parsed
    }

    private struct Tokenizer {
        var characters: ArraySlice<Character>
        var parsed = ParsedCommand(segments: [ParsedCommand.Segment()], hasDynamicSyntax: false)
        private var word = ""
        private var hasWord = false
        private var pendingRedirection = false

        init(characters: ArraySlice<Character>) {
            self.characters = characters
        }

        /// Consumes the whole line. Returns `false` on unbalanced quotes.
        mutating func run() -> Bool {
            while let character = characters.popFirst() {
                switch character {
                case "'", "\"": guard quoted(by: character) else { return false }
                case "\\": escaped()
                case "$", "`", "(", ")", "{", "}":
                    parsed.hasDynamicSyntax = true
                    append(character)
                case " ", "\t", "\n": endWord()
                case ";": newSegment(piped: false)
                case "&": ampersand()
                case "|": pipe()
                case ">", "<": redirection(character)
                default: append(character)
                }
            }
            endWord()
            return true
        }

        private mutating func append(_ character: Character) {
            word.append(character)
            hasWord = true
        }

        private mutating func quoted(by quote: Character) -> Bool {
            quote == "'" ? singleQuoted() : doubleQuoted()
        }

        private mutating func singleQuoted() -> Bool {
            hasWord = true
            guard let end = characters.firstIndex(of: "'") else { return false }
            word += characters[..<end]
            characters = characters[characters.index(after: end)...]
            return true
        }

        private mutating func doubleQuoted() -> Bool {
            hasWord = true
            while let inner = characters.popFirst() {
                if inner == "\"" { return true }
                if inner == "\\", let escaped = characters.popFirst() {
                    word.append(escaped)
                    continue
                }
                if inner == "$" || inner == "`" { parsed.hasDynamicSyntax = true }
                word.append(inner)
            }
            return false
        }

        private mutating func escaped() {
            if let escaped = characters.popFirst() { append(escaped) }
        }

        private mutating func ampersand() {
            if characters.first == "&" { characters.removeFirst() }
            if characters.first == ">" {
                // `&>` redirects both streams to a file.
                characters.removeFirst()
                endWord()
                pendingRedirection = true
            } else {
                newSegment(piped: false)
            }
        }

        private mutating func pipe() {
            if characters.first == "|" {
                characters.removeFirst()
                newSegment(piped: false)
            } else {
                newSegment(piped: true)
            }
        }

        private mutating func redirection(_ character: Character) {
            // A file descriptor number directly before the operator (`2>`) belongs to it.
            if hasWord, word.allSatisfy(\.isNumber) {
                word = ""
                hasWord = false
            } else {
                endWord()
            }
            if character == "<", characters.first == "<" { parsed.hasDynamicSyntax = true }
            while characters.first == ">" || characters.first == "<" { characters.removeFirst() }
            if characters.first == "&" {
                // `2>&1` duplicates a descriptor: no file involved.
                characters.removeFirst()
                while let next = characters.first, next.isNumber || next == "-" { characters.removeFirst() }
            } else if character == ">" {
                pendingRedirection = true
            }
        }

        private mutating func endWord() {
            guard hasWord else { return }
            let last = parsed.segments.count - 1
            if pendingRedirection {
                parsed.segments[last].redirections.append(word)
                pendingRedirection = false
            } else {
                parsed.segments[last].words.append(word)
            }
            word = ""
            hasWord = false
        }

        private mutating func newSegment(piped: Bool) {
            endWord()
            parsed.segments.append(ParsedCommand.Segment(isPiped: piped))
        }
    }
}
