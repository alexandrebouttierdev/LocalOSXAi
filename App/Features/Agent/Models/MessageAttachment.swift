import Foundation

/// A file the user attached to a message: its text, read when it was attached.
///
/// The content is kept with the message, so the conversation replays the same
/// text even if the file changes or disappears later (docs/ai/attachments.md).
struct MessageAttachment: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    /// File name, shown on the chip.
    let name: String
    /// Relative to the project root for a project file, else absolute.
    let path: String
    let content: String
    /// Size of the file on disk.
    let byteCount: Int
    /// Only the first `maxCharacters` characters were kept.
    let isTruncated: Bool

    init(id: UUID = UUID(), name: String, path: String, content: String, byteCount: Int, isTruncated: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.content = content
        self.byteCount = byteCount
        self.isTruncated = isTruncated
    }

    /// About 25K tokens: a large source file, not a whole log or dump.
    static let maxCharacters = 100_000
    /// Larger files are refused before being read.
    static let maxFileBytes = 2_000_000
    static let maxPerMessage = 10

    /// Extensions of images, which need a vision model: planned, refused for now.
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp"]

    /// Builds an attachment from a file's text, keeping at most `maxCharacters`.
    static func make(name: String, path: String, text: String, byteCount: Int) -> MessageAttachment {
        let isTruncated = text.count > maxCharacters
        return MessageAttachment(name: name, path: path, content: isTruncated ? String(text.prefix(maxCharacters)) : text,
                                 byteCount: byteCount, isTruncated: isTruncated)
    }

    /// Where a file is shown and told to the model: relative inside the
    /// project, so paths match the ones the agent's tools use.
    static func displayPath(of file: URL, projectRoot: URL) -> String {
        let path = file.standardizedFileURL.path
        let root = projectRoot.standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }
}

/// Why a file could not be attached.
enum AttachmentError: Error, Hashable, Sendable {
    case notAFile(name: String)
    case image(name: String)
    case notText(name: String)
    case tooLarge(name: String, bytes: Int)
    case unreadable(name: String)
    case tooMany(limit: Int)
}

extension AttachmentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAFile(let name): "“\(name)” is a folder or not a regular file."
        case .image(let name): "“\(name)” is an image. Images cannot be attached yet."
        case .notText(let name): "“\(name)” is not a text file."
        case let .tooLarge(name, bytes):
            "“\(name)” is too large (\(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)))."
        case .unreadable(let name): "“\(name)” could not be read."
        case .tooMany(let limit): "A message can have at most \(limit) files."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAFile: "Attach the files inside it instead."
        case .image: "Describe the image in your message, or attach a text file."
        case .notText: "Only text and source files can be attached."
        case .tooLarge:
            "Attach a smaller file, or ask the agent to read the part you need with its tools."
        case .unreadable: "Check that the file exists and that you can open it."
        case .tooMany: "Send the others in a next message."
        }
    }
}
