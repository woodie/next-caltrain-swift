import SwiftUI

// Helper to define a color that adapts to light/dark mode
private extension Color {
    init(light: Color, dark: Color) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Colors (named after legacy CSS variables)
extension Color {
    static let calPast = Color(                           // BLUE
        light: Color(red: 0.0, green: 0.0, blue: 1.0),  // #00F
        dark: Color(red: 0.20, green: 0.55, blue: 1.0)   // #338CFF
    )
    static let calArrive = Color(                         // GREEN
        light: Color(red: 0.0, green: 0.62, blue: 0.4),  // #009e0b
        dark: Color(red: 0.0, green: 1.0, blue: 0.0)   // #0F0
    )
    static let calDepart = Color(                         // YELLOW
        light: Color(red: 0.80, green: 0.62, blue: 0.07), // mustard
        dark: Color(red: 1.0, green: 1.0, blue: 0.0)   // #FF0
    )
    static let calSwapped = Color(
        light: Color(white: 0.55),
        dark: Color(white: 0.4)
    )
    static let iconCircleBackground = Color(
        light: Color(white: 0.88),
        dark: Color(white: 0.15)
    )

    // Background and primary text — straight inversions
    static let appBackground = Color(
        light: Color.white,
        dark: Color.black
    )
    static let appText = Color(
        light: Color.black,
        dark: Color.white
    )
}

enum AppStyle {
    // Home, List, Detail screens
    static let fontTrain: CGFloat = 18
    static let fontOrigin: CGFloat = 22
    static let fontBlurb: CGFloat  = 28

    // Toolbar icon buttons (back, swap, reset)
    static let fontStatusBar: CGFloat   = 18
    static let iconButtonSize: CGFloat  = 44
}
