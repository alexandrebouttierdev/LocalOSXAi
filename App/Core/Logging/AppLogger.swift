import Foundation
import OSLog

/// Log categories, one per subsystem area. Filter in Console.app with
/// `subsystem:dev.localosxai.app category:<name>`.
enum LogCategory: String, CaseIterable, Sendable {
    case agent
    case provider
    case tools
    case terminal
    case git
    case persistence
    case ui
}

extension Logger {
    static let subsystem = "dev.localosxai.app"

    /// Creates a logger for a category.
    ///
    /// Privacy rule (docs/security/permissions.md): interpolate user content,
    /// file paths, prompts and command lines with the default (private)
    /// privacy level. Never log API keys or tokens, even as private.
    init(category: LogCategory) {
        self.init(subsystem: Self.subsystem, category: category.rawValue)
    }
}
