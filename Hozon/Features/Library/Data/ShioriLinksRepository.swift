struct ShioriLinksRepository: LinksRepository {
    let apiClient: ShioriAPIClient
    private let cache: LinksCache

    init(apiClient: ShioriAPIClient, cache: LinksCache = LinksCache()) {
        self.apiClient = apiClient
        self.cache = cache
        let cache = cache
        Task.detached(priority: .background) {
            await cache.pruneExpiredArchiveAndTrash()
        }
    }

    func cachedLinks(for list: LinksList) async -> [Link] {
        await cache.links(for: list)
    }

    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        let response = try await apiClient.fetchLinks(
            limit: limit,
            offset: offset
        )

        await cacheResponse(response, for: .inbox, offset: offset)

        return response
    }

    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        let response = try await apiClient.fetchLinks(
            read: "read",
            limit: limit,
            offset: offset
        )

        await cacheResponse(response, for: .archive, offset: offset)
        pruneExpiredArchiveAndTrashCacheInBackground()

        return response
    }

    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        let response = try await apiClient.fetchLinks(
            trash: true,
            limit: limit,
            offset: offset
        )

        await cacheResponse(response, for: .trash, offset: offset)
        pruneExpiredArchiveAndTrashCacheInBackground()

        return response
    }
    
    func archiveLink(id: Link.ID) async throws {
        try await apiClient.archiveLink(id: id)
        await cache.removeLink(id: id)
    }
    
    func deleteLink(id: Link.ID) async throws {
        try await apiClient.deleteLink(id: id)
        await cache.removeLink(id: id)
    }

    private func cacheResponse(_ response: LinksResponse, for list: LinksList, offset: Int) async {
        if offset == 0 {
            await cache.setLinks(response.links, for: list)
        } else {
            await cache.appendLinks(response.links, for: list)
        }
    }

    private func pruneExpiredArchiveAndTrashCacheInBackground() {
        let cache = cache
        Task.detached(priority: .background) {
            await cache.pruneExpiredArchiveAndTrash()
        }
    }
}
