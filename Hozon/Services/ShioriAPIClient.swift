import Foundation
import OSLog

enum LinkReadFilter: String, Sendable {
    case all
    case unread
    case read
}

enum ShioriAPIError: LocalizedError {
    case apiKeyNotConfigured
    case invalidResponse
    case requestFailed(statusCode: Int)
    case transportFailed
    case responseDecodingFailed(String)

    var statusCode: Int? {
        guard case let .requestFailed(statusCode) = self else { return nil }
        return statusCode
    }

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "Add your Shiori API key in Settings to load links."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .requestFailed(let statusCode):
            return "Shiori API returned HTTP \(statusCode)."
        case .transportFailed:
            return "Could not connect to Shiori. Check your connection and try again."
        case .responseDecodingFailed(let message):
            return "Could not decode the Shiori API response: \(message)"
        }
    }
}

struct ShioriAPIClient {
    let baseURL: URL
    let apiKeyStore: ShioriAPIKeyStore
    private let session: URLSession

    private static let logger = Logger(subsystem: "com.benekuehn.Hozon", category: "ShioriAPI")

    init(
        baseURL: URL,
        apiKeyStore: ShioriAPIKeyStore,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKeyStore = apiKeyStore
        self.session = session
    }
    
    private func request(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
        guard let apiKey = apiKeyStore.apiKey else {
            throw ShioriAPIError.apiKeyNotConfigured
        }

        let url: URL

        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw ShioriAPIError.invalidResponse
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let resolvedURL = components.url else {
            throw ShioriAPIError.invalidResponse
        }
        url = resolvedURL

        var request = URLRequest(url: url)
        request.assumesHTTP3Capable = false
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.error("Request failed. method=\(method, privacy: .public) error=\(error.localizedDescription, privacy: .private(mask: .hash))")
            throw ShioriAPIError.transportFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Received a non-HTTP response. method=\(method, privacy: .public)")
            throw ShioriAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            Self.logger.error("Request failed. method=\(method, privacy: .public) status=\(httpResponse.statusCode, privacy: .public)")
            throw ShioriAPIError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return data
    }

    func fetchLinks(
        read: LinkReadFilter = .all,
        trash: Bool = false,
        limit: Int = 25,
        offset: Int = 0
    ) async throws -> LinksResponse {
        var queryItems: [URLQueryItem] = []

        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))

        if read != .all {
            queryItems.append(URLQueryItem(name: "read", value: read.rawValue))
        }

        if trash {
            queryItems.append(URLQueryItem(name: "trash", value: "true"))
        }

        let data = try await request(
            path: "api/links",
            method: "GET",
            queryItems: queryItems
        )

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(LinksResponse.self, from: data)
        } catch {
            throw ShioriAPIError.responseDecodingFailed(String(describing: error))
        }
    }

    func fetchLinks(for subscriptionID: Subscription.ID, read: LinkReadFilter) async throws -> [Link] {
        let pageSize = 1000
        var offset = 0
        var matchingLinks: [Link] = []

        while true {
            let response = try await fetchLinks(read: read, limit: pageSize, offset: offset)
            matchingLinks += response.links.filter { $0.subscriptionId == subscriptionID }
            offset += response.links.count

            if response.links.isEmpty || offset >= response.total {
                return matchingLinks
            }
        }
    }

    func createLink(url: URL) async throws {
        let body = try JSONEncoder().encode(CreateLinkRequest(url: url.absoluteString))
        _ = try await request(path: "api/links", method: "POST", body: body)
    }

    func archiveLink(id: Link.ID) async throws {
        let body = try JSONEncoder().encode(["read": true])

        _ = try await request(
            path: "api/links/\(id)",
            method: "PATCH",
            body: body
        )
    }

    func deleteLink(id: Link.ID) async throws {
        _ = try await request(
            path: "api/links/\(id)",
            method: "DELETE"
        )
    }

    func fetchSubscriptions() async throws -> [Subscription] {
        let data = try await request(path: "api/subscriptions", method: "GET")
        return try decode(SubscriptionsResponse.self, from: data).subscriptions
    }

    func subscribe(to feedURL: URL, initialSync: Bool) async throws -> Subscription {
        let body = try JSONEncoder().encode(
            SubscriptionRequest(feedUrl: feedURL.absoluteString, initialSync: initialSync)
        )
        let data = try await request(path: "api/subscriptions", method: "POST", body: body)
        return try decode(SubscriptionResponse.self, from: data).subscription
    }

    func unsubscribe(id: Subscription.ID) async throws {
        _ = try await request(path: "api/subscriptions/\(id)", method: "DELETE")
    }

    func archiveLinks(ids: [Link.ID]) async throws {
        guard !ids.isEmpty else { return }
        let body = try JSONEncoder().encode(BulkReadRequest(ids: ids, read: true))
        _ = try await request(path: "api/links", method: "PATCH", body: body)
    }

    func deleteLinks(ids: [Link.ID]) async throws {
        guard !ids.isEmpty else { return }
        let body = try JSONEncoder().encode(BulkDeleteRequest(ids: ids, deleted: true))
        _ = try await request(path: "api/links", method: "PATCH", body: body)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ShioriAPIError.responseDecodingFailed(String(describing: error))
        }
    }

}

private struct SubscriptionRequest: Encodable {
    let feedUrl: String
    let initialSync: Bool
}

private struct CreateLinkRequest: Encodable {
    let url: String
}

private struct BulkReadRequest: Encodable {
    let ids: [Link.ID]
    let read: Bool
}

private struct BulkDeleteRequest: Encodable {
    let ids: [Link.ID]
    let deleted: Bool
}
