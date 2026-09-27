import Foundation
import Observation

/// Editable provider settings with validation.
///
/// Edits are kept as a draft and only take effect on `apply()`, so a URL is
/// never used while the user is still typing it. API keys of custom servers
/// follow the same rule and are written to the secret store on `apply()`.
@MainActor
@Observable
final class ProviderSettingsViewModel {
    enum Field: Hashable {
        case ollamaURL
        case lmStudioURL
        case serverName(UUID)
        case serverURL(UUID)
    }

    /// The editable form of a custom server.
    struct ServerDraft: Identifiable, Hashable {
        let id: UUID
        var name: String
        var isEnabled: Bool
        var url: String
        var apiKey: String
        var supportsTools: Bool
        var contextTokens: Int?

        var providerID: ProviderID { ProviderSettings.CustomServer.providerID(for: id) }
    }

    var ollamaEnabled: Bool
    var ollamaURL: String
    var ollamaContextTokens: Int?
    var lmStudioEnabled: Bool
    var lmStudioURL: String
    var idleTimeoutSeconds: Double
    var customServers: [ServerDraft]

    private(set) var validationErrors: [Field: String] = [:]
    private(set) var saved: ProviderSettings
    /// API keys as last loaded or applied, by server.
    private var savedAPIKeys: [UUID: String]
    private(set) var isApplying = false
    var error: UserFacingError?

    private let store: any ProviderSettingsStore
    private let secrets: any ProviderSecretStore
    private let onApply: @MainActor (ProviderSettings) async -> Void

    /// - Parameter onApply: called with the new settings after they are saved,
    ///   to rebuild providers and rediscover models.
    init(store: any ProviderSettingsStore, secrets: any ProviderSecretStore,
         onApply: @escaping @MainActor (ProviderSettings) async -> Void) {
        self.store = store
        self.secrets = secrets
        self.onApply = onApply
        let settings = store.load()
        saved = settings
        ollamaEnabled = settings.ollama.isEnabled
        ollamaURL = settings.ollama.baseURL.absoluteString
        ollamaContextTokens = settings.ollamaContextTokens
        lmStudioEnabled = settings.lmStudio.isEnabled
        lmStudioURL = settings.lmStudio.baseURL.absoluteString
        idleTimeoutSeconds = settings.idleTimeoutSeconds
        var keys: [UUID: String] = [:]
        var readError: (any Error)?
        for server in settings.customServers {
            do {
                keys[server.id] = try secrets.apiKey(for: server.providerID) ?? ""
            } catch {
                readError = error
            }
        }
        savedAPIKeys = keys
        customServers = Self.drafts(of: settings.customServers, keys: keys)
        if let readError {
            error = UserFacingError(readError, title: "Could not read an API key", category: .persistence)
        }
    }

    /// The draft as settings, or `nil` while a field is invalid.
    var draft: ProviderSettings? {
        guard let ollama = ProviderSettings.serverURL(from: ollamaURL),
              let lmStudio = ProviderSettings.serverURL(from: lmStudioURL),
              Self.nameErrors(of: customServers).isEmpty else { return nil }
        var servers: [ProviderSettings.CustomServer] = []
        for server in customServers {
            guard let url = ProviderSettings.serverURL(from: server.url) else { return nil }
            servers.append(.init(id: server.id, name: Self.trimmed(server.name), isEnabled: server.isEnabled, baseURL: url,
                                 supportsTools: server.supportsTools, contextTokens: server.contextTokens))
        }
        return ProviderSettings(
            ollama: .init(isEnabled: ollamaEnabled, baseURL: ollama),
            ollamaContextTokens: ollamaContextTokens,
            lmStudio: .init(isEnabled: lmStudioEnabled, baseURL: lmStudio),
            idleTimeoutSeconds: min(max(idleTimeoutSeconds, ProviderSettings.idleTimeoutRange.lowerBound),
                                    ProviderSettings.idleTimeoutRange.upperBound),
            customServers: servers
        )
    }

    var hasChanges: Bool { draft != saved || draft == nil || !changedAPIKeys.isEmpty }

    /// Adds an enabled server with suggested values, to be completed by the user.
    func addServer() {
        let taken = Set(customServers.map { Self.trimmed($0.name).lowercased() })
        var name = "Custom Server"
        var number = 1
        while taken.contains(name.lowercased()) {
            number += 1
            name = "Custom Server \(number)"
        }
        customServers.append(ServerDraft(id: UUID(), name: name, isEnabled: true,
                                         url: ProviderSettings.customServerDefaultURL.absoluteString, apiKey: "",
                                         supportsTools: true, contextTokens: nil))
    }

    /// Removes a server from the draft. Its API key is deleted on `apply()`.
    func removeServer(id: UUID) {
        customServers.removeAll { $0.id == id }
        validationErrors = validationErrors.filter { field, _ in
            field != .serverName(id) && field != .serverURL(id)
        }
    }

