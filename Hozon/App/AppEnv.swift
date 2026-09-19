import Foundation

@MainActor
struct AppEnv {
    let linksRepository: any LinksRepository
    let apiKeyStore: ShioriAPIKeyStore
    let linkOpeningPreferenceStore: LinkOpeningPreferenceStore

    init(
        linksRepository: any LinksRepository,
        apiKeyStore: ShioriAPIKeyStore,
        linkOpeningPreferenceStore: LinkOpeningPreferenceStore
    ) {
        self.linksRepository = linksRepository
        self.apiKeyStore = apiKeyStore
        self.linkOpeningPreferenceStore = linkOpeningPreferenceStore
    }

    static let live: AppEnv = {
        let apiKeyStore = ShioriAPIKeyStore()
        guard let baseURL = URL(string: "https://www.shiori.sh") else {
            preconditionFailure("The Shiori base URL must be valid.")
        }

        return AppEnv(
            linksRepository: ShioriLinksRepository(
                apiClient: ShioriAPIClient(
                    baseURL: baseURL,
                    apiKeyStore: apiKeyStore
                )
            ),
            apiKeyStore: apiKeyStore,
            linkOpeningPreferenceStore: LinkOpeningPreferenceStore()
        )
    }()
}
