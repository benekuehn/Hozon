import SwiftUI

enum LinkOpeningPreference: String, CaseIterable, Identifiable, Sendable {
    case alwaysReader
    case alwaysWebView
    case readerInDarkMode

    static let defaultValue = LinkOpeningPreference.readerInDarkMode
    static let storageKey = "linkOpeningPreference"

    var id: Self { self }

    var title: String {
        switch self {
        case .alwaysReader:
            "Always Reader"
        case .alwaysWebView:
            "Always Web View"
        case .readerInDarkMode:
            "Reader in Dark Mode"
        }
    }

    func opensInReader(for colorScheme: ColorScheme) -> Bool {
        switch self {
        case .alwaysReader:
            true
        case .alwaysWebView:
            false
        case .readerInDarkMode:
            colorScheme == .dark
        }
    }
}

@Observable
@MainActor
final class LinkOpeningPreferenceStore {
    var preference: LinkOpeningPreference {
        didSet {
            userDefaults.set(preference.rawValue, forKey: LinkOpeningPreference.storageKey)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        preference = userDefaults.string(forKey: LinkOpeningPreference.storageKey)
            .flatMap(LinkOpeningPreference.init(rawValue:))
            ?? .defaultValue
    }
}
