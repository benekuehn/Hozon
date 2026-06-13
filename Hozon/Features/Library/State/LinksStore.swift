import SwiftUI

@Observable
final class LinksStore {
    private(set) var links: [Link] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: any LinksRepository

    init(repository: any LinksRepository) {
        self.repository = repository
    }

    func loadInbox() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            links = try await repository.fetchInboxLinks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
