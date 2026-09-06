import SwiftUI

struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss

    let subscriptionsStore: SubscriptionsStore

    @State private var urlString = ""
    @State private var syncRecents = false
    @State private var errorMessage: String?

    private var feedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host() != nil else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Feed or Website URL") {
                    TextField(
                        "Feed URL",
                        text: $urlString,
                        prompt: Text("https://example.com/feed.xml").foregroundStyle(.secondary)
                    )
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }

                Section {
                    Toggle("Sync Recents", isOn: $syncRecents)
                } footer: {
                    Text("Adds the three most recent publications from this feed to your inbox.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Feed")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(subscriptionsStore.isMutating)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                        .disabled(subscriptionsStore.isMutating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: addFeed)
                        .tint(.primary)
                        .disabled(feedURL == nil || subscriptionsStore.isMutating)
                }
            }
            .overlay {
                if subscriptionsStore.isMutating {
                    ProgressView()
                }
            }
        }
        .presentationSizing(.form)
    }

    private func addFeed() {
        guard let feedURL else { return }
        errorMessage = nil

        Task {
            if let message = await subscriptionsStore.add(feedURL: feedURL, syncRecents: syncRecents) {
                errorMessage = message
            } else {
                dismiss()
            }
        }
    }
}
