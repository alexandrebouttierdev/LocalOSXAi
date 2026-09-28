import Foundation

/// How a tool call reads in the transcript: an icon and a human sentence
/// (“Read Makefile”, “Searched for “struct App””) instead of raw JSON, which
/// stays available in the expanded details.
struct ToolCallPresentation: Hashable, Sendable {
    /// What the call does, which the row shows as the icon's hue.
    enum Kind: Hashable, Sendable {
        case read, search, edit, write, command, git, other
    }

    let systemImage: String
    let title: String
    /// Secondary detail, e.g. the searched folder or file pattern.
    let detail: String?
    let kind: Kind

    init(_ call: ToolCallRecord) {
        let arguments = (try? JSONValue.parse(call.argumentsJSON))?.objectValue ?? [:]
        func string(_ key: String) -> String? {
            guard let value = arguments[key]?.stringValue, !value.isEmpty else { return nil }
            return value
        }
        let path = string("path")
        let place = path.flatMap { $0 == "." ? nil : "in \($0)" }

        switch call.name {
        case "read_file":
            self.init(.read, "doc.text", "Read \(path ?? "a file")")
        case "list_directory":
            self.init(.read, "folder", "Listed \(path.map { $0 == "." ? "project root" : $0 } ?? "project root")")
        case "search_files":
            self.init(.search, "doc.text.magnifyingglass", "Found files matching \(string("pattern") ?? "…")", detail: place)
        case "search_text":
            self.init(.search, "magnifyingglass", "Searched for “\(string("query") ?? "…")”",
                      detail: [place, string("file_pattern")].compactMap { $0 }.joined(separator: " · ").nilIfEmpty)
        case "edit_file":
            self.init(.edit, "pencil", "Edited \(path ?? "a file")")
        case "write_file":
            self.init(.write, "square.and.pencil", "Wrote \(path ?? "a file")")
        case "run_command":
            self.init(.command, "terminal", "Ran \(string("command").map { "“\($0)”" } ?? "a command")")
        case "git_status":
            self.init(.git, "arrow.triangle.branch", "Checked the Git status")
        case "git_diff":
            self.init(.git, "plusminus", "Read the Git diff", detail: place)
        case "git_log":
            self.init(.git, "clock.arrow.circlepath", "Read the Git history")
        default:
            self.init(.other, "wrench.and.screwdriver", call.name)
        }
    }

    private init(_ kind: Kind, _ systemImage: String, _ title: String, detail: String? = nil) {
        self.kind = kind
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
