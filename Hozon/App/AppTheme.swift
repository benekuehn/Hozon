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

    private static let uiAccent = UIColor(red: 140 / 255, green: 163 / 255, blue: 117 / 255, alpha: 1)

    private static let uiElevation = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 23 / 255, green: 28 / 255, blue: 18 / 255, alpha: 1)
            : UIColor(red: 250 / 255, green: 251 / 255, blue: 249 / 255, alpha: 1)
    }

    private static let uiRowIconBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.05)
    }

    private static let lightBackground = UIColor(red: 242 / 255, green: 245 / 255, blue: 240 / 255, alpha: 1)

    private static let darkBackground = UIColor(
        red: 13 / 255,
        green: 15 / 255,
        blue: 10 / 255,
        alpha: 1
    )
}
