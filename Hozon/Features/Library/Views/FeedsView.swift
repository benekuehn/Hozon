import SwiftUI

struct FeedsView: View {
    let subscriptionsStore: SubscriptionsStore
    let repository: any LinksRepository
    let isAPIKeyConfigured: Bool

    @State private var isPresentingAddFeed = false

    var body: some View {
        NavigationStack {
            Group {
                if isAPIKeyConfigured {
                    feedsList
                } else {
                    ContentUnavailableView(
                        "Add Your Shiori API Key",
                        systemImage: "key",
                        description: Text("Open Settings in the sidebar to connect your Shiori account.")
                    )
                }
            }
            .navigationTitle("Feeds")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Feed", systemImage: "plus") {
                        isPresentingAddFeed = true
                    }
                    .tint(.primary)
                    .disabled(!isAPIKeyConfigured || subscriptionsStore.isMutating)
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
                        repository: repository
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

private struct AddFeedView: View {
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
                    Button("Cancel") { dismiss() }
                        .disabled(subscriptionsStore.isMutating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addFeed()
                    }
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

private struct FeedDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription
    let subscriptionsStore: SubscriptionsStore
    @State private var store: FeedLinksStore
    @State private var selectedLink: Link?
    @State private var websitePresentation: BrowserPresentation?
    @State private var isPresentingUnsubscribe = false
    @State private var errorMessage: String?

    init(
        subscription: Subscription,
        subscriptionsStore: SubscriptionsStore,
        repository: any LinksRepository
    ) {
        self.subscription = subscription
        self.subscriptionsStore = subscriptionsStore
        _store = State(initialValue: FeedLinksStore(subscriptionID: subscription.id, repository: repository))
    }

    private var filterBinding: Binding<FeedEntriesFilter> {
        Binding(
            get: { store.filter },
            set: { newFilter in store.filter = newFilter }
        )
    }

    private var filterPicker: some View {
        Picker("Entries", selection: filterBinding) {
            Text("All").tag(FeedEntriesFilter.all)
            Text("Inbox").tag(FeedEntriesFilter.inbox)
            Text("Archive").tag(FeedEntriesFilter.archive)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    var body: some View {
        List(store.links) { link in
            Button {
                selectedLink = link
            } label: {
                LinkRowView(link: link)
            }
            .buttonStyle(.plain)
            .listRowBackground(AppTheme.rowBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(subscription.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            filterPicker
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        if let siteURL = subscription.siteUrl {
                            websitePresentation = BrowserPresentation(url: siteURL)
                        }
                    } label: {
                        Label("Open Website", systemImage: "safari")
                    }
                    .disabled(subscription.siteUrl == nil)

                    Divider()

                    Button {
                        isPresentingUnsubscribe = true
                    } label: {
                        Label("Unsubscribe", systemImage: "minus.circle")
                    }
                    .disabled(subscriptionsStore.isMutating)
                } label: {
                    Image(systemName: "ellipsis")
                        .accessibilityLabel("Feed Actions")
                }
                .tint(.primary)
            }
        }
        .overlay {
            if store.isLoading && store.links.isEmpty {
                ProgressView()
            } else if let errorMessage = store.errorMessage, store.links.isEmpty {
                ContentUnavailableView(
                    "Could Not Load Entries",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if !store.isLoading && store.links.isEmpty {
                ContentUnavailableView(
                    "No \(store.filter.rawValue) Entries",
                    systemImage: "doc.text"
                )
            }
        }
        .task(id: store.filter) {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
        .fullScreenCover(item: $selectedLink) { link in
            BrowserSheetView(url: link.url)
        }
        .fullScreenCover(item: $websitePresentation) { presentation in
            BrowserSheetView(url: presentation.url)
        }
        .alert(
            "Unsubscribe from \(subscription.displayTitle)?",
            isPresented: $isPresentingUnsubscribe,
        ) {
            Button("Keep Unread in Inbox") {
                unsubscribe(.keepInInbox)
            }
            Button("Archive Unread") {
                unsubscribe(.archiveUnread)
            }
            Button("Move Unread to Trash", role: .destructive) {
                unsubscribe(.trashUnread)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose what should happen to unread entries already saved from this feed.")
        }
        .alert("Couldn’t Unsubscribe", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func unsubscribe(_ disposition: UnsubscribeDisposition) {
        Task {
            if let message = await subscriptionsStore.unsubscribe(subscription, disposition: disposition) {
                errorMessage = message
            } else {
                dismiss()
            }
        }
    }
}

private struct BrowserPresentation: Identifiable {
    let url: URL

    var id: URL { url }
}
