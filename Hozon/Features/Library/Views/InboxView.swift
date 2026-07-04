import SwiftUI

struct LinksView: View {
    let title: String
    let store: LinksStore
    let showsDateSections: Bool
    let showsArchiveAction: Bool
    let showsDeleteAction: Bool
    @State private var selectedLinkID: Link.ID?
    
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
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)!
        let lastWeek = DateInterval(
            start: calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start)!,
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

    private var selectedLink: Link? {
        guard let selectedLinkID else { return nil }
        return store.links.first { $0.id == selectedLinkID }
    }

    @ViewBuilder
    var body: some View {
        GeometryReader { proxy in
            if usesLandscapeReaderLayout(in: proxy.size) {
                HStack(spacing: 0) {
                    NavigationStack {
                        linksList
                    }
                    .frame(width: selectedLink == nil ? proxy.size.width : listColumnWidth(for: proxy.size))

                    if let selectedLink {
                        Divider()

                        NavigationStack {
                            browserView(for: selectedLink, showsCollapseButton: true)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: selectedLinkID)
            } else {
                NavigationStack {
                    linksList
                        .navigationDestination(item: $selectedLinkID) { linkID in
                            if let link = store.links.first(where: { $0.id == linkID }) {
                                browserView(for: link, showsCollapseButton: false)
                            }
                        }
                }
            }
        }
        .task {
            SafariView.prewarm()
        }
    }

    private func archive(_ link: Link) async {
        if selectedLinkID == link.id {
            selectedLinkID = nil
        }

        await store.archiveLink(link)
    }

    private func delete(_ link: Link) async {
        if selectedLinkID == link.id {
            selectedLinkID = nil
        }

        await store.deleteLink(link)
    }

    private func usesLandscapeReaderLayout(in size: CGSize) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad &&
        size.width > size.height
    }

    private func listColumnWidth(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.34, 300), 420)
    }

    private var linksList: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.links) { link in
                        Button {
                            selectedLinkID = link.id
                        } label: {
                            LinkRowView(link: link)
                        }
                        .buttonStyle(.plain)
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
                            }
                        }
                        .listRowBackground(AppTheme.background)
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
            }

            if store.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(AppTheme.background)
            }
        }
        .navigationTitle(title)
        .listStyle(.grouped)
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
    }

    private func browserView(for link: Link, showsCollapseButton: Bool) -> some View {
        SafariView(url: link.url)
            .navigationTitle(link.domain)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCollapseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedLinkID = nil
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
    }
}
