import Foundation

/// What the About window and the sidebar show about the app: its version,
/// its author and where to find it.
struct AppInfo: Hashable, Sendable {
    let name: String
    /// `CFBundleShortVersionString`, e.g. “0.1.0”.
    let version: String
    /// `CFBundleVersion`, e.g. “1”.
    let build: String

    static let author = "Alexandre Bouttier"
    static let tagline = "A native macOS coding agent for local models."
    static let license = "MIT License"
    static let copyright = "© 2026 Alexandre Bouttier"
    // Constant, valid URLs: a failure here is a typo caught by the tests.
    static let repository = URL(string: "https://github.com/alexandrebouttierdev/LocalOSXAi") ?? URL(fileURLWithPath: "/")
    static let website = URL(string: "https://www.alexandrebouttier.fr") ?? URL(fileURLWithPath: "/")
    static let issues = repository.appending(path: "issues")
    static let licenseURL = repository.appending(path: "blob/dev/LICENSE")

    /// “v0.1.0”, at the bottom of the sidebar.
    var shortVersion: String { "v\(version)" }
    /// “Version 0.1.0 (1)”, in the About window.
    var fullVersion: String { "Version \(version) (\(build))" }

    /// Reads a bundle's Info.plist values; missing ones show as “—”.
    init(infoDictionary: [String: Any]) {
        name = infoDictionary["CFBundleDisplayName"] as? String ?? infoDictionary["CFBundleName"] as? String ?? "LocalOSXAi"
        version = infoDictionary["CFBundleShortVersionString"] as? String ?? "—"
        build = infoDictionary["CFBundleVersion"] as? String ?? "—"
    }
}
