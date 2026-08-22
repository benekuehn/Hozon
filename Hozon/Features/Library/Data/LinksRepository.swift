import Foundation

enum FeedEntriesFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all = "All"
    case inbox = "Inbox"
    case archive = "Archive"

    var id: Self { self }
}

enum UnsubscribeDisposition: Sendable {
    case keepInInbox
    case archiveUnread
    case trashUnread
}

protocol LinksRepository {
    func cachedLinks(for list: LinksList) async -> [Link]
    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse
    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse
    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse
    func createLink(url: URL) async throws
    func archiveLink(id: Link.ID) async throws
    func deleteLink(id: Link.ID) async throws
    func cachedSubscriptions() async -> [Subscription]
    func refreshSubscriptions() async throws -> [Subscription]
    func subscribe(to feedURL: URL, initialSync: Bool) async throws -> Subscription
    func fetchLinks(for subscriptionID: Subscription.ID, filter: FeedEntriesFilter) async throws -> [Link]
    func unsubscribe(id: Subscription.ID, disposition: UnsubscribeDisposition) async throws
}
