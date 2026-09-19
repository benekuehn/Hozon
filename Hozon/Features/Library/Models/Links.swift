import Foundation

struct LinksResponse: Decodable, Sendable {
    let success: Bool
    let links: [Link]
    let total: Int
}

struct Subscription: Codable, Sendable, Identifiable {
    let id: String
    let feedUrl: URL
    let title: String?
    let description: String?
    let siteUrl: URL?
    let iconUrl: URL?
    let lastSyncedAt: Date?

    init(
        id: String,
        feedUrl: URL,
        title: String? = nil,
        description: String? = nil,
        siteUrl: URL? = nil,
        iconUrl: URL? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.feedUrl = feedUrl
        self.title = title
        self.description = description
        self.siteUrl = siteUrl
        self.iconUrl = iconUrl
        self.lastSyncedAt = lastSyncedAt
    }
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
    let subscriptionId: String?

    init(
        id: String,
        url: URL,
        title: String,
        domain: String,
        summary: String?,
        imageUrl: URL?,
        status: LinkStatus,
        source: LinkSource,
        createdAt: Date,
        updatedAt: Date,
        readAt: Date?,
        deletedAt: Date?,
        purgedAt: Date?,
        hnUrl: URL?,
        fileType: String?,
        fileMimeType: String?,
        notionPageId: String?,
        author: String?,
        discoverableFeedUrl: URL?,
        subscriptionId: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.domain = domain
        self.summary = summary
        self.imageUrl = imageUrl
        self.status = status
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.readAt = readAt
        self.deletedAt = deletedAt
        self.purgedAt = purgedAt
        self.hnUrl = hnUrl
        self.fileType = fileType
        self.fileMimeType = fileMimeType
        self.notionPageId = notionPageId
        self.author = author
        self.discoverableFeedUrl = discoverableFeedUrl
        self.subscriptionId = subscriptionId
    }
}

enum LinkStatus: String, Codable, Sendable {
    case created
    case processing
    case ready
    case failed
    case error
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = LinkStatus(rawValue: rawValue) ?? .unknown
    }
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
