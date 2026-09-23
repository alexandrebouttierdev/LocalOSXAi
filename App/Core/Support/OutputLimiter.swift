import Foundation

/// Keeps model-facing text within a size budget, preserving the beginning
/// and the end, which usually carry the most information (a command's
/// invocation and its final error, a file's header and its latest lines).
enum OutputLimiter {
    static func limit(_ text: String, maxCharacters: Int, note: String? = nil) -> String {
        guard text.count > maxCharacters else { return text }
        let half = maxCharacters / 2
        let omitted = text.count - 2 * half
        let marker = note ?? "\(omitted) characters omitted"
        return String(text.prefix(half)) + "\n… [\(marker)] …\n" + String(text.suffix(half))
    }
}
