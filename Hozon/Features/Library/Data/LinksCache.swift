import Foundation

actor LinksCache {
    private struct Snapshot: Codable {
        var inbox: [Link] = []
        var archive: [Link] = []
        var trash: [Link] = []
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

    func appendLinks(_ links: [Link], for list: LinksList) {
        setLinks(Self.deduplicated(self.links(for: list) + links), for: list)
    }

    func removeLink(id: Link.ID) {
        snapshot.inbox.removeAll { $0.id == id }
        snapshot.archive.removeAll { $0.id == id }
        snapshot.trash.removeAll { $0.id == id }
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
            print("Failed to persist links cache: \(error.localizedDescription)")
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
