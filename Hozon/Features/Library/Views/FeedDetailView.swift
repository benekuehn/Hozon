import SwiftUI

struct FeedDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let subscription: Subscription
    let subscriptionsStore: SubscriptionsStore
    let linkOpeningPreferenceStore: LinkOpeningPreferenceStore

    @State private var store: FeedLinksStore
    @State private var selectedLink: Link?
    @State private var websitePresentation: BrowserPresentation?
    @State private var isPresentingUnsubscribe = false
    @State private var errorMessage: String?

    init(
        subscription: Subscription,
        subscriptionsStore: SubscriptionsStore,
        repository: any LinksRepository,
        linkOpeningPreferenceStore: LinkOpeningPreferenceStore
    ) {
        self.subscription = subscription
        self.subscriptionsStore = subscriptionsStore
        self.linkOpeningPreferenceStore = linkOpeningPreferenceStore
        _store = State(initialValue: FeedLinksStore(subscriptionID: subscription.id, repository: repository))
    }

    var body: some View {
        List(store.links) { link in
            Button {
                open(link)
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
            FeedFilterPicker(filter: filterBinding)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                feedActionsMenu
            }
        }
        .overlay {
            feedStateOverlay
        }
        .task(id: store.filter) {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
        .sheet(item: $selectedLink) { link in
            ReaderSheetView(link: link)
                .presentationSizing(.page)
        }
        .fullScreenCover(item: $websitePresentation) { presentation in
            BrowserSheetView(url: presentation.url)
        }
        .confirmationDialog(
            "Unsubscribe from \(subscription.displayTitle)?",
            isPresented: $isPresentingUnsubscribe,
            titleVisibility: .visible
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
        .alert("Couldn’t Unsubscribe", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var filterBinding: Binding<FeedEntriesFilter> {
        Binding(
            get: { store.filter },
            set: { store.filter = $0 }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var feedActionsMenu: some View {
        Menu {
            Button("Open Website", systemImage: "safari", action: openWebsite)
                .disabled(subscription.siteUrl == nil)

            Divider()

            Button("Unsubscribe", systemImage: "minus.circle", action: presentUnsubscribeOptions)
                .disabled(subscriptionsStore.isMutating)
        } label: {
            Image(systemName: "ellipsis")
                .accessibilityLabel("Feed Actions")
        }
        .tint(.primary)
    }

    @ViewBuilder
    private var feedStateOverlay: some View {
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

    private func openWebsite() {
        guard let siteURL = subscription.siteUrl else { return }
        websitePresentation = BrowserPresentation(url: siteURL)
    }

    private func open(_ link: Link) {
        if linkOpeningPreferenceStore.preference.opensInReader(for: colorScheme) {
            selectedLink = link
        } else {
            selectedLink = nil
            websitePresentation = BrowserPresentation(url: link.url)
        }
    }

    private func presentUnsubscribeOptions() {
        isPresentingUnsubscribe = true
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

private struct FeedFilterPicker: View {
    @Binding var filter: FeedEntriesFilter

    var body: some View {
        Picker("Entries", selection: $filter) {
            Text("All").tag(FeedEntriesFilter.all)
            Text("Inbox").tag(FeedEntriesFilter.inbox)
            Text("Archive").tag(FeedEntriesFilter.archive)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
