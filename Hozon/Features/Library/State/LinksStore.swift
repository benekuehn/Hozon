import SwiftUI

enum LinksList {
    case inbox
    case archive
    case trash
}

@Observable
@MainActor
final class LinksStore {
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

        if list == .inbox {
            let cachedLinks = await repository.cachedInboxLinks()

            if !cachedLinks.isEmpty {
                links = cachedLinks
                total = cachedLinks.count
                offset = cachedLinks.count
                setLoading(false)
            }
        }

        do {
            let response = try await fetchPage(offset: 0)
            links = response.links
            total = response.total
            offset = response.links.count
        } catch {
            print("Failed to load links: \(error.localizedDescription)")
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
            print("Failed to load more links: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }
    
    func archiveLink(_ link: Link) async {
        errorMessage = nil
        print("Archive link requested: \(link.id) \(link.title)")

        do {
            try await repository.archiveLink(id: link.id)
            print("Archive link succeeded: \(link.id)")
            removeLink(link)
        } catch {
            print("Failed to archive link: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteLink(_ link: Link) async {
        errorMessage = nil
        print("Delete link requested: \(link.id) \(link.title)")

        do {
            try await repository.deleteLink(id: link.id)
            print("Delete link succeeded: \(link.id)")
            removeLink(link)
        } catch {
            print("Failed to delete link: \(error.localizedDescription)")
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
