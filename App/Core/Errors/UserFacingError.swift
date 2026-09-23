import Foundation
import OSLog

/// An error prepared for display: a short title, an understandable message and
/// an optional recovery suggestion.
///
/// ViewModels convert thrown errors with `init(_:title:category:)`, which also
/// logs the technical description. Views only ever see this type, so they
/// never format raw errors themselves. See docs/ai/errors.md.
struct UserFacingError: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?

    init(title: String, message: String, recoverySuggestion: String? = nil) {
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }

    /// Converts any error, preferring `LocalizedError` descriptions and falling
    /// back to a generic message so internal details never leak into the UI.
    init(_ error: any Error, title: String, category: LogCategory) {
        Logger(category: category).error("\(title, privacy: .public): \(String(describing: error))")
        let localized = error as? LocalizedError
        self.init(
            title: title,
            message: localized?.errorDescription ?? "Something went wrong. Details were written to the system log.",
            recoverySuggestion: localized?.recoverySuggestion
        )
    }
}
