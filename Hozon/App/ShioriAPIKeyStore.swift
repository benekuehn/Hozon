import Foundation
import Security

enum ShioriAPIKeyStoreError: LocalizedError {
    case emptyKey
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "Enter a Shiori API key before saving."
        case .keychain:
            return "Your API key could not be saved securely. Please try again."
        }
    }
}

@Observable
@MainActor
final class ShioriAPIKeyStore {
    private let service = "benekuehn.Hozon"
    private let account = "shiori-api-key"
    private let storedAtDefaultsKey = "shiori-api-key-stored-at"

    private(set) var apiKey: String?
    private(set) var apiKeyStoredAt: Date?

    var hasAPIKey: Bool {
        apiKey != nil
    }

    init() {
        apiKey = try? readKey()
        apiKeyStoredAt = UserDefaults.standard.object(forKey: storedAtDefaultsKey) as? Date
    }

    func save(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ShioriAPIKeyStoreError.emptyKey }

        let data = Data(key.utf8)
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            attributes.forEach { addQuery[$0.key] = $0.value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ShioriAPIKeyStoreError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw ShioriAPIKeyStoreError.keychain(updateStatus)
        }

        apiKey = key
        let storedAt = Date()
        UserDefaults.standard.set(storedAt, forKey: storedAtDefaultsKey)
        apiKeyStoredAt = storedAt
    }

    func remove() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ShioriAPIKeyStoreError.keychain(status)
        }

        apiKey = nil
        UserDefaults.standard.removeObject(forKey: storedAtDefaultsKey)
        apiKeyStoredAt = nil
    }

    private func readKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            throw ShioriAPIKeyStoreError.keychain(status)
        }
        return key
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
