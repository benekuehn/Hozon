import Foundation

enum ShioriAPIKeyStoreError: LocalizedError {
    case emptyKey

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "Enter a Shiori API key before saving."
        }
    }
}

@Observable
@MainActor
final class ShioriAPIKeyStore {
    private let usesPersistentStorage: Bool

    private(set) var apiKey: String?

    var hasAPIKey: Bool {
        apiKey != nil
    }

    init() {
        usesPersistentStorage = true
        try? SharedAPIKey.migrateLegacyValueIfNeeded()
        apiKey = try? SharedAPIKey.read()
    }

    /// Creates an in-memory store with fixed state for SwiftUI previews.
    static func preview(apiKey: String? = nil) -> ShioriAPIKeyStore {
        ShioriAPIKeyStore(previewAPIKey: apiKey)
    }

    private init(previewAPIKey: String?) {
        usesPersistentStorage = false
        apiKey = previewAPIKey
    }

    func save(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ShioriAPIKeyStoreError.emptyKey }

        guard usesPersistentStorage else {
            apiKey = key
            return
        }

        try SharedAPIKey.save(key)
        apiKey = key
    }

    func remove() throws {
        guard usesPersistentStorage else {
            apiKey = nil
            return
        }

        try SharedAPIKey.remove()
        apiKey = nil
    }
}
