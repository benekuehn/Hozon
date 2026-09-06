import SwiftUI
import OSLog

private enum AppTab: Hashable {
    case inbox
    case feeds
    case archive
    case trash
    case settings
}

@MainActor
struct RootView: View {
    private static let logger = Logger(subsystem: "com.benekuehn.Hozon", category: "SharedLinks")
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .inbox
    @State private var inboxStore: LinksStore
    @State private var archiveStore: LinksStore
    @State private var trashStore: LinksStore
    @State private var subscriptionsStore: SubscriptionsStore

    private let environment: AppEnv

    init(environment: AppEnv) {
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
            Self.logger.error("Failed to read shared links. error=\(error.localizedDescription, privacy: .private(mask: .hash))")
            return
        }

        guard !pendingLinks.isEmpty else { return }

        var failedLinks: [PendingSharedLink] = []

        for pendingLink in pendingLinks {
            do {
                try await environment.linksRepository.createLink(url: pendingLink.url)
            } catch {
                Self.logger.error("Failed to import a shared link. error=\(error.localizedDescription, privacy: .private(mask: .hash))")
                failedLinks.append(pendingLink)
            }
        }

        if !failedLinks.isEmpty {
            do {
                try SharedLinkInbox.requeue(failedLinks)
            } catch {
                Self.logger.error("Failed to preserve undelivered shared links. error=\(error.localizedDescription, privacy: .private(mask: .hash))")
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
