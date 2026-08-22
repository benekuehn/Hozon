import Foundation

/// A small, durable queue shared by the app and its Share extension.
///
/// The extension only writes URLs here; the containing app owns authenticated
/// communication with Shiori when it next becomes active.
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
    static let appGroupIdentifier = "group.benekuehn.Hozon"

    private static let fileName = "pending-shared-links.json"

    static func enqueue(url: URL) throws {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw SharedLinkInboxError.unsupportedURL
        }

        try update { pending in
            pending.append(PendingSharedLink(url: url))
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
