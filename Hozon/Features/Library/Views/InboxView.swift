import SwiftUI

struct LinksView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let store: LinksStore
    let subscriptionsStore: SubscriptionsStore
    let linkOpeningPreferenceStore: LinkOpeningPreferenceStore
    let showsDateSections: Bool
    let showsArchiveAction: Bool
    let showsDeleteAction: Bool
    @State private var selectedLink: Link?
    @State private var websitePresentation: BrowserPresentation?
    
    private enum InboxBucket: String, CaseIterable, Identifiable {
        case today = "Today"
        case thisWeek = "This Week"
        case lastWeek = "Last Week"
        case older = "Older"

        var id: Self { self }
    }

    private struct LinkSection: Identifiable {
        let title: String?
        let links: [Link]

        var id: String { title ?? "links" }
    }

    private var sections: [LinkSection] {
        guard showsDateSections else {
            return store.links.isEmpty ? [] : [LinkSection(title: nil, links: store.links)]
        }

        let calendar = Calendar.current
        let now = Date()
        guard
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now),
            let previousWeekStart = calendar.date(
                byAdding: .weekOfYear,
                value: -1,
                to: thisWeek.start
            )
        else {
            return [LinkSection(title: nil, links: store.links)]
        }
        let lastWeek = DateInterval(
            start: previousWeekStart,
            end: thisWeek.start
        )

        let grouped: [InboxBucket: [Link]] = Dictionary(grouping: store.links) { link in
            if calendar.isDate(link.createdAt, inSameDayAs: now) { return InboxBucket.today }
            if thisWeek.contains(link.createdAt) { return InboxBucket.thisWeek }
            if lastWeek.contains(link.createdAt) { return InboxBucket.lastWeek }
            return InboxBucket.older
        }

        return InboxBucket.allCases.compactMap { bucket in
            guard let links = grouped[bucket], !links.isEmpty else { return nil }
            return LinkSection(title: bucket.rawValue, links: links)
        }
    }

    var body: some View {
        NavigationStack {
            linksList
        }
        .sheet(item: $selectedLink) { link in
            ReaderSheetView(link: link)
                .presentationSizing(.page)
        }
    }

    private func archive(_ link: Link) async {
        if selectedLink?.id == link.id {
            selectedLink = nil
        }

        await store.archiveLink(link)
    }

    private func delete(_ link: Link) async {
        if selectedLink?.id == link.id {
            selectedLink = nil
        }

        await store.deleteLink(link)
    }

    private var linksList: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.links) { link in
                        linkRow(for: link)
                            .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }

            if store.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(AppTheme.listCardBackground)
                .listRowSeparator(.hidden)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .listStyle(.insetGrouped)
        .refreshable {
            await store.load()
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .overlay {
            if store.isLoading {
                ProgressView()
            } else if let errorMessage = store.errorMessage, store.links.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Could not load \(title.lowercased())")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        Task {
                            await store.load()
                        }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .fullScreenCover(item: $websitePresentation) { presentation in
            BrowserSheetView(url: presentation.url)
        }
    }

    private func linkRow(for link: Link) -> some View {
        Button {
            open(link)
        } label: {
            LinkRowView(link: link)
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .onAppear {
            Task {
                await store.loadNextPageIfNeeded(currentLink: link)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: showsArchiveAction) {
            if showsArchiveAction {
                Button {
                    Task {
                        await archive(link)
                    }
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .tint(.gray)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: showsDeleteAction) {
            if showsDeleteAction {
                Button(role: .destructive) {
                    Task {
                        await delete(link)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)

                FeedOptionsMenu(link: link, subscriptionsStore: subscriptionsStore)
                .tint(.gray)
            }
        }
        .listRowBackground(AppTheme.rowBackground)
    }

    private func open(_ link: Link) {
        if linkOpeningPreferenceStore.preference.opensInReader(for: colorScheme) {
            selectedLink = link
        } else {
            selectedLink = nil
            websitePresentation = BrowserPresentation(url: link.url)
        }
    }
}

private struct FeedOptionsMenu: View {
    let link: Link
    let subscriptionsStore: SubscriptionsStore
    @State private var errorMessage: String?

    var body: some View {
        Menu {
            Group {
                if let feedURL = link.discoverableFeedUrl {
                    if !subscriptionsStore.hasHydrated {
                        Label("Checking Feed", systemImage: "antenna.radiowaves.left.and.right")
                            .disabled(true)
                    } else {
                        Toggle("Subscribe to Feed", isOn: Binding(
                            get: { subscriptionsStore.isSubscribed(for: feedURL) },
                            set: { isSubscribed, _ in
                                Task {
                                    errorMessage = await subscriptionsStore.setSubscribed(isSubscribed, for: feedURL)
                                }
                            }
                        ))
                        .disabled(subscriptionsStore.isMutating || subscriptionsStore.isLoading)
                    }
                } else {
                    Label("Feed Unavailable", systemImage: "antenna.radiowaves.left.and.right")
                        .disabled(true)
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .alert("Couldn’t Update Feed", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

}
