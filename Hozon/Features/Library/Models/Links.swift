import Foundation

struct LinksResponse: Decodable, Sendable {
    let success: Bool
    let links: [Link]
    let total: Int
}

struct Subscription: Codable, Sendable, Identifiable {
    let id: String
    let feedUrl: URL
}

struct SubscriptionsResponse: Decodable {
    let subscriptions: [Subscription]
}

struct SubscriptionResponse: Decodable {
    let subscription: Subscription
}

struct Link: Identifiable, Codable, Sendable {
    let id: String
    let url: URL
    let title: String
    let domain: String
    let summary: String?
    let imageUrl: URL?
    let status: LinkStatus
    let source: LinkSource
    let createdAt: Date
    let updatedAt: Date
    let readAt: Date?
    let deletedAt: Date?
    let purgedAt: Date?
    let hnUrl: URL?
    let fileType: String?
    let fileMimeType: String?
    let notionPageId: String?
    let author: String?
    let discoverableFeedUrl: URL?
}

enum LinkStatus: String, Codable, Sendable {
    case created
    case processing
    case ready
    case failed
}

enum LinkSource: String, Codable, Sendable {
    case api
    case web
    case extensionSource = "extension"
    case email
    case rss
    case shortcut
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = LinkSource(rawValue: rawValue) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
