import SwiftUI

struct AppThemeColors {
    // Backgrounds
    let backgroundPrimary: Color
    let backgroundSecondary: Color
    let backgroundTertiary: Color

    // Surfaces (cards, inputs, elevated elements)
    let surfacePrimary: Color
    let surfaceSecondary: Color
    let surfaceHover: Color

    // Accent
    let accent: Color
    let accentLight: Color

    // Text
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // Borders
    let border: Color
    let borderLight: Color

    // Sidebar
    let sidebarBackground: Color
    let sidebarSelected: Color
    let sidebarHover: Color

    // Semantic
    let error: Color
    let warning: Color

    /// Stable identity string used by cache layers (e.g. `SelectableMarkdownView`)
    /// to detect that the active theme changed without having to compare every
    /// individual color. Set by `ThemeManager` when it constructs the palette.
    var identityToken: String = ""
}
