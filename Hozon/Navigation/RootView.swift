import SwiftData
import SwiftUI

private enum AppTab: Hashable {
    case search
    case inbox
    case archive
    case trash
}

struct RootView: View {
    @State private var selectedTab: AppTab = .inbox

    private let environment = AppEnv.live

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .search, role: .search) {
                Text("Search")
            }

            Tab("Inbox", systemImage: "tray", value: .inbox) {
                InboxView(
                    store: LinksStore(repository: environment.linksRepository)
                )
            }

            Tab("Archive", systemImage: "archivebox", value: .archive) {
                Text("Archive")
            }

            Tab("Trash", systemImage: "trash", value: .trash) {
                Text("Trash")
            }
            .tabPlacement(.sidebarOnly)
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(.sidebar)
    }
}
