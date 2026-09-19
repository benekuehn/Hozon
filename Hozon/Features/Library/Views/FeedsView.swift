import SwiftUI

struct FeedsView: View {
    let subscriptionsStore: SubscriptionsStore
    let repository: any LinksRepository
    let linkOpeningPreferenceStore: LinkOpeningPreferenceStore

    @State private var isPresentingAddFeed = false

    var body: some View {
        NavigationStack {
            feedsList
                .navigationTitle("Feeds")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Feed", systemImage: "plus") {
                        isPresentingAddFeed = true
                    }
                    .tint(.primary)
                    .disabled(subscriptionsStore.isMutating)
                }
            }
            .sheet(isPresented: $isPresentingAddFeed) {
                AddFeedView(subscriptionsStore: subscriptionsStore)
            }
        }
    }

    private var feedsList: some View {
        List {
            ForEach(subscriptionsStore.subscriptions.sorted(by: feedSort)) { subscription in
                NavigationLink {
                    FeedDetailView(
                        subscription: subscription,
                        subscriptionsStore: subscriptionsStore,
                        repository: repository,
                        linkOpeningPreferenceStore: linkOpeningPreferenceStore
                    )
                } label: {
                    FeedRowView(subscription: subscription)
                }
                .listRowBackground(AppTheme.rowBackground)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .refreshable {
            await subscriptionsStore.load()
        }
        .overlay {
            if subscriptionsStore.isLoading && subscriptionsStore.subscriptions.isEmpty {
                ProgressView()
            } else if let errorMessage = subscriptionsStore.errorMessage,
                      subscriptionsStore.subscriptions.isEmpty {
                ContentUnavailableView(
                    "Could Not Load Feeds",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if subscriptionsStore.hasHydrated && subscriptionsStore.subscriptions.isEmpty {
                ContentUnavailableView(
                    "No Feeds Yet",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text("Tap the plus button to subscribe to an RSS or Atom feed.")
                )
            }
        }
    }

    private func feedSort(_ lhs: Subscription, _ rhs: Subscription) -> Bool {
        lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
    }
}

private struct FeedRowView: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: subscription.iconUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.rowIconBackground)
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.displayTitle)
                    .font(.body.weight(.medium))

                Text(subscription.siteUrl?.host() ?? subscription.feedUrl.host() ?? subscription.feedUrl.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
