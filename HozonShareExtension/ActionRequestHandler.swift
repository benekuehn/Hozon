import Foundation
import OSLog
import UniformTypeIdentifiers

final class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    private static let logger = Logger(
        subsystem: "benekuehn.Hozon.ActionExtension",
        category: "AddToHozon"
    )

    func beginRequest(with context: NSExtensionContext) {
        Self.logger.info("Action request received")

        guard let input = Self.supportedInput(in: context) else {
            Self.logger.error("No supported URL, webpage, or text input was provided")
            context.cancelRequest(withError: SharedLinkInboxError.unsupportedURL)
            return
        }

        input.provider.loadItem(forTypeIdentifier: input.typeIdentifier, options: nil) { item, error in
            if let error {
                Self.logger.error("Loading shared input failed: \(error.localizedDescription, privacy: .public)")
                context.cancelRequest(withError: error)
                return
            }

            guard let url = Self.url(from: item, typeIdentifier: input.typeIdentifier),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                Self.logger.error("Shared input did not contain an HTTP URL")
                context.cancelRequest(withError: SharedLinkInboxError.unsupportedURL)
                return
            }

            Task { @MainActor in
                do {
                    guard let apiKey = try SharedAPIKey.read() else {
                        throw AddToHozonError.apiKeyNotConfigured
                    }
                    try await Self.addToInbox(url: url, apiKey: apiKey)
                    Self.logger.info("Link delivered directly to Shiori")
                } catch {
                    Self.logger.error("Direct delivery failed; queueing retry: \(error.localizedDescription, privacy: .public)")
                    // Preserve the link for the containing app to retry later.
                    // The action still completes without presenting more UI.
                    do {
                        try SharedLinkInbox.enqueue(url: url)
                    } catch {
                        Self.logger.fault("Queueing retry failed: \(error.localizedDescription, privacy: .public)")
                        context.cancelRequest(withError: error)
                        return
                    }
                }

                context.completeRequest(returningItems: nil)
            }
        }
    }

    private static func addToInbox(url: URL, apiKey: String) async throws {
        var request = URLRequest(url: URL(string: "https://www.shiori.sh/api/links")!)
        request.assumesHTTP3Capable = false
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateLinkRequest(url: url.absoluteString))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AddToHozonError.requestFailed
        }
    }

    private static func supportedInput(in context: NSExtensionContext) -> SharedInput? {
        let providers = context.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }

        let supportedTypes = [
            UTType.url.identifier,
            UTType.propertyList.identifier,
            UTType.plainText.identifier
        ]

        for typeIdentifier in supportedTypes {
            if let provider = providers.first(where: {
                $0.hasItemConformingToTypeIdentifier(typeIdentifier)
            }) {
                return SharedInput(provider: provider, typeIdentifier: typeIdentifier)
            }
        }

        return nil
    }

    private static func url(from item: NSSecureCoding?, typeIdentifier: String) -> URL? {
        if typeIdentifier == UTType.propertyList.identifier,
           let dictionary = item as? [String: Any],
           let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any],
           let urlString = results["url"] as? String {
            return URL(string: urlString)
        }

        return switch item {
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

private struct SharedInput {
    let provider: NSItemProvider
    let typeIdentifier: String
}

private struct CreateLinkRequest: Encodable {
    let url: String
}

private enum AddToHozonError: LocalizedError {
    case apiKeyNotConfigured
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            "Add your Shiori API key in Hozon before using this action."
        case .requestFailed:
            "Hozon could not add this link to your inbox."
        }
    }
}
