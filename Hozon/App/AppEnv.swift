import Foundation

struct AppEnv {
    let linksRepository: any LinksRepository

    static let live = AppEnv(
        linksRepository: ShioriLinksRepository(
            apiClient: ShioriAPIClient(
                baseURL: URL(string: "https://www.shiori.sh")!,
                apiKey: Secrets.shioriAPIKey
            )
        )
    )
}
