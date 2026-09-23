import Foundation
import Observation

/// Editable provider settings with validation.
///
/// Edits are kept as a draft and only take effect on `apply()`, so a URL is
/// never used while the user is still typing it.
@MainActor
@Observable
final class ProviderSettingsViewModel {
    enum Field: Hashable {
        case ollamaURL
        case lmStudioURL
    }

    var ollamaEnabled: Bool
    var ollamaURL: String
    var ollamaContextTokens: Int?
    var lmStudioEnabled: Bool
    var lmStudioURL: String
    var idleTimeoutSeconds: Double

    private(set) var validationErrors: [Field: String] = [:]
    private(set) var saved: ProviderSettings
    private(set) var isApplying = false
    var error: UserFacingError?

    private let store: any ProviderSettingsStore
    private let onApply: @MainActor (ProviderSettings) async -> Void

    /// - Parameter onApply: called with the new settings after they are saved,
    ///   to rebuild providers and rediscover models.
    init(store: any ProviderSettingsStore, onApply: @escaping @MainActor (ProviderSettings) async -> Void) {
        self.store = store
        self.onApply = onApply
        let settings = store.load()
        saved = settings
        ollamaEnabled = settings.ollama.isEnabled
        ollamaURL = settings.ollama.baseURL.absoluteString
        ollamaContextTokens = settings.ollamaContextTokens
        lmStudioEnabled = settings.lmStudio.isEnabled
        lmStudioURL = settings.lmStudio.baseURL.absoluteString
        idleTimeoutSeconds = settings.idleTimeoutSeconds
    }

    /// The draft as settings, or `nil` while a field is invalid.
    var draft: ProviderSettings? {
        guard let ollama = ProviderSettings.serverURL(from: ollamaURL),
              let lmStudio = ProviderSettings.serverURL(from: lmStudioURL) else { return nil }
        return ProviderSettings(
            ollama: .init(isEnabled: ollamaEnabled, baseURL: ollama),
            ollamaContextTokens: ollamaContextTokens,
            lmStudio: .init(isEnabled: lmStudioEnabled, baseURL: lmStudio),
            idleTimeoutSeconds: min(max(idleTimeoutSeconds, ProviderSettings.idleTimeoutRange.lowerBound),
                                    ProviderSettings.idleTimeoutRange.upperBound)
        )
    }

    var hasChanges: Bool { draft != saved || draft == nil }

    /// Validates, saves and applies the draft. Returns `false` when a field is
    /// invalid or saving failed.
    @discardableResult
    func apply() async -> Bool {
        validate()
        guard validationErrors.isEmpty, let settings = draft else { return false }
        isApplying = true
        defer { isApplying = false }
        do {
            try store.save(settings)
        } catch {
            self.error = UserFacingError(error, title: "Could not save settings", category: .persistence)
            return false
        }
        saved = settings
        load(settings)
        await onApply(settings)
        return true
    }

    func revert() {
        load(saved)
        validationErrors = [:]
    }

    func restoreDefaults() {
        load(.defaults)
        validationErrors = [:]
    }

    private func validate() {
        var errors: [Field: String] = [:]
        let message = "Enter a URL such as http://localhost:11434"
        if ProviderSettings.serverURL(from: ollamaURL) == nil { errors[.ollamaURL] = message }
        if ProviderSettings.serverURL(from: lmStudioURL) == nil { errors[.lmStudioURL] = message }
        validationErrors = errors
    }

    private func load(_ settings: ProviderSettings) {
        ollamaEnabled = settings.ollama.isEnabled
        ollamaURL = settings.ollama.baseURL.absoluteString
        ollamaContextTokens = settings.ollamaContextTokens
        lmStudioEnabled = settings.lmStudio.isEnabled
        lmStudioURL = settings.lmStudio.baseURL.absoluteString
        idleTimeoutSeconds = settings.idleTimeoutSeconds
    }
}