    /// A caution about where prompts go, or `nil` for a server on this Mac.
    /// Recomputed as the user types; an invalid URL has its own error instead.
    func privacyWarning(forURL text: String, apiKey: String = "") -> String? {
        guard let url = ProviderSettings.serverURL(from: text), !ProviderSettings.isOnThisMac(url) else { return nil }
        let host = url.host() ?? url.absoluteString
        var warning = "Prompts, including the contents of project files, are sent to \(host)."
        if url.scheme?.lowercased() == "http" && !Self.trimmed(apiKey).isEmpty {
            warning += " The API key travels unencrypted over HTTP."
        }
        return warning
    }

    /// Validates, saves and applies the draft. Returns `false` when a field is
    /// invalid or saving failed.
    @discardableResult
    func apply() async -> Bool {
        validate()
        guard validationErrors.isEmpty, let settings = draft else { return false }
        isApplying = true
        defer { isApplying = false }
        // Keys first: providers are rebuilt from the saved settings and read
        // their keys then, so a server must never be saved before its key.
        let keys = Dictionary(uniqueKeysWithValues: customServers.map { ($0.id, Self.trimmed($0.apiKey)) })
        do {
            try saveAPIKeys(removing: saved.customServers.filter { keys[$0.id] == nil })
            try store.save(settings)
        } catch {
            self.error = UserFacingError(error, title: "Could not save settings", category: .persistence)
            return false
        }
        saved = settings
        savedAPIKeys = keys
        load(settings, keys: keys)
        await onApply(settings)
        return true
    }

    func revert() {
        load(saved, keys: savedAPIKeys)
        validationErrors = [:]
    }

    func restoreDefaults() {
        load(.defaults, keys: [:])
        validationErrors = [:]
    }

    /// Keys that differ from the saved ones, by server; an empty key means
    /// removal. A key that could not be read counts as empty, so a read
    /// failure never turns into a deletion unless the user edits the key.
    private var changedAPIKeys: [UUID: String] {
        var changed: [UUID: String] = [:]
        for server in customServers {
            let key = Self.trimmed(server.apiKey)
            if key != savedAPIKeys[server.id, default: ""] { changed[server.id] = key }
        }
        return changed
    }

    /// Writes changed keys and deletes those of removed servers. Unchanged
    /// keys are not rewritten, so applying other edits never touches them.
    private func saveAPIKeys(removing removed: [ProviderSettings.CustomServer]) throws {
        for (id, key) in changedAPIKeys {
            try secrets.setAPIKey(key.isEmpty ? nil : key, for: ProviderSettings.CustomServer.providerID(for: id))
        }
        for server in removed {
            try secrets.setAPIKey(nil, for: server.providerID)
        }
    }

    private func validate() {
        var errors: [Field: String] = [:]
        let message = "Enter a URL such as http://localhost:11434"
        if ProviderSettings.serverURL(from: ollamaURL) == nil { errors[.ollamaURL] = message }
        if ProviderSettings.serverURL(from: lmStudioURL) == nil { errors[.lmStudioURL] = message }
        for server in customServers where ProviderSettings.serverURL(from: server.url) == nil {
            errors[.serverURL(server.id)] = "Enter a URL such as http://localhost:8080"
        }
        errors.merge(Self.nameErrors(of: customServers)) { first, _ in first }
        validationErrors = errors
    }

    /// Names are shown next to every model of the server, so they must be
    /// present and tell servers apart, including from the built-in providers.
    private static func nameErrors(of servers: [ServerDraft]) -> [Field: String] {
        var errors: [Field: String] = [:]
        var seen: Set<String> = ["ollama", "lm studio"]
        for server in servers {
            let name = trimmed(server.name).lowercased()
            if name.isEmpty {
                errors[.serverName(server.id)] = "Enter a name"
            } else if !seen.insert(name).inserted {
                errors[.serverName(server.id)] = "Another provider already uses this name"
            }
        }
        return errors
    }

    private static func drafts(of servers: [ProviderSettings.CustomServer], keys: [UUID: String]) -> [ServerDraft] {
        servers.map { server in
            ServerDraft(id: server.id, name: server.name, isEnabled: server.isEnabled, url: server.baseURL.absoluteString,
                        apiKey: keys[server.id] ?? "", supportsTools: server.supportsTools, contextTokens: server.contextTokens)
        }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load(_ settings: ProviderSettings, keys: [UUID: String]) {
        ollamaEnabled = settings.ollama.isEnabled
        ollamaURL = settings.ollama.baseURL.absoluteString
        ollamaContextTokens = settings.ollamaContextTokens
        lmStudioEnabled = settings.lmStudio.isEnabled
        lmStudioURL = settings.lmStudio.baseURL.absoluteString
        idleTimeoutSeconds = settings.idleTimeoutSeconds
        customServers = Self.drafts(of: settings.customServers, keys: keys)
    }
}
