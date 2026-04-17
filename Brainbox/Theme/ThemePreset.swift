import SwiftUI

enum ThemePreset: String, CaseIterable, Identifiable {
    case midnightPurple
    case deepOcean
    case roseQuartz
    case emeraldNight
    case sunsetGlow
    case arctic
    case noir
    case cyberpunk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnightPurple: return "Midnight Purple"
        case .deepOcean: return "Deep Ocean"
        case .roseQuartz: return "Rose Quartz"
        case .emeraldNight: return "Emerald Night"
        case .sunsetGlow: return "Sunset Glow"
        case .arctic: return "Arctic"
        case .noir: return "Noir"
        case .cyberpunk: return "Cyberpunk"
        }
    }

    /// Colors shown in the theme preview card
    var previewColors: [Color] {
        let c = colors
        return [c.sidebarBackground, c.backgroundPrimary, c.surfacePrimary, c.accent, c.accentLight]
    }

    // MARK: - Theme Definitions

    var colors: AppThemeColors {
        var base: AppThemeColors
        switch self {
        case .midnightPurple: base = Self.midnightPurpleColors
        case .deepOcean: base = Self.deepOceanColors
        case .roseQuartz: base = Self.roseQuartzColors
        case .emeraldNight: base = Self.emeraldNightColors
        case .sunsetGlow: base = Self.sunsetGlowColors
        case .arctic: base = Self.arcticColors
        case .noir: base = Self.noirColors
        case .cyberpunk: base = Self.cyberpunkColors
        }
        // Stamp the preset name so render caches can detect theme swaps
        // without comparing every individual color field.
        base.identityToken = rawValue
        return base
    }

    // MARK: - Midnight Purple
    // Deep purple-black with magenta accents. Premium and moody.
    private static let midnightPurpleColors = AppThemeColors(
        backgroundPrimary: Color(red: 0.08, green: 0.05, blue: 0.12),
        backgroundSecondary: Color(red: 0.10, green: 0.07, blue: 0.14),
        backgroundTertiary: Color(red: 0.13, green: 0.09, blue: 0.18),
        surfacePrimary: Color(red: 0.14, green: 0.10, blue: 0.20),
        surfaceSecondary: Color(red: 0.17, green: 0.12, blue: 0.23),
        surfaceHover: Color(red: 0.20, green: 0.15, blue: 0.27),
        accent: Color(red: 0.75, green: 0.22, blue: 0.50),
        accentLight: Color(red: 0.85, green: 0.35, blue: 0.60),
        textPrimary: Color(red: 0.93, green: 0.91, blue: 0.95),
        textSecondary: Color(red: 0.60, green: 0.55, blue: 0.65),
        textTertiary: Color(red: 0.42, green: 0.38, blue: 0.48),
        border: Color(red: 0.22, green: 0.17, blue: 0.28),
        borderLight: Color(red: 0.18, green: 0.14, blue: 0.24),
        sidebarBackground: Color(red: 0.07, green: 0.04, blue: 0.10),
        sidebarSelected: Color(red: 0.20, green: 0.14, blue: 0.28),
        sidebarHover: Color(red: 0.12, green: 0.08, blue: 0.16),
        error: Color(red: 0.90, green: 0.30, blue: 0.30),
        warning: Color(red: 0.95, green: 0.75, blue: 0.30)
    )

    // MARK: - Deep Ocean
    // Navy depths with teal/cyan accents. Calming and professional.
    private static let deepOceanColors = AppThemeColors(
        backgroundPrimary: Color(red: 0.04, green: 0.07, blue: 0.13),
        backgroundSecondary: Color(red: 0.06, green: 0.09, blue: 0.16),
        backgroundTertiary: Color(red: 0.08, green: 0.12, blue: 0.20),
        surfacePrimary: Color(red: 0.08, green: 0.13, blue: 0.22),
        surfaceSecondary: Color(red: 0.10, green: 0.16, blue: 0.26),
        surfaceHover: Color(red: 0.12, green: 0.19, blue: 0.30),
        accent: Color(red: 0.13, green: 0.70, blue: 0.77),
        accentLight: Color(red: 0.25, green: 0.82, blue: 0.88),
        textPrimary: Color(red: 0.88, green: 0.93, blue: 0.96),
        textSecondary: Color(red: 0.50, green: 0.60, blue: 0.68),
        textTertiary: Color(red: 0.35, green: 0.43, blue: 0.50),
        border: Color(red: 0.12, green: 0.18, blue: 0.28),
        borderLight: Color(red: 0.10, green: 0.15, blue: 0.24),
        sidebarBackground: Color(red: 0.03, green: 0.05, blue: 0.10),
        sidebarSelected: Color(red: 0.12, green: 0.20, blue: 0.32),
        sidebarHover: Color(red: 0.06, green: 0.10, blue: 0.18),
        error: Color(red: 0.90, green: 0.35, blue: 0.35),
        warning: Color(red: 0.95, green: 0.75, blue: 0.30)
    )

    // MARK: - Rose Quartz
    // Dark with warm rose/blush accents. Elegant and sophisticated.
    private static let roseQuartzColors = AppThemeColors(
        backgroundPrimary: Color(red: 0.09, green: 0.05, blue: 0.07),
        backgroundSecondary: Color(red: 0.12, green: 0.07, blue: 0.09),
        backgroundTertiary: Color(red: 0.15, green: 0.09, blue: 0.12),
        surfacePrimary: Color(red: 0.16, green: 0.10, blue: 0.13),
        surfaceSecondary: Color(red: 0.20, green: 0.13, blue: 0.16),
        surfaceHover: Color(red: 0.24, green: 0.16, blue: 0.20),
        accent: Color(red: 0.91, green: 0.36, blue: 0.46),
        accentLight: Color(red: 0.96, green: 0.52, blue: 0.60),
        textPrimary: Color(red: 0.95, green: 0.91, blue: 0.92),
        textSecondary: Color(red: 0.62, green: 0.52, blue: 0.56),
        textTertiary: Color(red: 0.45, green: 0.37, blue: 0.40),
        border: Color(red: 0.24, green: 0.16, blue: 0.19),
        borderLight: Color(red: 0.20, green: 0.13, blue: 0.16),
        sidebarBackground: Color(red: 0.07, green: 0.04, blue: 0.05),
        sidebarSelected: Color(red: 0.24, green: 0.13, blue: 0.18),
        sidebarHover: Color(red: 0.13, green: 0.07, blue: 0.10),
        error: Color(red: 0.90, green: 0.30, blue: 0.30),
        warning: Color(red: 0.95, green: 0.75, blue: 0.30)
    )

    // MARK: - Emerald Night
    // Dark forest with emerald green accents. Natural and refreshing.
    private static let emeraldNightColors = AppThemeColors(
        backgroundPrimary: Color(red: 0.04, green: 0.08, blue: 0.06),
        backgroundSecondary: Color(red: 0.06, green: 0.10, blue: 0.08),
        backgroundTertiary: Color(red: 0.08, green: 0.14, blue: 0.10),
        surfacePrimary: Color(red: 0.08, green: 0.15, blue: 0.11),
        surfaceSecondary: Color(red: 0.10, green: 0.18, blue: 0.14),
        surfaceHover: Color(red: 0.13, green: 0.22, blue: 0.17),
        accent: Color(red: 0.20, green: 0.78, blue: 0.43),
        accentLight: Color(red: 0.35, green: 0.88, blue: 0.55),
        textPrimary: Color(red: 0.90, green: 0.95, blue: 0.92),
        textSecondary: Color(red: 0.50, green: 0.62, blue: 0.55),
        textTertiary: Color(red: 0.35, green: 0.45, blue: 0.40),
        border: Color(red: 0.12, green: 0.20, blue: 0.16),
        borderLight: Color(red: 0.10, green: 0.17, blue: 0.13),
        sidebarBackground: Color(red: 0.03, green: 0.06, blue: 0.04),
        sidebarSelected: Color(red: 0.12, green: 0.24, blue: 0.16),
        sidebarHover: Color(red: 0.06, green: 0.12, blue: 0.08),
        error: Color(red: 0.90, green: 0.35, blue: 0.35),
        warning: Color(red: 0.95, green: 0.78, blue: 0.30)
    )

    // MARK: - Sunset Glow
    // Dark warm tones with amber/orange accents. Warm and inviting.
    private static let sunsetGlowColors = AppThemeColors(
        backgroundPrimary: Color(red: 0.09, green: 0.07, blue: 0.04),
        backgroundSecondary: Color(red: 0.12, green: 0.09, blue: 0.05),
        backgroundTertiary: Color(red: 0.15, green: 0.12, blue: 0.07),
        surfacePrimary: Color(red: 0.16, green: 0.13, blue: 0.08),
        surfaceSecondary: Color(red: 0.20, green: 0.16, blue: 0.10),
        surfaceHover: Color(red: 0.24, green: 0.20, blue: 0.13),
        accent: Color(red: 0.94, green: 0.63, blue: 0.19),
        accentLight: Color(red: 0.98, green: 0.75, blue: 0.35),
        textPrimary: Color(red: 0.96, green: 0.93, blue: 0.88),
        textSecondary: Color(red: 0.62, green: 0.56, blue: 0.46),
        textTertiary: Color(red: 0.45, green: 0.40, blue: 0.33),
        border: Color(red: 0.24, green: 0.20, blue: 0.13),
        borderLight: Color(red: 0.20, green: 0.17, blue: 0.10),
        sidebarBackground: Color(red: 0.07, green: 0.05, blue: 0.03),
        sidebarSelected: Color(red: 0.24, green: 0.20, blue: 0.10),
        sidebarHover: Color(red: 0.13, green: 0.10, blue: 0.06),
        error: Color(red: 0.90, green: 0.35, blue: 0.30),
        warning: Color(red: 0.95, green: 0.80, blue: 0.30)
    )

    // MARK: - Arctic
    // Cool gray-blue with ice blue accents. Clean and modern.
    private static let arcticColors = AppThemeColors(
        backgroundPrimary: Color(red: 0.07, green: 0.08, blue: 0.10),
        backgroundSecondary: Color(red: 0.09, green: 0.10, blue: 0.13),
        backgroundTertiary: Color(red: 0.12, green: 0.13, blue: 0.16),
        surfacePrimary: Color(red: 0.13, green: 0.14, blue: 0.18),
        surfaceSecondary: Color(red: 0.16, green: 0.17, blue: 0.22),
        surfaceHover: Color(red: 0.19, green: 0.20, blue: 0.26),
        accent: Color(red: 0.35, green: 0.65, blue: 0.94),
        accentLight: Color(red: 0.50, green: 0.75, blue: 0.98),
        textPrimary: Color(red: 0.91, green: 0.93, blue: 0.95),
        textSecondary: Color(red: 0.55, green: 0.58, blue: 0.65),
        textTertiary: Color(red: 0.38, green: 0.40, blue: 0.48),
        border: Color(red: 0.18, green: 0.20, blue: 0.26),
        borderLight: Color(red: 0.15, green: 0.17, blue: 0.22),
        sidebarBackground: Color(red: 0.06, green: 0.07, blue: 0.08),
        sidebarSelected: Color(red: 0.18, green: 0.22, blue: 0.30),
        sidebarHover: Color(red: 0.10, green: 0.11, blue: 0.15),
        error: Color(red: 0.90, green: 0.35, blue: 0.35),
        warning: Color(red: 0.95, green: 0.78, blue: 0.30)
    )

    // MARK: - Noir
    // Pure monochrome black. Minimalist and focused.
    private static let noirColors = AppThemeColors(
        backgroundPrimary: Color(red: 0.05, green: 0.05, blue: 0.05),
        backgroundSecondary: Color(red: 0.08, green: 0.08, blue: 0.08),
        backgroundTertiary: Color(red: 0.11, green: 0.11, blue: 0.11),
        surfacePrimary: Color(red: 0.12, green: 0.12, blue: 0.12),
        surfaceSecondary: Color(red: 0.16, green: 0.16, blue: 0.16),
        surfaceHover: Color(red: 0.20, green: 0.20, blue: 0.20),
        accent: Color(red: 0.85, green: 0.85, blue: 0.85),
        accentLight: Color(red: 0.95, green: 0.95, blue: 0.95),
        textPrimary: Color(red: 0.92, green: 0.92, blue: 0.92),
        textSecondary: Color(red: 0.55, green: 0.55, blue: 0.55),
        textTertiary: Color(red: 0.38, green: 0.38, blue: 0.38),
        border: Color(red: 0.18, green: 0.18, blue: 0.18),
        borderLight: Color(red: 0.14, green: 0.14, blue: 0.14),
        sidebarBackground: Color(red: 0.04, green: 0.04, blue: 0.04),
        sidebarSelected: Color(red: 0.20, green: 0.20, blue: 0.20),
        sidebarHover: Color(red: 0.09, green: 0.09, blue: 0.09),
        error: Color(red: 0.90, green: 0.30, blue: 0.30),
        warning: Color(red: 0.95, green: 0.75, blue: 0.30)
    )

    // MARK: - Cyberpunk
    // Electric neon on dark. Bold and futuristic.
    private static let cyberpunkColors = AppThemeColors(
        backgroundPrimary: Color(red: 0.04, green: 0.04, blue: 0.09),
        backgroundSecondary: Color(red: 0.06, green: 0.06, blue: 0.12),
        backgroundTertiary: Color(red: 0.08, green: 0.08, blue: 0.16),
        surfacePrimary: Color(red: 0.08, green: 0.08, blue: 0.18),
        surfaceSecondary: Color(red: 0.10, green: 0.10, blue: 0.22),
        surfaceHover: Color(red: 0.13, green: 0.13, blue: 0.28),
        accent: Color(red: 0.00, green: 1.00, blue: 0.53),
        accentLight: Color(red: 0.30, green: 1.00, blue: 0.70),
        textPrimary: Color(red: 0.90, green: 0.94, blue: 1.00),
        textSecondary: Color(red: 0.50, green: 0.54, blue: 0.68),
        textTertiary: Color(red: 0.35, green: 0.38, blue: 0.50),
        border: Color(red: 0.12, green: 0.12, blue: 0.26),
        borderLight: Color(red: 0.10, green: 0.10, blue: 0.22),
        sidebarBackground: Color(red: 0.03, green: 0.03, blue: 0.07),
        sidebarSelected: Color(red: 0.12, green: 0.12, blue: 0.28),
        sidebarHover: Color(red: 0.06, green: 0.06, blue: 0.14),
        error: Color(red: 1.00, green: 0.25, blue: 0.40),
        warning: Color(red: 1.00, green: 0.85, blue: 0.00)
    )
}
