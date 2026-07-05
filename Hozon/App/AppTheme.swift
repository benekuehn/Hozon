import SwiftUI
import UIKit

enum AppTheme {
    static let uiBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? darkBackground : lightBackground
    }

    static let background = Color(uiColor: uiBackground)
    static let listCardBackground = Color(uiColor: uiListCardBackground)
    static let rowBackground = Color(uiColor: uiRowBackground)
    static let rowIconBackground = Color(uiColor: uiRowIconBackground)
    static let accent = Color(red: 1, green: 100 / 255, blue: 0)

    private static let uiListCardBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.24, green: 0.2, blue: 0.16, alpha: 1)
            : .white
    }

    private static let uiRowBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.18, blue: 0.14, alpha: 1)
            : .white
    }

    private static let uiRowIconBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.05)
    }

    private static let lightBackground = UIColor(red: 254 / 255, green: 250 / 255, blue: 244 / 255, alpha: 1)

    private static let darkBackground = UIColor(
        red: 0.1453835916,
        green: 0.1166666397,
        blue: 0.0866956741,
        alpha: 1
    )
}
