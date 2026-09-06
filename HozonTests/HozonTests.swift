import XCTest
@testable import Hozon

@MainActor
final class HozonTests: XCTestCase {
    func testUnknownLinkSourceDecodesAsUnknown() throws {
        let data = Data(#""future_importer""#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(LinkSource.self, from: data), .unknown)
    }

    func testLinksResponseDecodesSnakeCasePayload() throws {
        let data = Data("""
        {
          "success": true,
          "total": 1,
          "links": [{
            "id": "link-1",
            "url": "https://example.com/article",
            "title": "Example",
            "domain": "example.com",
            "summary": null,
            "image_url": null,
            "status": "ready",
            "source": "rss",
            "created_at": "2026-01-01T12:00:00Z",
            "updated_at": "2026-01-01T12:00:00Z",
            "read_at": null,
            "deleted_at": null,
            "purged_at": null,
            "hn_url": null,
            "file_type": null,
            "file_mime_type": null,
            "notion_page_id": null,
            "author": null,
            "discoverable_feed_url": null,
            "subscription_id": "feed-1"
          }]
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let response = try decoder.decode(LinksResponse.self, from: data)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.links.first?.source, .rss)
        XCTAssertEqual(response.links.first?.subscriptionId, "feed-1")
    }

    func testLinksCachePersistsDeduplicatesAndPrunesExpiredItems() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "links.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let old = link(id: "old", updatedAt: date("2025-01-01T00:00:00Z"))
        let current = link(id: "current", updatedAt: date("2026-01-15T00:00:00Z"))
        let cache = LinksCache(fileURL: fileURL)
        await cache.setLinks([old, current, current], for: .archive)
        await cache.appendLinks([current], for: .archive)
        await cache.pruneExpiredArchiveAndTrash(now: date("2026-02-01T00:00:00Z"))

        let persistedCache = LinksCache(fileURL: fileURL)
        let links = await persistedCache.links(for: .archive)
        XCTAssertEqual(links.map(\.id), ["current"])
    }

    func testLinksStoreUsesCachedLinksThenRefreshesRepository() async {
        let cached = link(id: "cached")
        let refreshed = link(id: "refreshed")
        let repository = StubRepository(cachedInbox: [cached], inboxResponse: LinksResponse(success: true, links: [refreshed], total: 1))
        let store = LinksStore(repository: repository)

        await store.load()

        XCTAssertEqual(store.links.map(\.id), ["refreshed"])
        XCTAssertEqual(repository.inboxRequests.count, 1)
        XCTAssertEqual(repository.inboxRequests.first?.0, 25)
        XCTAssertEqual(repository.inboxRequests.first?.1, 0)
        XCTAssertNil(store.errorMessage)
    }

    func testSharedLinkValidationAcceptsWebURLsOnly() throws {
        XCTAssertNoThrow(try SharedLinkInbox.validate(url: URL(string: "https://example.com")!))
        XCTAssertThrowsError(try SharedLinkInbox.validate(url: URL(string: "file:///tmp/article")!)) { error in
            XCTAssertEqual(error as? SharedLinkInboxError, .unsupportedURL)
        }
    }
}

private extension HozonTests {
    func link(id: String, updatedAt: Date? = nil) -> Link {
        let updatedAt = updatedAt ?? date("2026-01-15T00:00:00Z")
        return Link(id: id, url: URL(string: "https://example.com/\(id)")!, title: id, domain: "example.com", summary: nil, imageUrl: nil, status: .ready, source: .api, createdAt: updatedAt, updatedAt: updatedAt, readAt: nil, deletedAt: nil, purgedAt: nil, hnUrl: nil, fileType: nil, fileMimeType: nil, notionPageId: nil, author: nil, discoverableFeedUrl: nil)
    }

    func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

@MainActor
private final class StubRepository: LinksRepository {
    var cachedInbox: [Link]
    let inboxResponse: LinksResponse
    var inboxRequests: [(Int, Int)] = []

    init(cachedInbox: [Link], inboxResponse: LinksResponse) {
        self.cachedInbox = cachedInbox
        self.inboxResponse = inboxResponse
    }

    func cachedLinks(for list: LinksList) async -> [Link] { list == .inbox ? cachedInbox : [] }
    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse { inboxRequests.append((limit, offset)); return inboxResponse }
    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse { inboxResponse }
    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse { inboxResponse }
    func createLink(url: URL) async throws {}
    func archiveLink(id: Link.ID) async throws {}
    func deleteLink(id: Link.ID) async throws {}
    func cachedSubscriptions() async -> [Subscription] { [] }
    func refreshSubscriptions() async throws -> [Subscription] { [] }
    func subscribe(to feedURL: URL, initialSync: Bool) async throws -> Subscription { fatalError("Not used") }
    func fetchLinks(for subscriptionID: Subscription.ID, filter: FeedEntriesFilter) async throws -> [Link] { [] }
    func unsubscribe(id: Subscription.ID, disposition: UnsubscribeDisposition) async throws {}
}
