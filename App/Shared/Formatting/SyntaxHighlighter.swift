import Foundation

/// A small, language-aware tokenizer for coloring code one line at a time,
/// like Linear's diffs: keywords, strings, numbers, comments, types, markup
/// tags and attributes.
///
/// It is deliberately approximate: no parser, no state across lines (a line
/// inside a block comment is colored as code). Its only job is readability;
/// it never changes the text, so the concatenated tokens are the line.
enum SyntaxHighlighter {
    enum Kind: Hashable, Sendable {
        case plain, keyword, string, number, comment, type, tag, attribute
    }

    struct Token: Hashable, Sendable {
        let kind: Kind
        let text: String
    }

    /// What a file's extension says about its syntax.
    struct Language: Hashable, Sendable {
        var lineComments: [String] = ["//"]
        /// `<tag attr="…">` markup (HTML, XML, JSX…).
        var hasMarkup = false

        static let cLike = Language()
        static let hashComments = Language(lineComments: ["#"])
        static let markup = Language(lineComments: [], hasMarkup: true)
        static let plainText = Language(lineComments: [])

        static func forPath(_ path: String) -> Language {
            let name = (path as NSString).lastPathComponent.lowercased()
            if ["makefile", "dockerfile", "gemfile", "podfile"].contains(name) { return .hashComments }
            switch (name as NSString).pathExtension {
            case "html", "htm", "xml", "svg", "vue", "plist", "xib", "storyboard": return .markup
            case "jsx", "tsx": return Language(lineComments: ["//"], hasMarkup: true)
            case "py", "sh", "bash", "zsh", "rb", "yml", "yaml", "toml", "pl", "r", "conf", "ini", "cfg", "env", "gitignore":
                return .hashComments
            case "md", "markdown", "txt", "csv", "json", "log", "": return .plainText
            case "sql": return Language(lineComments: ["--"])
            default: return .cLike
            }
        }
    }

    /// Keywords of the common languages at once: a word is rarely a keyword
    /// in one language and an ordinary name in a file of another.
    static let keywords: Set<String> = [
        "import", "from", "export", "default", "as", "let", "var", "const", "func", "function", "fn", "def", "class",
        "struct", "enum", "protocol", "interface", "type", "extension", "impl", "trait", "return", "if", "else", "elif",
        "for", "while", "do", "switch", "case", "break", "continue", "guard", "defer", "in", "of", "is", "new", "try",
        "catch", "throw", "throws", "await", "async", "static", "private", "public", "internal", "fileprivate",
        "protected", "final", "override", "init", "self", "Self", "super", "this", "nil", "null", "undefined", "true",
        "false", "None", "True", "False", "and", "or", "not", "with", "yield", "lambda", "pub", "mut", "use", "mod",
        "package", "go", "select", "where", "some", "any", "typeof", "instanceof", "extends", "implements", "void",
        "int", "float", "double", "bool", "string", "char", "long", "unsigned", "echo", "then", "fi", "done", "esac"
    ]

    static func tokens(in line: String, language: Language) -> [Token] {
        var scanner = Scanner(characters: Array(line), language: language)
        while !scanner.isAtEnd { scanner.scanNext() }
        return scanner.tokens
    }

    /// One pass over a line; each `scan…` method consumes one token.
    private struct Scanner {
        let characters: [Character]
        let language: Language
        var index = 0
        var tokens: [Token] = []
        /// Between `<tag` and `>` in markup, where names before `=` are attributes.
        var insideTag = false

        var isAtEnd: Bool { index >= characters.count }

        mutating func scanNext() {
            let character = characters[index]
            if scanComment() { return }
            if character == "\"" || character == "'" || character == "`" {
                scanString(closingWith: character)
            } else if character.isNumber, index == 0 || !SyntaxHighlighter.isIdentifier(characters[index - 1]) {
                scanNumber()
            } else if SyntaxHighlighter.isIdentifierStart(character) {
                scanWord()
            } else {
                if character == ">" { insideTag = false }
                emit(language.hasMarkup && (character == "<" || character == ">") ? .tag : .plain, until: index + 1)
            }
        }

        /// A markup comment, or a line comment to the end of the line. `#`
        /// starts a comment only at the start of a word, so `url#anchor` is not one.
        private mutating func scanComment() -> Bool {
            if language.hasMarkup, starts(with: "<!--", at: index) {
                let close = (index..<characters.count).first { starts(with: "-->", at: $0) }.map { $0 + 3 }
                emit(.comment, until: close ?? characters.count)
                return true
            }
            let startsWord = index == 0 || characters[index - 1].isWhitespace || language.lineComments != ["#"]
            guard startsWord, language.lineComments.contains(where: { starts(with: $0, at: index) }) else { return false }
            emit(.comment, until: characters.count)
            return true
        }

        private mutating func scanString(closingWith quote: Character) {
            var end = index + 1
            while end < characters.count, characters[end] != quote {
                end += characters[end] == "\\" ? 2 : 1
            }
            emit(.string, until: min(end + 1, characters.count))
        }

        private mutating func scanNumber() {
            var end = index + 1
            while end < characters.count,
                  characters[end].isNumber || characters[end].isLetter || characters[end] == "." || characters[end] == "_" {
                end += 1
            }
            emit(.number, until: end)
        }

        private mutating func scanWord() {
            var end = index + 1
            while end < characters.count,
                  SyntaxHighlighter.isIdentifier(characters[end]) || characters[end] == "-" && insideTag {
                end += 1
            }
            let word = String(characters[index..<end])
            let previous = characters[..<index].last { !$0.isWhitespace }
            let kind: Kind
            if language.hasMarkup, previous == "<" || (previous == "/" && index >= 2 && characters[index - 2] == "<") {
                kind = .tag
                insideTag = true
            } else if insideTag, end < characters.count, characters[end] == "=" {
                kind = .attribute
            } else if SyntaxHighlighter.keywords.contains(word) {
                kind = .keyword
            } else {
                kind = characters[index].isUppercase ? .type : .plain
            }
            emit(kind, until: end)
        }

        /// Adds `characters[index..<end]` as a token, merged with the previous one of the same kind.
        private mutating func emit(_ kind: Kind, until end: Int) {
            let text = String(characters[index..<end])
            if let last = tokens.last, last.kind == kind {
                tokens[tokens.count - 1] = Token(kind: kind, text: last.text + text)
            } else {
                tokens.append(Token(kind: kind, text: text))
            }
            index = end
        }

        private func starts(with prefix: String, at position: Int) -> Bool {
            let prefix = Array(prefix)
            return position + prefix.count <= characters.count && Array(characters[position..<position + prefix.count]) == prefix
        }
    }

    fileprivate static func isIdentifierStart(_ character: Character) -> Bool {
        character.isLetter || character == "_" || character == "$" || character == "@"
    }

    fileprivate static func isIdentifier(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "$"
    }
}
