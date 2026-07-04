protocol LinksRepository {
    func cachedLinks(for list: LinksList) async -> [Link]
    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse
    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse
    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse
    func archiveLink(id: Link.ID) async throws
    func deleteLink(id: Link.ID) async throws
}
