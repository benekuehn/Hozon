protocol LinksRepository {
    func fetchInboxLinks() async throws -> [Link]
    func fetchArchiveLinks() async throws -> [Link]
    func fetchTrashLinks() async throws -> [Link]
}
