import Foundation
import OSLog

actor LinksCache {
    private static let logger = Logger(subsystem: "com.benekuehn.Hozon", category: "LinksCache")
    private struct Snapshot: Codable {
        var inbox: [Link] = []
        var archive: [Link] = []
        var trash: [Link] = []
        var subscriptions: [Subscription] = []

        private enum CodingKeys: String, CodingKey {
            case inbox, archive, trash, subscriptions
        }

        init(inbox: [Link] = [], archive: [Link] = [], trash: [Link] = [], subscriptions: [Subscription] = []) {
            self.inbox = inbox
            self.archive = archive
            self.trash = trash
            self.subscriptions = subscriptions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            inbox = try container.decodeIfPresent([Link].self, forKey: .inbox) ?? []
            archive = try container.decodeIfPresent([Link].self, forKey: .archive) ?? []
            trash = try container.decodeIfPresent([Link].self, forKey: .trash) ?? []
            subscriptions = try container.decodeIfPresent([Subscription].self, forKey: .subscriptions) ?? []
        }
    }

    private let fileURL: URL
    private var snapshot: Snapshot

    init(fileURL: URL = LinksCache.defaultFileURL()) {
        self.fileURL = fileURL
        snapshot = Self.load(from: fileURL)
    }

    func links(for list: LinksList) -> [Link] {
        switch list {
        case .inbox: snapshot.inbox
        case .archive: snapshot.archive
        case .trash: snapshot.trash
        }
    }

    func setLinks(_ links: [Link], for list: LinksList) {
        switch list {
        case .inbox: snapshot.inbox = links
        case .archive: snapshot.archive = links
        case .trash: snapshot.trash = links
        }
        persist()
    }

    func cachedSubscriptions() -> [Subscription] {
        snapshot.subscriptions
    }

    func setSubscriptions(_ subscriptions: [Subscription]) {
        snapshot.subscriptions = subscriptions
        persist()
    }

    func appendLinks(_ links: [Link], for list: LinksList) {
        setLinks(Self.deduplicated(self.links(for: list) + links), for: list)
    }

    func removeLink(id: Link.ID) {
        removeLinks(ids: Set([id]))
    }

    func removeLinks(ids: Set<Link.ID>) {
        snapshot.inbox.removeAll { ids.contains($0.id) }
        snapshot.archive.removeAll { ids.contains($0.id) }
        snapshot.trash.removeAll { ids.contains($0.id) }
        persist()
    }

    func pruneExpiredArchiveAndTrash(now: Date = .now) {
        guard let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: now) else { return }
        let oldArchiveCount = snapshot.archive.count
        let oldTrashCount = snapshot.trash.count

        snapshot.archive.removeAll { ($0.readAt ?? $0.updatedAt) < cutoff }
        snapshot.trash.removeAll { ($0.deletedAt ?? $0.updatedAt) < cutoff }

        if snapshot.archive.count != oldArchiveCount || snapshot.trash.count != oldTrashCount {
            persist()
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            Self.logger.error("Failed to persist the links cache. error=\(error.localizedDescription, privacy: .private(mask: .hash))")
        }
    }

    private static func load(from fileURL: URL) -> Snapshot {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Snapshot.self, from: Data(contentsOf: fileURL))
        } catch {
            return Snapshot()
        }
    }

    private static func defaultFileURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "LinksCache", directoryHint: .isDirectory)
            .appending(path: "links.json")
    }

    private static func deduplicated(_ links: [Link]) -> [Link] {
        var ids = Set<Link.ID>()
        return links.filter { ids.insert($0.id).inserted }
    }
}
