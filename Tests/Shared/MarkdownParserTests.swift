import Foundation
import Testing
@testable import LocalOSXAi

@Suite("MarkdownParser")
struct MarkdownParserTests {
    @Test("paragraphs are separated by blank lines and keep soft line breaks")
    func paragraphs() {
        #expect(MarkdownParser.blocks(from: "One\ntwo\n\nThree") == [.paragraph("One\ntwo"), .paragraph("Three")])
    }

    @Test("fenced code keeps its language and exact content")
    func codeBlocks() {
        let text = "Run:\n```swift\nlet x = 1\n    indented\n```\nDone"
        #expect(MarkdownParser.blocks(from: text) == [
            .paragraph("Run:"), .code(language: "swift", code: "let x = 1\n    indented"), .paragraph("Done")
        ])
    }

    @Test("an unterminated fence still renders as code")
    func unterminatedFence() {
        #expect(MarkdownParser.blocks(from: "```\nhalf") == [.code(language: nil, code: "half")])
    }

    @Test("headings, lists and rules are recognized")
    func structure() {
        let text = "# Title\n- one\n* two\n12. twelve\n---\n#hashtag"
        #expect(MarkdownParser.blocks(from: text) == [
            .heading(level: 1, text: "Title"),
            .listItem(marker: "•", text: "one"),
            .listItem(marker: "•", text: "two"),
            .listItem(marker: "12.", text: "twelve"),
            .rule,
            .paragraph("#hashtag")
        ])
    }

    @Test("markdown inside code is not interpreted")
    func codeIsLiteral() {
        #expect(MarkdownParser.blocks(from: "```\n# not a heading\n- not a list\n```")
                == [.code(language: nil, code: "# not a heading\n- not a list")])
    }

    @Test("empty text has no blocks")
    func empty() {
        #expect(MarkdownParser.blocks(from: "\n\n").isEmpty)
    }
}

@Suite("ToolCallPresentation")
struct ToolCallPresentationTests {
    private func present(_ name: String, _ arguments: String) -> ToolCallPresentation {
        ToolCallPresentation(ToolCallRecord(id: "1", name: name, argumentsJSON: arguments, status: .succeeded))
    }

    @Test("tool calls read as human sentences")
    func sentences() {
        #expect(present("read_file", #"{"path":"Makefile"}"#).title == "Read Makefile")
        #expect(present("list_directory", #"{"path":"."}"#).title == "Listed project root")
        #expect(present("list_directory", #"{"path":"Sources"}"#).title == "Listed Sources")
        #expect(present("edit_file", #"{"path":"a.swift","old_string":"x","new_string":"y"}"#).title == "Edited a.swift")
        #expect(present("write_file", #"{"path":"b.md","content":""}"#).title == "Wrote b.md")
        #expect(present("search_files", #"{"pattern":"*.swift"}"#).title == "Found files matching *.swift")
    }

    @Test("search details mention the folder and file pattern")
    func searchDetail() {
        let presentation = present("search_text", #"{"query":"TODO","path":"Sources","file_pattern":"*.swift"}"#)
        #expect(presentation.title == "Searched for “TODO”")
        #expect(presentation.detail == "in Sources · *.swift")
    }

    @Test("malformed arguments and unknown tools still render")
    func fallbacks() {
        #expect(present("read_file", "{broken").title == "Read a file")
        #expect(present("custom_tool", "{}").title == "custom_tool")
    }
}

@Suite("ProjectBadge")
struct ProjectBadgeTests {
    @Test("a project always gets the same color, within the palette")
    func stableColor() {
        let index = ProjectBadge.paletteIndex(for: "LocalOSXAi")
        #expect(index == ProjectBadge.paletteIndex(for: "LocalOSXAi"))
        #expect(AppColors.projectPalette.indices.contains(index))
        #expect(AppColors.projectPalette.indices.contains(ProjectBadge.paletteIndex(for: "")))
    }
}
