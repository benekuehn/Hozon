import SwiftUI

@Observable
@MainActor
final class FeedLinksStore {
    private(set) var links: [Link] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var filter: FeedEntriesFilter = .inbox

    private let subscriptionID: Subscription.ID
    private let repository: any LinksRepository
    private var activeRequestID: UUID?

    init(subscriptionID: Subscription.ID, repository: any LinksRepository) {
        self.subscriptionID = subscriptionID
        self.repository = repository
    }

    func load() async {
        let requestedFilter = filter
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil

        do {
            let fetchedLinks = try await repository.fetchLinks(for: subscriptionID, filter: requestedFilter)
            guard activeRequestID == requestID, filter == requestedFilter else { return }
            links = fetchedLinks
        } catch is CancellationError {
            // A newer filter or refresh owns the visible state.
        } catch {
            guard activeRequestID == requestID, filter == requestedFilter else { return }
            errorMessage = error.localizedDescription
        }

        if activeRequestID == requestID {
            isLoading = false
        }
    }
}
