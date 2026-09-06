import Foundation

@MainActor
struct AppEnv {
    let linksRepository: any LinksRepository
    let apiKeyStore: ShioriAPIKeyStore

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
            apiKeyStore: apiKeyStore
        )
    }()
}
