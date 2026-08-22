import Foundation

struct AppEnv {
    let linksRepository: any LinksRepository
    let apiKeyStore: ShioriAPIKeyStore

    static let live: AppEnv = {
        let apiKeyStore = ShioriAPIKeyStore()
        return AppEnv(
            linksRepository: ShioriLinksRepository(
                apiClient: ShioriAPIClient(
                    baseURL: URL(string: "https://www.shiori.sh")!,
                    apiKeyStore: apiKeyStore
                )
            ),
            apiKeyStore: apiKeyStore
        )
    }()
}
