import Foundation

/// The small, presentation-friendly result of extracting an article from a webpage.
///
/// We intentionally keep the body as plain semantic blocks rather than arbitrary
/// webpage HTML. That lets the reader use native SwiftUI typography and prevents a
/// site’s styles, scripts, or tracking markup from becoming part of the app UI.
struct ArticleDocument: Sendable {
    let url: URL
    let title: String
    let siteName: String?
    let byline: String?
    let blocks: [ArticleBlock]
}

struct ArticleBlock: Sendable, Hashable {
    enum Kind: String, Decodable, Sendable {
        case heading
        case paragraph
        case quote
        case listItem
    }

    let kind: Kind
    let text: String
}
