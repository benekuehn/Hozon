import SwiftUI

private enum AppTab: Hashable {
    case inbox
    case feeds
    case archive
    case trash
    case settings
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

            Tab("Feeds", systemImage: "dot.radiowaves.left.and.right", value: .feeds) {
                FeedsView(
                    subscriptionsStore: subscriptionsStore,
                    repository: environment.linksRepository
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

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView(apiKeyStore: environment.apiKeyStore)
            }
            .tabPlacement(.pinned)
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(.sidebar)
        .sheet(isPresented: Binding(
            get: { !environment.apiKeyStore.hasAPIKey },
            set: { _ in }
        )) {
            APIKeyOnboardingView(apiKeyStore: environment.apiKeyStore)
                .interactiveDismissDisabled()
                .presentationSizing(.form)
        }
        .task(id: selectedTab) {
            await refreshSelectedTab()
        }
        .task(id: environment.apiKeyStore.hasAPIKey) {
            guard environment.apiKeyStore.hasAPIKey else { return }
            await importSharedLinks()
            await subscriptionsStore.load()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                guard environment.apiKeyStore.hasAPIKey else { return }
                await importSharedLinks()
                await refreshSelectedTab()
                await subscriptionsStore.load()
            }
        }
    }

    private func refreshSelectedTab() async {
        guard environment.apiKeyStore.hasAPIKey else { return }

        switch selectedTab {
        case .inbox:
            await inboxStore.load()
        case .feeds:
            await subscriptionsStore.load()
        case .archive:
            await archiveStore.load()
        case .trash:
            await trashStore.load()
        case .settings:
            break
        }
    }

    /// Delivers URLs queued by the Action extension, then refreshes Inbox so a
    /// successful share is visible as soon as the app becomes active.
    private func importSharedLinks() async {
        let pendingLinks: [PendingSharedLink]

        do {
            pendingLinks = try SharedLinkInbox.takeAll()
        } catch {
            print("Failed to read shared links: \(error.localizedDescription)")
            return
        }

        guard !pendingLinks.isEmpty else { return }

        var failedLinks: [PendingSharedLink] = []

        for pendingLink in pendingLinks {
            do {
                try await environment.linksRepository.createLink(url: pendingLink.url)
            } catch {
                print("Failed to import shared link: \(error.localizedDescription)")
                failedLinks.append(pendingLink)
            }
        }

        if !failedLinks.isEmpty {
            do {
                try SharedLinkInbox.requeue(failedLinks)
            } catch {
                print("Failed to preserve undelivered shared links: \(error.localizedDescription)")
            }
        }

        guard failedLinks.count < pendingLinks.count else { return }
        selectedTab = .inbox
        await inboxStore.load()
    }
}

#Preview {
    RootView(
        environment: AppEnv(
            linksRepository: PreviewLinksRepository(),
            apiKeyStore: .preview(apiKey: "preview-api-key")
        )
    )
    .tint(AppTheme.accent)
}

struct PreviewLinksRepository: LinksRepository {
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

    func createLink(url: URL) async throws {
        // No-op for previews.
    }
    
    func deleteLink(id: Link.ID) async throws {
        // No-op for previews.
    }
    
    func archiveLink(id: Link.ID) async throws {
        // No-op for previews.
    }

    func cachedSubscriptions() async -> [Subscription] { [] }

    func refreshSubscriptions() async throws -> [Subscription] { [] }

    func subscribe(to feedURL: URL, initialSync: Bool) async throws -> Subscription {
        Subscription(id: "preview-subscription", feedUrl: feedURL)
    }

    func fetchLinks(for subscriptionID: Subscription.ID, filter: FeedEntriesFilter) async throws -> [Link] {
        previewLinks().filter { $0.subscriptionId == subscriptionID }
    }

    func unsubscribe(id: Subscription.ID, disposition: UnsubscribeDisposition) async throws {
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
