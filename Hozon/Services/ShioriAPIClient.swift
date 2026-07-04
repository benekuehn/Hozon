import Foundation

enum ShioriAPIError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, body: String)
    case responseDecodingFailed(String)

    var errorDescription: String? {
        switch self {
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
    let apiKey: String
    
    private func request(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
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

}
