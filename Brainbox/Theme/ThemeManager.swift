import SwiftUI

@Observable
class ThemeManager {
    var selectedPreset: ThemePreset {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: UDKey.selectedTheme)
        }
    }

    var useGlassEffect: Bool { true }

    var colors: AppThemeColors {
        selectedPreset.colors
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: UDKey.selectedTheme),
           let preset = ThemePreset(rawValue: saved) {
            self.selectedPreset = preset
        } else {
            self.selectedPreset = .midnightPurple
        }
    }
}
