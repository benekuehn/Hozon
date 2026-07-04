import SwiftUI
import UIKit

enum AppTheme {
    static let uiBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? darkBackground : lightBackground
    }

    static let background = Color(uiColor: uiBackground)

    private static let lightBackground = UIColor(
        red: 0.9291315861,
        green: 0.8887484743,
        blue: 0.8477838931,
        alpha: 1
    )

    private static let darkBackground = UIColor(
        red: 0.1453835916,
        green: 0.1166666397,
        blue: 0.0866956741,
        alpha: 1
    )
}
