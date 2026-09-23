import Foundation

/// How a tool call reads in the transcript: an icon and a human sentence
/// (“Read Makefile”, “Searched for “struct App””) instead of raw JSON, which
/// stays available in the expanded details.
struct ToolCallPresentation: Hashable, Sendable {
    let systemImage: String
    let title: String
    /// Secondary detail, e.g. the searched folder or file pattern.
    let detail: String?

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
            self.init(systemImage: "doc.text", title: "Read \(path ?? "a file")", detail: nil)
        case "list_directory":
            self.init(systemImage: "folder", title: "Listed \(path.map { $0 == "." ? "project root" : $0 } ?? "project root")", detail: nil)
        case "search_files":
            self.init(systemImage: "doc.text.magnifyingglass", title: "Found files matching \(string("pattern") ?? "…")", detail: place)
        case "search_text":
            self.init(systemImage: "magnifyingglass", title: "Searched for “\(string("query") ?? "…")”",
                      detail: [place, string("file_pattern")].compactMap { $0 }.joined(separator: " · ").nilIfEmpty)
        case "edit_file":
            self.init(systemImage: "pencil", title: "Edited \(path ?? "a file")", detail: nil)
        case "write_file":
            self.init(systemImage: "square.and.pencil", title: "Wrote \(path ?? "a file")", detail: nil)
        default:
            self.init(systemImage: "wrench.and.screwdriver", title: call.name, detail: nil)
        }
    }

    private init(systemImage: String, title: String, detail: String?) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
