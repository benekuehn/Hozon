import Social
import UniformTypeIdentifiers
import UIKit

final class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool {
        urlItemProvider != nil
    }

    override func didSelectPost() {
        guard let provider = urlItemProvider else {
            cancel(with: SharedLinkInboxError.unsupportedURL)
            return
        }

        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            guard let self else { return }

            if let error {
                self.cancel(with: error)
                return
            }

            guard let url = Self.url(from: item) else {
                self.cancel(with: SharedLinkInboxError.unsupportedURL)
                return
            }

            do {
                try SharedLinkInbox.enqueue(url: url)
                self.extensionContext?.completeRequest(returningItems: nil)
            } catch {
                self.cancel(with: error)
            }
        }
    }

    private var urlItemProvider: NSItemProvider? {
        extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }
    }

    private func cancel(with error: Error) {
        extensionContext?.cancelRequest(withError: error)
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL:
            url
        case let url as NSURL:
            url as URL
        case let string as String:
            URL(string: string)
        default:
            nil
        }
    }
}
