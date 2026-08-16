import SwiftUI

@Observable
@MainActor
final class SubscriptionsStore {
    private(set) var subscriptions: [Subscription] = []
    private(set) var hasHydrated = false
    private(set) var isLoading = false
    private(set) var isMutating = false
    private(set) var errorMessage: String?

    private let repository: any LinksRepository
    private var pending: [String: Bool] = [:]

    init(repository: any LinksRepository) {
        self.repository = repository
    }

    func load() async {
        guard !isLoading, !isMutating else { return }
        subscriptions = await repository.cachedSubscriptions()
        hasHydrated = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            subscriptions = try await repository.refreshSubscriptions()
        } catch {
            errorMessage = message(for: error)
        }
    }

    func subscription(for feedURL: URL) -> Subscription? {
        subscriptions.first { $0.feedUrl.absoluteString == feedURL.absoluteString }
    }

    func isSubscribed(for feedURL: URL) -> Bool {
        pending[feedURL.absoluteString] ?? (subscription(for: feedURL) != nil)
    }

    func setSubscribed(_ desired: Bool, for feedURL: URL) async -> String? {
        guard !isLoading, !isMutating else { return nil }
        let previous = subscriptions
        pending[feedURL.absoluteString] = desired
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            if desired {
                do {
                    let subscription = try await repository.subscribe(to: feedURL)
                    subscriptions.removeAll { $0.feedUrl == feedURL }
                    subscriptions.append(subscription)
                } catch let error as ShioriAPIError where error.statusCode == 409 {
                    subscriptions = try await repository.refreshSubscriptions()
                    guard subscription(for: feedURL) != nil else { throw error }
                }
            } else if let subscription = subscription(for: feedURL) {
                try await repository.unsubscribe(id: subscription.id)
                subscriptions.removeAll { $0.id == subscription.id }
            }
            pending.removeValue(forKey: feedURL.absoluteString)
            return nil
        } catch {
            subscriptions = previous
            pending.removeValue(forKey: feedURL.absoluteString)
            return message(for: error)
        }
    }

    private func message(for error: Error) -> String {
        if error is URLError { return "Check your connection and try again." }
        if let error = error as? ShioriAPIError, [401, 403].contains(error.statusCode) {
            return "Check your Shiori API key and try again."
        }
        return "Couldn’t update this feed. Try again."
    }
}
