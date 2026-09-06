import SwiftUI
import OSLog

enum LinksList: Sendable {
    case inbox
    case archive
    case trash
}

@Observable
@MainActor
final class LinksStore {
    private static let logger = Logger(subsystem: "com.benekuehn.Hozon", category: "LinksStore")
    private(set) var links: [Link] = []
    private(set) var isLoading = true
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    private let pageSize = 25
    private let list: LinksList
    private let repository: any LinksRepository
    private var total = 0
    private var offset = 0

    init(repository: any LinksRepository, list: LinksList = .inbox) {
        self.list = list
        self.repository = repository
    }

    func load() async {
        if links.isEmpty {
            setLoading(true)
        }

        errorMessage = nil

        let cachedLinks = await repository.cachedLinks(for: list)

        if !cachedLinks.isEmpty {
            links = cachedLinks
            total = cachedLinks.count
            offset = cachedLinks.count
            setLoading(false)
        }

        do {
            let response = try await fetchPage(offset: 0)
            links = response.links
            total = response.total
            offset = response.links.count
        } catch {
            Self.logger.error("Failed to load links. error=\(error.localizedDescription, privacy: .private(mask: .hash))")
            errorMessage = error.localizedDescription
        }

        setLoading(false)
        if let firstLink = links.first {
            await loadNextPageIfNeeded(currentLink: firstLink)
        }
    }

    func loadNextPageIfNeeded(currentLink: Link) async {
        guard let currentIndex = links.firstIndex(where: { $0.id == currentLink.id }) else { return }
        guard !isLoading, !isLoadingMore, links.count < total else { return }
        guard currentIndex >= max(0, links.count - pageSize) else { return }

        errorMessage = nil
        isLoadingMore = true

        do {
            let response = try await fetchPage(offset: offset)
            links += response.links
            total = response.total
            offset += response.links.count
        } catch {
            Self.logger.error("Failed to load more links. error=\(error.localizedDescription, privacy: .private(mask: .hash))")
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }
    
    func archiveLink(_ link: Link) async {
        errorMessage = nil
        do {
            try await repository.archiveLink(id: link.id)
            removeLink(link)
        } catch {
            Self.logger.error("Failed to archive a link. error=\(error.localizedDescription, privacy: .private(mask: .hash))")
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteLink(_ link: Link) async {
        errorMessage = nil
        do {
            try await repository.deleteLink(id: link.id)
            removeLink(link)
        } catch {
            Self.logger.error("Failed to delete a link. error=\(error.localizedDescription, privacy: .private(mask: .hash))")
            errorMessage = error.localizedDescription
        }
    }

    private func fetchPage(offset: Int) async throws -> LinksResponse {
        switch list {
        case .inbox:
            try await repository.refreshInboxLinks(limit: pageSize, offset: offset)
        case .archive:
            try await repository.fetchArchiveLinks(limit: pageSize, offset: offset)
        case .trash:
            try await repository.fetchTrashLinks(limit: pageSize, offset: offset)
        }
    }

    private func removeLink(_ link: Link) {
        let originalCount = links.count
        links.removeAll { $0.id == link.id }
        guard links.count != originalCount else { return }
        total = max(links.count, total - 1)
        offset = max(0, offset - 1)
    }

    private func setLoading(_ isLoading: Bool) {
        guard self.isLoading != isLoading else { return }
        self.isLoading = isLoading
    }
}
