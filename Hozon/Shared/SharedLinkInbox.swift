import Foundation
import Security

enum SharedAPIKeyError: LocalizedError {
    case accessGroupUnavailable
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .accessGroupUnavailable:
            "Hozon's shared Keychain access group is unavailable."
        case .keychain:
            "Your API key could not be accessed securely."
        }
    }
}

/// Stores the API key in a Keychain access group shared by the app and its
/// Action extension. The app migrates keys saved before Keychain sharing was
/// enabled, so existing installations do not need to enter the key again.
enum SharedAPIKey {
    private static let service = Bundle.main.object(forInfoDictionaryKey: "HozonKeychainService") as? String ?? "com.example.Hozon"
    private static let account = "shiori-api-key"
    private static let accessGroupSuffix = Bundle.main.object(forInfoDictionaryKey: "HozonKeychainSharedAccessGroup") as? String ?? "com.example.Hozon.shared"

    static func migrateLegacyValueIfNeeded() throws {
        guard try read() == nil, let legacyValue = try read(usingSharedAccessGroup: false) else {
            return
        }

        try save(legacyValue)
        let status = SecItemDelete(baseQuery(accessGroup: nil) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SharedAPIKeyError.keychain(status)
        }
    }

    static func read() throws -> String? {
        try read(usingSharedAccessGroup: true)
    }

    static func save(_ value: String) throws {
        let data = Data(value.utf8)
        let query = try baseQuery(accessGroup: accessGroup())
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
                throw SharedAPIKeyError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw SharedAPIKeyError.keychain(updateStatus)
        }
    }

    static func remove() throws {
        let status = SecItemDelete(
            try baseQuery(accessGroup: accessGroup()) as CFDictionary
        )
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SharedAPIKeyError.keychain(status)
        }
    }

    private static func read(usingSharedAccessGroup: Bool) throws -> String? {
        let group = try usingSharedAccessGroup ? accessGroup() : nil
        var query = baseQuery(accessGroup: group)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw SharedAPIKeyError.keychain(status)
        }
        return key
    }

    private static func baseQuery(accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        query[kSecAttrAccessGroup as String] = accessGroup
        return query
    }

    private static func accessGroup() throws -> String {
        guard let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String else {
            throw SharedAPIKeyError.accessGroupUnavailable
        }
        return prefix + accessGroupSuffix
    }
}

/// A small, durable queue shared by the app and its Action extension.
///
/// The extension writes URLs here when immediate delivery fails; the containing
/// app retries them when it next becomes active.
struct PendingSharedLink: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let url: URL
    let receivedAt: Date

    init(id: UUID = UUID(), url: URL, receivedAt: Date = .now) {
        self.id = id
        self.url = url
        self.receivedAt = receivedAt
    }
}

enum SharedLinkInboxError: LocalizedError {
    case appGroupUnavailable
    case unsupportedURL

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "The shared app storage is unavailable."
        case .unsupportedURL:
            return "Only web URLs can be added to Inbox."
        }
    }
}

enum SharedLinkInbox {
    static let appGroupIdentifier = Bundle.main.object(forInfoDictionaryKey: "HozonAppGroupIdentifier") as? String ?? "group.com.example.Hozon"

    private static let fileName = "pending-shared-links.json"

    static func enqueue(url: URL) throws {
        try validate(url: url)

        try update { pending in
            pending.append(PendingSharedLink(url: url))
        }
    }

    static func validate(url: URL) throws {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty else {
            throw SharedLinkInboxError.unsupportedURL
        }
    }

    /// Removes and returns all queued links. Call `requeue(_:)` for any links
    /// that could not be delivered to Shiori so they survive a later retry.
    static func takeAll() throws -> [PendingSharedLink] {
        let fileURL = try queueFileURL()
        var result: [PendingSharedLink] = []
        var coordinationError: NSError?
        var operationError: Error?

        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                result = try read(from: coordinatedURL)
                try write([], to: coordinatedURL)
            } catch {
                result = []
                operationError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
        return result
    }

    static func requeue(_ links: [PendingSharedLink]) throws {
        guard !links.isEmpty else { return }

        try update { pending in
            let pendingIDs = Set(pending.map(\.id))
            let linksToRestore = links.filter { !pendingIDs.contains($0.id) }
            pending.insert(contentsOf: linksToRestore, at: 0)
        }
    }

    private static func update(_ transform: (inout [PendingSharedLink]) -> Void) throws {
        let fileURL = try queueFileURL()
        var coordinationError: NSError?
        var operationError: Error?

        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                var pending = try read(from: coordinatedURL)
                transform(&pending)
                try write(pending, to: coordinatedURL)
            } catch {
                operationError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let operationError { throw operationError }
    }

    private static func queueFileURL() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw SharedLinkInboxError.appGroupUnavailable
        }

        return containerURL.appending(path: fileName)
    }

    private static func read(from fileURL: URL) throws -> [PendingSharedLink] {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([PendingSharedLink].self, from: data)
    }

    private static func write(_ links: [PendingSharedLink], to fileURL: URL) throws {
        let data = try JSONEncoder().encode(links)
        try data.write(to: fileURL, options: .atomic)
    }
}
