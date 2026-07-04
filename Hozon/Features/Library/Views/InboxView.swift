import SwiftUI

struct LinksView: View {
    let title: String
    let store: LinksStore
    let showsDateSections: Bool
    let showsArchiveAction: Bool
    let showsDeleteAction: Bool
    @State private var selectedLink: Link?
    
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.links) { link in
                            Button {
                                selectedLink = link
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
                                            await store.archiveLink(link)
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
                                            await store.deleteLink(link)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }    
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
                }
            }
            .navigationTitle(title)
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
            .sheet(item: $selectedLink) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
        }
    }
}
