import SwiftUI

private enum AppTab: Hashable {
    case search
    case inbox
    case archive
    case trash
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .inbox
    @State private var inboxStore: LinksStore
    @State private var archiveStore: LinksStore
    @State private var trashStore: LinksStore
    @State private var subscriptionsStore: SubscriptionsStore

    private let environment: AppEnv

    init(environment: AppEnv = .live) {
        self.environment = environment
        _inboxStore = State(
            initialValue: LinksStore(
                repository: environment.linksRepository,
                list: .inbox
            )
        )
        _archiveStore = State(
            initialValue: LinksStore(
                repository: environment.linksRepository,
                list: .archive
            )
        )
        _trashStore = State(
            initialValue: LinksStore(
                repository: environment.linksRepository,
                list: .trash
            )
        )
        _subscriptionsStore = State(
            initialValue: SubscriptionsStore(repository: environment.linksRepository)
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .search, role: .search) {
                Text("Search")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background)
            }

            Tab("Inbox", systemImage: "tray", value: .inbox) {
                LinksView(
                    title: "Inbox",
                    store: inboxStore,
                    subscriptionsStore: subscriptionsStore,
                    showsDateSections: true,
                    showsArchiveAction: true,
                    showsDeleteAction: true
                )
            }

            Tab("Archive", systemImage: "archivebox", value: .archive) {
                LinksView(
                    title: "Archive",
                    store: archiveStore,
                    subscriptionsStore: subscriptionsStore,
                    showsDateSections: false,
                    showsArchiveAction: false,
                    showsDeleteAction: true
                )
            }

            Tab("Trash", systemImage: "trash", value: .trash) {
                LinksView(
                    title: "Trash",
                    store: trashStore,
                    subscriptionsStore: subscriptionsStore,
                    showsDateSections: false,
                    showsArchiveAction: false,
                    showsDeleteAction: false
                )
            }
            .tabPlacement(.sidebarOnly)
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(.sidebar)
        .background(AppTheme.background)
        .tint(AppTheme.accent)
        .task(id: selectedTab) {
            await refreshSelectedTab()
        }
        .task {
            await subscriptionsStore.load()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshSelectedTab()
                await subscriptionsStore.load()
            }
        }
    }

    private func refreshSelectedTab() async {
        switch selectedTab {
        case .search:
            break
        case .inbox:
            await inboxStore.load()
        case .archive:
            await archiveStore.load()
        case .trash:
            await trashStore.load()
        }
    }
}

#Preview {
    RootView(
        environment: AppEnv(
            linksRepository: PreviewLinksRepository()
        )
    )
}

private struct PreviewLinksRepository: LinksRepository {
    func cachedLinks(for list: LinksList) async -> [Link] {
        list == .inbox ? previewLinks() : []
    }

    func refreshInboxLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        let links = Array(previewLinks().dropFirst(offset).prefix(limit))
        return LinksResponse(success: true, links: links, total: previewLinks().count)
    }

    private func previewLinks() -> [Link] {
        [
            previewLink(
                id: "preview-1",
                title: "Designing a Native iPad Reading App",
                domain: "example.com",
                feedURL: URL(string: "https://example.com/feed.xml")
            ),
            previewLink(
                id: "preview-2",
                title: "SwiftUI Navigation Patterns",
                domain: "developer.apple.com"
            )
        ]
    }

    func fetchArchiveLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        LinksResponse(success: true, links: [], total: 0)
    }

    func fetchTrashLinks(limit: Int, offset: Int) async throws -> LinksResponse {
        LinksResponse(success: true, links: [], total: 0)
    }
    
    func deleteLink(id: Link.ID) async throws {
        // No-op for previews.
    }
    
    func archiveLink(id: Link.ID) async throws {
        // No-op for previews.
    }

    func cachedSubscriptions() async -> [Subscription] { [] }

    func refreshSubscriptions() async throws -> [Subscription] { [] }

    func subscribe(to feedURL: URL) async throws -> Subscription {
        Subscription(id: "preview-subscription", feedUrl: feedURL)
    }

    func unsubscribe(id: Subscription.ID) async throws {
        // No-op for previews.
    }

    private func previewLink(id: String, title: String, domain: String, feedURL: URL? = nil) -> Link {
        let url = URL(string: "https://\(domain)") ?? URL(fileURLWithPath: "/")
        let now = Date()

        return Link(
            id: id,
            url: url,
            title: title,
            domain: domain,
            summary: "Preview summary",
            imageUrl: nil,
            status: .ready,
            source: .api,
            createdAt: now,
            updatedAt: now,
            readAt: nil,
            deletedAt: nil,
            purgedAt: nil,
            hnUrl: nil,
            fileType: nil,
            fileMimeType: nil,
            notionPageId: nil,
            author: nil,
            discoverableFeedUrl: feedURL
        )
    }
}
