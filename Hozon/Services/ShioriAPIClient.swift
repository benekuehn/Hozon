import Foundation

enum ShioriAPIError: LocalizedError {
    case apiKeyNotConfigured
    case invalidResponse
    case requestFailed(statusCode: Int, body: String)
    case responseDecodingFailed(String)

    var statusCode: Int? {
        guard case let .requestFailed(statusCode, _) = self else { return nil }
        return statusCode
    }

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "Add your Shiori API key in Settings to load links."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .requestFailed(let statusCode, let body):
            if body.isEmpty {
                return "Shiori API returned HTTP \(statusCode)."
            }

            return "Shiori API returned HTTP \(statusCode): \(body)"
        case .responseDecodingFailed(let message):
            return "Could not decode the Shiori API response: \(message)"
        }
    }
}

struct ShioriAPIClient {
    let baseURL: URL
    let apiKeyStore: ShioriAPIKeyStore
    
    private func request(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
        guard let apiKey = apiKeyStore.apiKey else {
            throw ShioriAPIError.apiKeyNotConfigured
        }

        var url = baseURL.appending(path: path)

        if !queryItems.isEmpty {
            var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = queryItems
            url = components.url!
        }

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
        let session = URLSession(configuration: .ephemeral)

        do {
            defer {
                session.finishTasksAndInvalidate()
            }

            (data, response) = try await session.data(for: request)
        } catch {
            print("Shiori API <- \(method) \(url.absoluteString) failed: \(error.localizedDescription)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("Shiori API <- \(method) \(url.absoluteString) invalid response")
            throw ShioriAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw ShioriAPIError.requestFailed(
                statusCode: httpResponse.statusCode,
                body: responseBody
            )
        }

        return data
    }

    func fetchLinks(
        read: String = "all",
        trash: Bool = false,
        limit: Int = 25,
        offset: Int = 0
    ) async throws -> LinksResponse {
        var queryItems: [URLQueryItem] = []

        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))

        if read != "all" {
            queryItems.append(URLQueryItem(name: "read", value: read))
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

    func fetchLinks(for subscriptionID: Subscription.ID, read: String) async throws -> [Link] {
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
