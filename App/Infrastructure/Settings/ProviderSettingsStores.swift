import Foundation
import OSLog
import Synchronization

/// Provider settings persisted as JSON in `UserDefaults`.
///
/// The key carries a version so a future incompatible format can be read
/// once and migrated (docs/data/migrations.md).
struct UserDefaultsProviderSettingsStore: ProviderSettingsStore {
    static let key = "providers.v1"

    /// `UserDefaults` is not `Sendable`, so the store keeps the suite name and
    /// resolves the (thread-safe) defaults object on each call.
    private let suiteName: String?

    /// - Parameter suiteName: `nil` for the app's standard defaults; tests
    ///   pass a unique suite to stay isolated.
    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func load() -> ProviderSettings {
        guard let data = defaults.data(forKey: Self.key) else { return .defaults }
        do {
            return try JSONDecoder().decode(ProviderSettings.self, from: data)
        } catch {
            Logger(category: .persistence).error("Unreadable provider settings, using defaults: \(error)")
            return .defaults
        }
    }

    func save(_ settings: ProviderSettings) throws {
        defaults.set(try JSONEncoder().encode(settings), forKey: Self.key)
    }
}

/// Process-lifetime settings, for the simulated environment and tests.
final class InMemoryProviderSettingsStore: ProviderSettingsStore {
    private let settings: Mutex<ProviderSettings>

    init(_ settings: ProviderSettings = .defaults) {
        self.settings = Mutex(settings)
    }

    func load() -> ProviderSettings {
        settings.withLock { $0 }
    }

    func save(_ newValue: ProviderSettings) {
        settings.withLock { $0 = newValue }
    }
}
