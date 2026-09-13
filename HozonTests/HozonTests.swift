import XCTest
@testable import Hozon

@MainActor
final class HozonTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

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

    func testLinksStoreLoadsTheNextPageWhenTheInitialPageIsFull() async {
        let firstPage = (0..<25).map { link(id: "first-\($0)") }
        let secondPage = [link(id: "second-1"), link(id: "second-2")]
        let repository = StubRepository(
            cachedInbox: [],
            inboxResponses: [
                LinksResponse(success: true, links: firstPage, total: 27),
                LinksResponse(success: true, links: secondPage, total: 27)
            ]
        )
        let store = LinksStore(repository: repository)

        await store.load()

        XCTAssertEqual(repository.inboxRequests.map(\.1), [0, 25])
        XCTAssertEqual(store.links.map(\.id), firstPage.map(\.id) + secondPage.map(\.id))
        XCTAssertNil(store.errorMessage)
    }

    func testLinksStoreKeepsLinkWhenArchivingFails() async {
        let cached = link(id: "cached")
        let repository = StubRepository(
            cachedInbox: [cached],
            inboxResponse: LinksResponse(success: true, links: [cached], total: 1)
        )
        repository.archiveError = StubError.failed
        let store = LinksStore(repository: repository)

        await store.load()
        await store.archiveLink(cached)

        XCTAssertEqual(repository.archivedIDs, [cached.id])
        XCTAssertEqual(store.links.map(\.id), [cached.id])
        XCTAssertNotNil(store.errorMessage)
    }

    func testSubscriptionsStoreTreatsExistingSubscriptionConflictAsSuccess() async {
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let existing = subscription(id: "existing", feedURL: feedURL)
        let repository = SubscriptionStubRepository(
            refreshedSubscriptions: [existing],
            subscribeResult: .failure(ShioriAPIError.requestFailed(statusCode: 409))
        )
        let store = SubscriptionsStore(repository: repository)

        let message = await store.setSubscribed(true, for: feedURL)

        XCTAssertNil(message)
        XCTAssertEqual(repository.subscribeURLs, [feedURL])
        XCTAssertEqual(repository.refreshSubscriptionsCallCount, 1)
        XCTAssertTrue(store.isSubscribed(for: feedURL))
    }

    func testSubscriptionsStoreRollsBackFailedUnsubscribe() async {
        let existing = subscription(id: "existing", feedURL: URL(string: "https://example.com/feed.xml")!)
        let repository = SubscriptionStubRepository(
            cachedSubscriptions: [existing],
            refreshedSubscriptions: [existing],
            unsubscribeError: StubError.failed
        )
        let store = SubscriptionsStore(repository: repository)

        await store.load()
        let message = await store.unsubscribe(existing, disposition: .keepInInbox)

        XCTAssertEqual(message, "Couldn’t update this feed. Try again.")
        XCTAssertEqual(repository.unsubscribedIDs, [existing.id])
        XCTAssertEqual(store.subscriptions.map(\.id), [existing.id])
    }

    func testAPIClientMapsHTTPFailureToStatusCode() async {
        MockURLProtocol.configure { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = apiClient()

        do {
            _ = try await client.fetchLinks()
            XCTFail("Expected an HTTP failure")
        } catch let error as ShioriAPIError {
            guard case .requestFailed(let statusCode) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(statusCode, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAPIClientBuildsLinksRequestAndDecodesResponse() async throws {
        let response = """
        { "success": true, "total": 1, "links": [{
          "id": "link-1", "url": "https://example.com/article", "title": "Example", "domain": "example.com",
          "summary": null, "image_url": null, "status": "ready", "source": "rss",
          "created_at": "2026-01-01T12:00:00Z", "updated_at": "2026-01-01T12:00:00Z",
          "read_at": null, "deleted_at": null, "purged_at": null, "hn_url": null, "file_type": null,
          "file_mime_type": null, "notion_page_id": null, "author": null, "discoverable_feed_url": null,
          "subscription_id": "feed-1"
        }] }
        """
        MockURLProtocol.configure { request in
            let httpResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (httpResponse, Data(response.utf8))
        }

        let links = try await apiClient().fetchLinks(read: .unread, trash: true, limit: 10, offset: 20)

        let request = try XCTUnwrap(MockURLProtocol.recordedRequest())
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        let query = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value) }), ["limit": "10", "offset": "20", "read": "unread", "trash": "true"])
        XCTAssertEqual(links.links.first?.subscriptionId, "feed-1")
    }

    func testSharedLinkValidationAcceptsWebURLsOnly() throws {
        XCTAssertNoThrow(try SharedLinkInbox.validate(url: URL(string: "https://example.com")!))
        XCTAssertThrowsError(try SharedLinkInbox.validate(url: URL(string: "file:///tmp/article")!)) { error in
            XCTAssertEqual(error as? SharedLinkInboxError, .unsupportedURL)
        }
        XCTAssertThrowsError(try SharedLinkInbox.validate(url: URL(string: "https:relative")!)) { error in
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

    func subscription(id: String, feedURL: URL) -> Subscription {
        Subscription(id: id, feedUrl: feedURL, title: id)
    }

    func apiClient() -> ShioriAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return ShioriAPIClient(
            baseURL: URL(string: "https://shiori.example/")!,
            apiKeyStore: .preview(apiKey: "test-key"),
            session: URLSession(configuration: configuration)
        )
    }
}

