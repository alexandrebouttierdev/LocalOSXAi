import Foundation

/// Reads a file the user chose to attach to a message. Implemented in
/// `Infrastructure`, so the view model never touches the file system.
///
/// The user picks the file, so it may be outside the project: unlike the
/// agent's tools, attaching is not confined to the project root
/// (docs/security/permissions.md).
protocol AttachmentLoading: Sendable {
    /// - Throws: `AttachmentError`.
    func attachment(from file: URL, projectRoot: URL) async throws -> MessageAttachment
}
