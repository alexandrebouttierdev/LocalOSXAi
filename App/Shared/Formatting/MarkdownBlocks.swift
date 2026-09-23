import Foundation

/// Splits model output into Markdown blocks the UI can render natively.
///
/// Deliberately small: models mostly produce paragraphs, lists, headings and
/// fenced code. Inline styles (bold, code spans, links) are left to
/// `AttributedString(markdown:)`. Anything unrecognized stays a paragraph,
/// so no text is ever lost. Parsing is linear in the text length; it runs only
/// for messages that finished streaming.
enum MarkdownBlock: Hashable, Sendable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case listItem(marker: String, text: String)
    case code(language: String?, code: String)
    case rule
}

enum MarkdownParser {
    static func blocks(from text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: (language: String?, lines: [String])?

        func flushParagraph() {
            let joined = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { blocks.append(.paragraph(joined)) }
            paragraph = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if var open = code {
                if line.hasPrefix("```") {
                    blocks.append(.code(language: open.language, code: open.lines.joined(separator: "\n")))
                    code = nil
                } else {
                    open.lines.append(rawLine)
                    code = open
                }
                continue
            }
            if line.hasPrefix("```") {
                flushParagraph()
                let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                code = (language.isEmpty ? nil : language, [])
                continue
            }
            if line.isEmpty {
                flushParagraph()
                continue
            }
            if let heading = heading(line) {
                flushParagraph()
                blocks.append(heading)
            } else if line == "---" || line == "***" || line == "___" {
                flushParagraph()
                blocks.append(.rule)
            } else if let item = listItem(line) {
                flushParagraph()
                blocks.append(item)
            } else {
                paragraph.append(rawLine)
            }
        }
        // An unterminated fence (e.g. output cut by a limit) still renders as code.
        if let open = code {
            blocks.append(.code(language: open.language, code: open.lines.joined(separator: "\n")))
        }
        flushParagraph()
        return blocks
    }

    private static func heading(_ line: String) -> MarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return .heading(level: hashes, text: line.dropFirst(hashes + 1).trimmingCharacters(in: .whitespaces))
    }

    private static func listItem(_ line: String) -> MarkdownBlock? {
        for bullet in ["- ", "* ", "+ "] where line.hasPrefix(bullet) {
            return .listItem(marker: "•", text: String(line.dropFirst(2)))
        }
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty, digits.count <= 3, line.dropFirst(digits.count).hasPrefix(". ") {
            return .listItem(marker: "\(digits).", text: String(line.dropFirst(digits.count + 2)))
        }
        return nil
    }
}
