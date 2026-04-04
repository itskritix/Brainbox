import SwiftUI
import AppKit

/// Renders markdown in an NSTextView for native macOS text selection.
/// Replaces MarkdownUI's Markdown view which creates separate selection
/// islands per block, making multi-line selection impossible.
struct SelectableMarkdownView: NSViewRepresentable {
    let markdown: String
    let theme: AppThemeColors

    func makeNSView(context: Context) -> NSTextView {
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        // Force TextKit 1 — required for NSTextBlock (code block backgrounds)
        _ = tv.layoutManager
        return tv
    }

    func updateNSView(_ tv: NSTextView, context: Context) {
        tv.linkTextAttributes = [
            .foregroundColor: NSColor(theme.accent),
            .cursor: NSCursor.pointingHand,
        ]
        let rendered = MarkdownRenderer.render(markdown, theme: theme)
        tv.textStorage?.setAttributedString(rendered)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView tv: NSTextView,
        context: Context
    ) -> CGSize? {
        let w = proposal.width ?? 500
        guard w > 0 else { return CGSize(width: 0, height: 0) }
        tv.textContainer?.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude)
        tv.layoutManager?.ensureLayout(for: tv.textContainer!)
        let used = tv.layoutManager?.usedRect(for: tv.textContainer!) ?? .zero
        return CGSize(width: w, height: ceil(used.height + 1))
    }
}

// MARK: - Renderer

enum MarkdownRenderer {

    static func render(_ markdown: String, theme: AppThemeColors) -> NSAttributedString {
        guard !markdown.isEmpty else { return NSAttributedString() }
        do {
            let parsed = try AttributedString(
                markdown: markdown,
                options: .init(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
            return styled(from: parsed, theme: theme)
        } catch {
            return NSAttributedString(
                string: markdown,
                attributes: baseAttrs(theme)
            )
        }
    }

    // MARK: Defaults

    private static func baseAttrs(_ theme: AppThemeColors) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 3
        p.paragraphSpacing = 8
        return [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor(theme.textPrimary),
            .paragraphStyle: p,
        ]
    }

    // MARK: Build

    private static func styled(
        from source: AttributedString,
        theme: AppThemeColors
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var lastItemID: Int?

        for run in source.runs {
            let sub = source[run.range]
            let text = String(sub.characters)
            var a = baseAttrs(theme)

            let intent = sub.presentationIntent
            let inline = sub.inlinePresentationIntent

            // -- Block styles --
            var isCode = false
            var listDepth = 0
            var ordinal: Int?
            var ordered = false

            if let intent {
                for c in intent.components {
                    switch c.kind {
                    case .header(let lvl):    heading(lvl, &a, theme)
                    case .codeBlock:          isCode = true; codeBlock(&a, theme)
                    case .blockQuote:         blockQuote(&a, theme)
                    case .orderedList:        ordered = true; listDepth += 1
                    case .unorderedList:      listDepth += 1
                    case .listItem(let o):    ordinal = o
                    default: break
                    }
                }

                if listDepth > 0, let ordinal {
                    listStyle(listDepth, &a)
                    let comp = intent.components.first {
                        if case .listItem = $0.kind { return true }; return false
                    }
                    if let comp, comp.identity != lastItemID {
                        lastItemID = comp.identity
                        let marker = ordered ? "\(ordinal). " : "\u{2022} "
                        result.append(NSAttributedString(string: marker, attributes: a))
                    }
                }
            }

            // -- Inline styles --
            if !isCode, let inline {
                var font = (a[.font] as? NSFont) ?? .systemFont(ofSize: 14)
                if inline.contains(.stronglyEmphasized) {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
                if inline.contains(.emphasized) {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                if inline.contains(.code) {
                    font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
                    a[.foregroundColor] = NSColor(theme.accent)
                    a[.backgroundColor] = NSColor(theme.backgroundTertiary)
                }
                if inline.contains(.strikethrough) {
                    a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
                a[.font] = font
            }

            // -- Links --
            if let link = sub.link {
                a[.link] = link
                a[.foregroundColor] = NSColor(theme.accent)
            }

            result.append(NSAttributedString(string: text, attributes: a))
        }

        // Trim trailing newlines
        while result.length > 0, result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        return result
    }

    // MARK: Block helpers

    private static func heading(_ level: Int, _ a: inout [NSAttributedString.Key: Any], _ theme: AppThemeColors) {
        let sizes: [Int: CGFloat] = [1: 22, 2: 18, 3: 16, 4: 15, 5: 14, 6: 13]
        let w: NSFont.Weight = level <= 2 ? .bold : .semibold
        a[.font] = NSFont.systemFont(ofSize: sizes[level] ?? 14, weight: w)
        let p = NSMutableParagraphStyle()
        p.paragraphSpacingBefore = level == 1 ? 16 : (level == 2 ? 14 : 12)
        p.paragraphSpacing = level == 1 ? 8 : 6
        p.lineSpacing = 2
        a[.paragraphStyle] = p
    }

    private static func codeBlock(_ a: inout [NSAttributedString.Key: Any], _ theme: AppThemeColors) {
        a[.font] = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        let block = NSTextBlock()
        block.backgroundColor = NSColor(theme.backgroundTertiary)
        block.setContentWidth(100, type: .percentageValueType)
        for edge: NSRectEdge in [.minX, .maxX, .minY, .maxY] {
            block.setWidth(10, type: .absoluteValueType, for: .padding, edge: edge)
        }
        block.setWidth(6, type: .absoluteValueType, for: .margin, edge: .minY)
        block.setWidth(6, type: .absoluteValueType, for: .margin, edge: .maxY)
        let p = NSMutableParagraphStyle()
        p.textBlocks = [block]
        p.lineSpacing = 2
        a[.paragraphStyle] = p
    }

    private static func blockQuote(_ a: inout [NSAttributedString.Key: Any], _ theme: AppThemeColors) {
        a[.foregroundColor] = NSColor(theme.textSecondary)
        let block = NSTextBlock()
        block.backgroundColor = NSColor(theme.backgroundTertiary).withAlphaComponent(0.3)
        block.setContentWidth(100, type: .percentageValueType)
        block.setWidth(14, type: .absoluteValueType, for: .padding, edge: .minX)
        block.setWidth(8, type: .absoluteValueType, for: .padding, edge: .minY)
        block.setWidth(8, type: .absoluteValueType, for: .padding, edge: .maxY)
        block.setBorderColor(NSColor(theme.accent).withAlphaComponent(0.5), for: .minX)
        block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        block.setWidth(6, type: .absoluteValueType, for: .margin, edge: .minY)
        block.setWidth(6, type: .absoluteValueType, for: .margin, edge: .maxY)
        let p = NSMutableParagraphStyle()
        p.textBlocks = [block]
        p.lineSpacing = 3
        a[.paragraphStyle] = p
    }

    private static func listStyle(_ depth: Int, _ a: inout [NSAttributedString.Key: Any]) {
        let p = NSMutableParagraphStyle()
        let indent = CGFloat(depth) * 20
        p.headIndent = indent
        p.firstLineHeadIndent = indent - 16
        p.lineSpacing = 2
        p.paragraphSpacing = 3
        p.paragraphSpacingBefore = 1
        a[.paragraphStyle] = p
    }
}
