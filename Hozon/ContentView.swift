import SwiftUI

struct ContentView: View {
    private let environment: AppEnv

    init(environment: AppEnv = .live) {
        self.environment = environment
    }

    var body: some View {
        RootView(environment: environment)
    }
}

#Preview {
    ContentView(
        environment: AppEnv(
            linksRepository: PreviewLinksRepository(),
            apiKeyStore: .preview(apiKey: "preview-api-key")
        )
    )
    .tint(AppTheme.accent)
}
