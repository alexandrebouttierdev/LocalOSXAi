import Foundation
import Security
import Synchronization

/// API keys in the login Keychain, one generic password per provider
/// (service `dev.localosxai.app.provider.<id>`).
///
/// The file-based login keychain is used rather than the data protection
/// keychain because the latter needs a signing team, and development builds
/// are signed ad hoc (project.yml). macOS may therefore ask once for access
/// after a rebuild changes the app's signature.
struct KeychainProviderSecretStore: ProviderSecretStore {
    static let servicePrefix = "dev.localosxai.app.provider."
    private static let account = "api-key"

    func apiKey(for provider: ProviderID) throws -> String? {
        var query = baseQuery(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(operation: .read, status: status) }
        guard let data = result as? Data, let key = String(bytes: data, encoding: .utf8) else {
            throw KeychainError(operation: .read, status: errSecDecode)
        }
        return key
    }

    func setAPIKey(_ key: String?, for provider: ProviderID) throws {
        guard let key else {
            let status = SecItemDelete(baseQuery(for: provider) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError(operation: .delete, status: status)
            }
            return
        }
        let data = Data(key.utf8)
        let updateStatus = SecItemUpdate(baseQuery(for: provider) as CFDictionary,
                                         [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError(operation: .save, status: updateStatus) }
        var item = baseQuery(for: provider)
        item[kSecValueData as String] = data
        item[kSecAttrLabel as String] = "LocalOSXAi API key"
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(operation: .save, status: addStatus) }
    }

    private func baseQuery(for provider: ProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.servicePrefix + provider.rawValue,
            kSecAttrAccount as String: Self.account
        ]
    }
}

/// A Keychain failure. Carries only the operation and status, never the key.
struct KeychainError: Error, Hashable, LocalizedError {
    enum Operation: String, Hashable, Sendable {
        case read, save, delete
    }

    let operation: Operation
    let status: OSStatus

    var errorDescription: String? {
        let reason = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
        return "The Keychain could not \(operation.rawValue) the API key (\(reason))."
    }

    var recoverySuggestion: String? {
        "Unlock your login keychain in Keychain Access, then try again."
    }
}

/// Process-lifetime API keys, for the simulated environment and tests.
final class InMemoryProviderSecretStore: ProviderSecretStore {
    private let keys: Mutex<[ProviderID: String]>

    init(_ keys: [ProviderID: String] = [:]) {
        self.keys = Mutex(keys)
    }

    func apiKey(for provider: ProviderID) -> String? {
        keys.withLock { $0[provider] }
    }

    func setAPIKey(_ key: String?, for provider: ProviderID) {
        keys.withLock { $0[provider] = key }
    }
}
