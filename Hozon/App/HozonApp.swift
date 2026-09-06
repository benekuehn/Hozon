import SwiftUI

@main
struct HozonApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                RootView(environment: .live)
            }
            .background(AppTheme.background)
            .tint(AppTheme.accent)
        }
    }
}
