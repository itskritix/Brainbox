import AppKit

// MARK: - Clipboard

func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

// MARK: - SF Symbol Helpers

func outlineVariant(of symbol: String) -> String {
    if symbol.hasSuffix(".fill") {
        return String(symbol.dropLast(5))
    }
    return symbol
}

// MARK: - UserDefaults Keys

enum UDKey {
    static let userName = "userName"
    static let selectedModelId = "selectedModelId"
    static let activeProfileId = "activeProfileId"
    static let selectedTheme = "selectedTheme"
    static let useGlassEffect = "useGlassEffect"
}
