import SwiftUI
import SwiftData
import UIKit

@main
struct HozonApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        UIWindow.appearance().backgroundColor = AppTheme.uiBackground
        UIScrollView.appearance().backgroundColor = AppTheme.uiBackground
        UITableView.appearance().backgroundColor = AppTheme.uiBackground
        UICollectionView.appearance().backgroundColor = AppTheme.uiBackground
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                RootView()
            }
            .background(AppTheme.background)
        }
        .modelContainer(sharedModelContainer)
    }
}
