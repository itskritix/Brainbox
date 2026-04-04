import SwiftUI
import Textual

// MARK: - Brainbox Style (bundles all sub-styles)

struct BrainboxStyle: StructuredText.Style {
    let theme: AppThemeColors

    var inlineStyle: InlineStyle {
        InlineStyle()
            .code(.monospaced, .fontScale(0.88), .foregroundColor(theme.accent), .backgroundColor(theme.backgroundTertiary))
            .strong(.bold)
            .emphasis(.italic)
            .strikethrough(.strikethroughStyle(.single))
            .link(.foregroundColor(theme.accent))
    }

    var headingStyle: BrainboxHeadingStyle { .init(theme: theme) }
    var paragraphStyle: BrainboxParagraphStyle { .init() }
    var blockQuoteStyle: BrainboxBlockQuoteStyle { .init(theme: theme) }
    var codeBlockStyle: BrainboxCodeBlockStyle { .init(theme: theme) }
    var listItemStyle: StructuredText.DefaultListItemStyle { .default }
    var unorderedListMarker: StructuredText.HierarchicalSymbolListMarker { .hierarchical(.disc, .circle, .square) }
    var orderedListMarker: StructuredText.DecimalListMarker { .decimal }
    var tableStyle: StructuredText.DefaultTableStyle { .default }
    var tableCellStyle: StructuredText.DefaultTableCellStyle { .default }
    var thematicBreakStyle: BrainboxThematicBreakStyle { .init(theme: theme) }
}

// MARK: - Heading

struct BrainboxHeadingStyle: StructuredText.HeadingStyle {
    let theme: AppThemeColors

    // Maps heading levels to font scales relative to base (14pt)
    private static let fontScales: [CGFloat] = [
        22.0 / 14.0,  // h1: 1.571
        18.0 / 14.0,  // h2: 1.286
        16.0 / 14.0,  // h3: 1.143
        15.0 / 14.0,  // h4: 1.071
        1.0,           // h5: 1.0
        13.0 / 14.0,  // h6: 0.929
    ]

    func makeBody(configuration: Configuration) -> some View {
        let level = min(configuration.headingLevel, 6)
        let scale = Self.fontScales[level - 1]
        let topSpacing: CGFloat = level == 1 ? 16 : (level == 2 ? 14 : 12)
        let bottomSpacing: CGFloat = level == 1 ? 8 : 4

        configuration.label
            .textual.fontScale(scale)
            .textual.lineSpacing(.fontScaled(2.0 / 14.0))
            .textual.blockSpacing(.init(top: topSpacing, bottom: bottomSpacing))
            .fontWeight(level <= 2 ? .bold : .semibold)
    }
}

// MARK: - Paragraph

struct BrainboxParagraphStyle: StructuredText.ParagraphStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textual.lineSpacing(.fontScaled(3.0 / 14.0))
            .textual.blockSpacing(.fontScaled(top: 0, bottom: 8.0 / 14.0))
    }
}

// MARK: - Code Block (with header bar + copy button)

struct BrainboxCodeBlockStyle: StructuredText.CodeBlockStyle {
    let theme: AppThemeColors

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: language label + copy button
            CodeBlockHeader(
                language: configuration.languageHint,
                codeBlock: configuration.codeBlock,
                theme: theme
            )

            // Code content with horizontal scroll
            Overflow {
                configuration.label
                    .textual.lineSpacing(.fontScaled(2.0 / 14.0))
                    .textual.fontScale(13.0 / 14.0)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospaced()
                    .padding(12)
            }
        }
        .background(theme.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        .textual.blockSpacing(.fontScaled(top: 6.0 / 14.0, bottom: 6.0 / 14.0))
    }
}

private struct CodeBlockHeader: View {
    let language: String?
    let codeBlock: StructuredText.CodeBlockProxy
    let theme: AppThemeColors
    @State private var copied = false

    var body: some View {
        HStack {
            Text(language ?? "code")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            Spacer()
            Button {
                codeBlock.copyToPasteboard()
                withAnimation(.easeOut(duration: 0.15)) { copied = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeOut(duration: 0.15)) { copied = false }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                    Text(copied ? "Copied!" : "Copy")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(copied ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.backgroundTertiary.opacity(0.6))
    }
}

// MARK: - Block Quote

struct BrainboxBlockQuoteStyle: StructuredText.BlockQuoteStyle {
    let theme: AppThemeColors

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.accent.opacity(0.5))
                .frame(width: 3)
            configuration.label
                .foregroundStyle(theme.textSecondary)
                .textual.padding(.horizontal, .fontScaled(0.7))
        }
    }
}

// MARK: - Thematic Break

struct BrainboxThematicBreakStyle: StructuredText.ThematicBreakStyle {
    let theme: AppThemeColors

    func makeBody(configuration: Configuration) -> some View {
        Rectangle()
            .fill(theme.border.opacity(0.4))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .textual.blockSpacing(.init(top: 12, bottom: 12))
    }
}

// MARK: - Highlighter Theme

func brainboxHighlighterTheme(theme: AppThemeColors) -> StructuredText.HighlighterTheme {
    StructuredText.HighlighterTheme(
        foregroundColor: DynamicColor(theme.textPrimary),
        backgroundColor: DynamicColor(theme.backgroundTertiary)
    )
}
