import SwiftUI
import Textual

/// Renders markdown using Textual's StructuredText with Brainbox theming.
/// Replaces the previous custom NSTextView + ThemedMarkdownRenderer approach.
/// Preserves the same public API so call sites remain unchanged.
struct MarkdownContentView: View {
    let markdown: String
    let theme: AppThemeColors

    var body: some View {
        StructuredText(markdown: markdown)
            .textual.structuredTextStyle(BrainboxStyle(theme: theme))
            .textual.highlighterTheme(brainboxHighlighterTheme(theme: theme))
            .textual.textSelection(.enabled)
            .foregroundStyle(theme.textPrimary)
    }
}
