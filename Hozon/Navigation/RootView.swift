import SwiftUI

private enum AppTab: Hashable {
    case search
    case inbox
    case archive
    case trash
}

struct RootView: View {
    @State private var selectedTab: AppTab = .inbox
    @State private var inboxStore: LinksStore
    @State private var archiveStore: LinksStore
    @State private var trashStore: LinksStore

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
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .search, role: .search) {
                Text("Search")
            }

            Tab("Inbox", systemImage: "tray", value: .inbox) {
                LinksView(
                    title: "Inbox",
                    store: inboxStore,
                    showsArchiveAction: true,
                    showsDeleteAction: true
                )
            }

            Tab("Archive", systemImage: "archivebox", value: .archive) {
                LinksView(
                    title: "Archive",
                    store: archiveStore,
                    showsArchiveAction: false,
                    showsDeleteAction: true
                )
            }

            Tab("Trash", systemImage: "trash", value: .trash) {
                LinksView(
                    title: "Trash",
                    store: trashStore,
                    showsArchiveAction: false,
                    showsDeleteAction: false
                )
            }
            .tabPlacement(.sidebarOnly)
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(.sidebar)
        .task(id: selectedTab) {
            switch selectedTab {
            case .search:
                break
            case .inbox:
                if inboxStore.links.isEmpty {
                    await inboxStore.load()
                }
            case .archive:
                if archiveStore.links.isEmpty {
                    await archiveStore.load()
                }
            case .trash:
                if trashStore.links.isEmpty {
                    await trashStore.load()
                }
            }
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
    func cachedInboxLinks() async -> [Link] {
        previewLinks()
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
                domain: "example.com"
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

    private func previewLink(id: String, title: String, domain: String) -> Link {
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
            discoverableFeedUrl: nil
        )
    }
}
