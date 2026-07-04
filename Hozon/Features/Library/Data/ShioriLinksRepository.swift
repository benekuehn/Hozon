struct ShioriLinksRepository: LinksRepository {
    let apiClient: ShioriAPIClient
    private let cache: LinksCache

    init(apiClient: ShioriAPIClient, cache: LinksCache = LinksCache()) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func cachedInboxLinks() async -> [Link] {
        await cache.inboxLinks()
    }

    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        let response = try await apiClient.fetchLinks(
            limit: limit,
            offset: offset
        )

        if offset == 0 {
            await cache.setInboxLinks(response.links)
        } else {
            await cache.appendInboxLinks(response.links)
        }

        return response
    }

    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        try await apiClient.fetchLinks(
            read: "read",
            limit: limit,
            offset: offset
        )
    }

    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        try await apiClient.fetchLinks(
            trash: true,
            limit: limit,
            offset: offset
        )
    }
    
    func archiveLink(id: Link.ID) async throws {
        try await apiClient.archiveLink(id: id)
        await cache.removeLink(id: id)
    }
    
    func deleteLink(id: Link.ID) async throws {
        try await apiClient.deleteLink(id: id)
        await cache.removeLink(id: id)
    }
}

actor LinksCache {
    private var inbox: [Link] = []

    func inboxLinks() -> [Link] {
        inbox
    }

    func setInboxLinks(_ links: [Link]) {
        inbox = links
    }

    func appendInboxLinks(_ links: [Link]) {
        inbox += links
    }

    func removeLink(id: Link.ID) {
        inbox.removeAll { $0.id == id }
    }
}