@MainActor
private final class StubRepository: LinksRepository {
    var cachedInbox: [Link]
    var inboxResponses: [LinksResponse]
    var inboxRequests: [(Int, Int)] = []
    var archiveError: Error?
    var archivedIDs: [Link.ID] = []

    init(cachedInbox: [Link], inboxResponse: LinksResponse) {
        self.cachedInbox = cachedInbox
        inboxResponses = [inboxResponse]
    }

    init(cachedInbox: [Link], inboxResponses: [LinksResponse]) {
        self.cachedInbox = cachedInbox
        self.inboxResponses = inboxResponses
    }

    func cachedLinks(for list: LinksList) async -> [Link] { list == .inbox ? cachedInbox : [] }
    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        inboxRequests.append((limit, offset))
        return inboxResponses[min(inboxRequests.count - 1, inboxResponses.count - 1)]
    }
    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse { inboxResponses[0] }
    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse { inboxResponses[0] }
    func createLink(url: URL) async throws {}
    func archiveLink(id: Link.ID) async throws { archivedIDs.append(id); if let archiveError { throw archiveError } }
    func deleteLink(id: Link.ID) async throws {}
    func cachedSubscriptions() async -> [Subscription] { [] }
    func refreshSubscriptions() async throws -> [Subscription] { [] }
    func subscribe(to feedURL: URL, initialSync: Bool) async throws -> Subscription { fatalError("Not used") }
    func fetchLinks(for subscriptionID: Subscription.ID, filter: FeedEntriesFilter) async throws -> [Link] { [] }
    func unsubscribe(id: Subscription.ID, disposition: UnsubscribeDisposition) async throws {}
}

private enum StubError: Error {
    case failed
}

@MainActor
private final class SubscriptionStubRepository: LinksRepository {
    var cached: [Subscription]
    var refreshed: [Subscription]
    var subscribeResult: Result<Subscription, Error>
    var unsubscribeError: Error?
    var subscribeURLs: [URL] = []
    var unsubscribedIDs: [Subscription.ID] = []
    var refreshSubscriptionsCallCount = 0

    init(
        cachedSubscriptions: [Subscription] = [],
        refreshedSubscriptions: [Subscription] = [],
        subscribeResult: Result<Subscription, Error> = .failure(StubError.failed),
        unsubscribeError: Error? = nil
    ) {
        cached = cachedSubscriptions
        refreshed = refreshedSubscriptions
        self.subscribeResult = subscribeResult
        self.unsubscribeError = unsubscribeError
    }

    func cachedLinks(for list: LinksList) async -> [Link] { [] }
    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse { LinksResponse(success: true, links: [], total: 0) }
    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse { LinksResponse(success: true, links: [], total: 0) }
    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse { LinksResponse(success: true, links: [], total: 0) }
    func createLink(url: URL) async throws {}
    func archiveLink(id: Link.ID) async throws {}
    func deleteLink(id: Link.ID) async throws {}
    func cachedSubscriptions() async -> [Subscription] { cached }
    func refreshSubscriptions() async throws -> [Subscription] { refreshSubscriptionsCallCount += 1; return refreshed }
    func subscribe(to feedURL: URL, initialSync: Bool) async throws -> Subscription { subscribeURLs.append(feedURL); return try subscribeResult.get() }
    func fetchLinks(for subscriptionID: Subscription.ID, filter: FeedEntriesFilter) async throws -> [Link] { [] }
    func unsubscribe(id: Subscription.ID, disposition: UnsubscribeDisposition) async throws { unsubscribedIDs.append(id); if let unsubscribeError { throw unsubscribeError } }
}

private final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) private static var lastRequest: URLRequest?

    static func configure(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    static func recordedRequest() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return lastRequest
    }

    static func reset() {
        lock.lock()
        handler = nil
        lastRequest = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.lastRequest = request
        let handler = Self.handler
        Self.lock.unlock()
        do {
            guard let handler else { throw StubError.failed }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
