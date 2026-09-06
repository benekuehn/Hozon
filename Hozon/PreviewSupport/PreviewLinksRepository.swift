import Foundation

struct PreviewLinksRepository: LinksRepository {
    func cachedLinks(for list: LinksList) async -> [Link] {
        list == .inbox ? previewLinks() : []
    }

    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        let links = Array(previewLinks().dropFirst(offset).prefix(limit))
        return LinksResponse(success: true, links: links, total: previewLinks().count)
    }

    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        LinksResponse(success: true, links: [], total: 0)
    }

    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        LinksResponse(success: true, links: [], total: 0)
    }

    func createLink(url: URL) async throws {}

    func deleteLink(id: Link.ID) async throws {}

    func archiveLink(id: Link.ID) async throws {}

    func cachedSubscriptions() async -> [Subscription] { [] }

    func refreshSubscriptions() async throws -> [Subscription] { [] }

    func subscribe(to feedURL: URL, initialSync: Bool) async throws -> Subscription {
        Subscription(id: "preview-subscription", feedUrl: feedURL)
    }

    func fetchLinks(for subscriptionID: Subscription.ID, filter: FeedEntriesFilter) async throws -> [Link] {
        previewLinks().filter { $0.subscriptionId == subscriptionID }
    }

    func unsubscribe(id: Subscription.ID, disposition: UnsubscribeDisposition) async throws {}

    private func previewLinks() -> [Link] {
        [
            previewLink(
                id: "preview-1",
                title: "Designing a Native iPad Reading App",
                domain: "example.com",
                feedURL: URL(string: "https://example.com/feed.xml")
            ),
            previewLink(
                id: "preview-2",
                title: "SwiftUI Navigation Patterns",
                domain: "developer.apple.com"
            )
        ]
    }

    private func previewLink(id: String, title: String, domain: String, feedURL: URL? = nil) -> Link {
        let url = URL(string: "https://\(domain)") ?? URL(fileURLWithPath: "/")
        let now = Date()

        return Link(
            id: id,
            url: url,
            title: title,
            domain: domain,
            summary: "Preview summary",
            imageUrl: nil,
            status: .ready,
            source: .api,
            createdAt: now,
            updatedAt: now,
            readAt: nil,
            deletedAt: nil,
            purgedAt: nil,
            hnUrl: nil,
            fileType: nil,
            fileMimeType: nil,
            notionPageId: nil,
            author: nil,
            discoverableFeedUrl: feedURL
        )
    }
}
