import Foundation

/// Reads attachments from disk: regular text files up to
/// `MessageAttachment.maxFileBytes`, following symlinks.
struct LocalAttachmentLoader: AttachmentLoading {
    func attachment(from file: URL, projectRoot: URL) async throws -> MessageAttachment {
        let name = file.lastPathComponent
        guard !MessageAttachment.imageExtensions.contains(file.pathExtension.lowercased()) else {
            throw AttachmentError.image(name: name)
        }
        let resolved = file.resolvingSymlinksInPath()
        let values = try? resolved.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true else { throw AttachmentError.notAFile(name: name) }
        let bytes = values?.fileSize ?? 0
        guard bytes <= MessageAttachment.maxFileBytes else { throw AttachmentError.tooLarge(name: name, bytes: bytes) }

        let data: Data
        do {
            data = try Data(contentsOf: resolved)
        } catch {
            throw AttachmentError.unreadable(name: name)
        }
        // A NUL byte never appears in text: this rejects binaries that
        // happen to decode as UTF-8.
        guard !data.contains(0), let text = String(data: data, encoding: .utf8) else {
            throw AttachmentError.notText(name: name)
        }
        return .make(name: name, path: MessageAttachment.displayPath(of: resolved, projectRoot: projectRoot.resolvingSymlinksInPath()),
                     text: text, byteCount: data.count)
    }
}
