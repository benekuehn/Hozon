import SwiftUI
import UIKit

enum AppTheme {
    static let uiBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? darkBackground : lightBackground
    }

    static let background = Color(uiColor: uiBackground)
    static let listCardBackground = Color(uiColor: uiElevation)
    static let rowBackground = Color(uiColor: uiElevation)
    static let rowIconBackground = Color(uiColor: uiRowIconBackground)
    static let accent = Color(uiColor: uiAccent)

    private static let uiAccent = UIColor(red: 0 / 255, green: 51 / 255, blue: 204 / 255, alpha: 1)

    private static let uiElevation = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0 / 255, green: 19 / 255, blue: 77 / 255, alpha: 1)
            : UIColor(red: 250 / 255, green: 251 / 255, blue: 249 / 255, alpha: 1)
    }

    private static let uiRowIconBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.05)
    }

    private static let lightBackground = UIColor(red: 250 / 255, green: 248 / 255, blue: 245 / 255, alpha: 1)

    private static let darkBackground = UIColor(
        red: 0 / 255,
        green: 13 / 255,
        blue: 51 / 255,
        alpha: 1
    )
}
