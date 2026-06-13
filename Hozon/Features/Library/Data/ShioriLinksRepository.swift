struct ShioriLinksRepository: LinksRepository {
    let apiClient: ShioriAPIClient

    func fetchInboxLinks() async throws -> [Link] {
        let response = try await apiClient.fetchLinks()
        return response.links
    }

    func fetchArchiveLinks() async throws -> [Link] {
        []
    }

    func fetchTrashLinks() async throws -> [Link] {
        []
    }
}
