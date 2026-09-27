import Foundation
import Testing
@testable import LocalOSXAi

@Suite("SyntaxHighlighter")
struct SyntaxHighlighterTests {
    private func kinds(_ line: String, _ path: String = "a.swift") -> [SyntaxHighlighter.Kind: [String]] {
        let tokens = SyntaxHighlighter.tokens(in: line, language: .forPath(path))
        #expect(tokens.map(\.text).joined() == line, "tokens must rebuild the line exactly")
        return Dictionary(grouping: tokens, by: \.kind).mapValues { $0.map { $0.text.trimmingCharacters(in: .whitespaces) } }
    }

    @Test("keywords, types, strings, numbers and comments in code")
    func code() {
        let result = kinds(#"let view = View(title: "Hi \"you\"", count: 42) // done"#)
        #expect(result[.keyword] == ["let"])
        #expect(result[.type] == ["View"])
        #expect(result[.string] == [#""Hi \"you\"""#])
        #expect(result[.number] == ["42"])
        #expect(result[.comment] == ["// done"])
    }

    @Test("markup tags and attributes, and HTML comments")
    func markup() {
        let result = kinds(#"<meta name="viewport" data-x="1"> <!-- note -->"#, "index.html")
        #expect(result[.tag]?.first == "<meta")
        #expect(result[.attribute] == ["name", "data-x"])
        #expect(result[.string] == [#""viewport""#, #""1""#])
        #expect(result[.comment] == ["<!-- note -->"])
    }

    @Test("hash comments only where the language uses them, and never inside a word")
    func hashComments() {
        #expect(kinds("x = 1  # set x", "run.py")[.comment] == ["# set x"])
        #expect(kinds("color: #fff;", "style.css")[.comment] == nil)
        #expect(kinds("url#anchor", "run.sh")[.comment] == nil)
    }

    @Test("digits inside names are not numbers, and plain text stays plain")
    func edges() {
        #expect(kinds("utf8 h1 v2", "a.swift")[.number] == nil)
        #expect(SyntaxHighlighter.tokens(in: "", language: .cLike).isEmpty)
        #expect(SyntaxHighlighter.Language.forPath("notes.md") == .plainText)
        #expect(SyntaxHighlighter.Language.forPath("App.tsx").hasMarkup)
    }
}
