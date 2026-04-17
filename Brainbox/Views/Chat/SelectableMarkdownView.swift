import SwiftUI
import AppKit
import Markdown

// MARK: - Top-level markdown view

/// Splits markdown into prose and code-block segments.
/// Prose renders in NSTextView via Markdownosaur (full native text selection).
/// Code blocks get a SwiftUI view with a copy button.
///
/// Responsiveness model (matches ChatGPT / Claude.ai):
/// - During streaming, we split the content into a *sealed prefix* (all
///   complete blocks, already delimited by a blank line and with any code
///   fences closed) and a *live tail* (the block currently being streamed).
/// - The sealed prefix is parsed with the full markdown AST and only changes
///   when a new block boundary arrives, so the expensive NSTextView
///   `setAttributedString` path runs at most once per block — not once per
///   token.
/// - The live tail renders through a lightweight `Text` view so every token
///   update is O(length-of-current-block) instead of O(entire-message).
/// - When `isStreaming == false` the tail is empty and everything is parsed
///   normally, so the final rendering is identical to the pre-streaming path.
struct MarkdownContentView: View {
    let markdown: String
    let isStreaming: Bool
    let theme: AppThemeColors

    init(markdown: String, theme: AppThemeColors, isStreaming: Bool = false) {
        self.markdown = markdown
        self.isStreaming = isStreaming
        self.theme = theme
    }

    var body: some View {
        let split = Self.splitStableAndTail(markdown: markdown, isStreaming: isStreaming)
        let segs = Self.parse(split.stable)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .text(let md):
                    SelectableMarkdownView(markdown: md, theme: theme)
                case .code(let lang, let code):
                    CodeBlockView(language: lang, content: code, theme: theme)
                case .divider:
                    Rectangle()
                        .fill(theme.border.opacity(0.4))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }

            if !split.tail.isEmpty {
                StreamingTailView(
                    text: split.tail,
                    isInsideCodeFence: split.tailIsInsideCodeFence,
                    hasStablePrefix: !split.stable.isEmpty,
                    theme: theme
                )
            }
        }
    }

    // MARK: Segment parser (AST-based)

    private enum Segment {
        case text(String)
        case code(language: String?, content: String)
        case divider
    }

    /// Parses markdown into segments using the swift-markdown AST.
    /// Code blocks and thematic breaks are extracted as dedicated segments;
    /// all other blocks are grouped into text segments for NSTextView rendering.
    private static func parse(_ markdown: String) -> [Segment] {
        guard !markdown.isEmpty else { return [] }
        let document = Document(parsing: markdown)
        var segments: [Segment] = []
        var textBlocks: [String] = []

        func flushText() {
            let combined = textBlocks.joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty {
                segments.append(.text(combined))
            }
            textBlocks = []
        }

        for child in document.children {
            if let codeBlock = child as? CodeBlock {
                flushText()
                var code = codeBlock.code
                if code.hasSuffix("\n") { code = String(code.dropLast()) }
                let lang = codeBlock.language.flatMap { $0.isEmpty ? nil : $0 }
                segments.append(.code(language: lang, content: code))
            } else if child is ThematicBreak {
                flushText()
                segments.append(.divider)
            } else {
                textBlocks.append(child.format())
            }
        }
        flushText()

        return segments
    }

    // MARK: Stable/tail split

    fileprivate struct StableTailSplit {
        let stable: String
        let tail: String
        let tailIsInsideCodeFence: Bool
    }

    /// Splits `markdown` into a sealed prefix (safe to fully parse) and the
    /// active tail that is still being streamed.
    ///
    /// Rules:
    /// - If not streaming, everything is stable — no tail.
    /// - If an odd number of ``` fences have opened, the active code block is
    ///   unclosed. Everything up to the opening ``` is stable; the open fence
    ///   plus its body is the tail.
    /// - Otherwise the split point is the last blank line (`\n\n`) — content
    ///   before it is stable, content after it is the tail.
    /// - If no block boundary exists yet, everything is tail.
    fileprivate static func splitStableAndTail(
        markdown: String,
        isStreaming: Bool
    ) -> StableTailSplit {
        guard isStreaming, !markdown.isEmpty else {
            return StableTailSplit(stable: markdown, tail: "", tailIsInsideCodeFence: false)
        }

        // Detect unclosed triple-backtick code fence.
        let fenceCount = markdown.components(separatedBy: "```").count - 1
        if fenceCount % 2 == 1, let openRange = markdown.range(of: "```", options: .backwards) {
            let before = String(markdown[..<openRange.lowerBound])
            let tail = String(markdown[openRange.lowerBound...])
            let sealedBefore = sealBeforeBoundary(before)
            return StableTailSplit(
                stable: sealedBefore,
                tail: tail,
                tailIsInsideCodeFence: true
            )
        }

        // Find the last blank-line boundary.
        if let range = markdown.range(of: "\n\n", options: .backwards) {
            let stable = String(markdown[..<range.upperBound])
            let tail = String(markdown[range.upperBound...])
            if tail.isEmpty {
                return StableTailSplit(stable: stable, tail: "", tailIsInsideCodeFence: false)
            }
            return StableTailSplit(
                stable: stable.trimmingCharacters(in: CharacterSet.newlines).isEmpty ? "" : stable,
                tail: tail,
                tailIsInsideCodeFence: false
            )
        }

        // No block boundary yet — entire message is the live tail.
        return StableTailSplit(stable: "", tail: markdown, tailIsInsideCodeFence: false)
    }

    /// Trims trailing whitespace from the stable chunk so the split lines up
    /// cleanly when we re-render on the next token.
    private static func sealBeforeBoundary(_ s: String) -> String {
        var copy = s
        while let last = copy.last, last.isWhitespace {
            copy.removeLast()
        }
        return copy
    }
}

// MARK: - Streaming tail

/// Cheap renderer for the block that is still actively streaming.
/// Uses `Text` (with monospaced font if we're inside an unclosed code fence)
/// so updates cost O(length-of-current-block) rather than re-parsing the
/// whole document every token.
private struct StreamingTailView: View {
    let text: String
    let isInsideCodeFence: Bool
    let hasStablePrefix: Bool
    let theme: AppThemeColors

    var body: some View {
        let content = displayText

        Group {
            if isInsideCodeFence {
                Text(content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                    .padding(.top, hasStablePrefix ? 6 : 0)
            } else {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, hasStablePrefix ? 4 : 0)
            }
        }
        .textSelection(.enabled)
    }

    /// Strips the opening fence line so the streaming code block body renders
    /// as code instead of showing the raw ```lang prefix.
    private var displayText: String {
        guard isInsideCodeFence, text.hasPrefix("```") else { return text }
        if let newlineIndex = text.firstIndex(of: "\n") {
            return String(text[text.index(after: newlineIndex)...])
        }
        return ""
    }
}

// MARK: - Code block with copy button

private struct CodeBlockView: View {
    let language: String?
    let content: String
    let theme: AppThemeColors
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "code")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Button {
                    copyToClipboard(content)
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

            ScrollView(.horizontal, showsIndicators: false) {
                Text(content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
        .background(theme.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        .padding(.vertical, 6)
    }
}

// MARK: - NSTextView for prose (Markdownosaur-powered)

struct SelectableMarkdownView: NSViewRepresentable {
    let markdown: String
    let theme: AppThemeColors

    /// Caches the last rendered `(markdown, themeId)` pair so we don't
    /// re-parse + re-attribute the document when SwiftUI reconciles the
    /// parent view for unrelated reasons (hover, layout pass, etc).
    final class Coordinator {
        var lastMarkdown: String = ""
        var lastThemeId: String = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

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
        _ = tv.layoutManager
        return tv
    }

    func updateNSView(_ tv: NSTextView, context: Context) {
        tv.linkTextAttributes = [
            .foregroundColor: NSColor(theme.accent),
            .cursor: NSCursor.pointingHand,
        ]

        // Fast path: if the markdown AND theme haven't changed, SwiftUI is
        // only re-running us because the parent re-rendered. Skip the expensive
        // parse + attributed-string rebuild — the existing text is still valid.
        let themeId = theme.identityToken
        if context.coordinator.lastMarkdown == markdown,
           context.coordinator.lastThemeId == themeId,
           tv.textStorage?.length ?? 0 > 0 {
            return
        }

        var renderer = ThemedMarkdownRenderer(theme: theme)
        let document = Document(parsing: markdown)
        let attrStr = renderer.attributedString(from: document)
        tv.textStorage?.setAttributedString(attrStr)

        context.coordinator.lastMarkdown = markdown
        context.coordinator.lastThemeId = themeId
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

// MARK: - Themed Markdown Renderer (Markdownosaur adapted for macOS)

struct ThemedMarkdownRenderer: MarkupVisitor {
    let theme: AppThemeColors
    private let baseFontSize: CGFloat = 14.0

    init(theme: AppThemeColors) {
        self.theme = theme
    }

    mutating func attributedString(from document: Document) -> NSAttributedString {
        return visit(document)
    }

    // MARK: Default

    mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    // MARK: Inline

    mutating func visitText(_ text: Markdown.Text) -> NSAttributedString {
        return NSAttributedString(string: text.plainText, attributes: [
            .font: NSFont.systemFont(ofSize: baseFontSize),
            .foregroundColor: NSColor(theme.textPrimary),
        ])
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in emphasis.children { result.append(visit(child)) }
        result.applyTrait(.italicFontMask)
        return result
    }

    mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in strong.children { result.append(visit(child)) }
        result.applyTrait(.boldFontMask)
        return result
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in strikethrough.children { result.append(visit(child)) }
        result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue,
                            range: NSRange(0..<result.length))
        return result
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        return NSAttributedString(string: inlineCode.code, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize * 0.88, weight: .regular),
            .foregroundColor: NSColor(theme.accent),
            .backgroundColor: NSColor(theme.backgroundTertiary),
        ])
    }

    mutating func visitLink(_ link: Markdown.Link) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in link.children { result.append(visit(child)) }
        let r = NSRange(0..<result.length)
        result.addAttribute(.foregroundColor, value: NSColor(theme.accent), range: r)
        if let dest = link.destination, let url = URL(string: dest) {
            result.addAttribute(.link, value: url, range: r)
        }
        return result
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSAttributedString {
        return NSAttributedString(string: " ", attributes: [
            .font: NSFont.systemFont(ofSize: baseFontSize),
        ])
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSAttributedString {
        return NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: baseFontSize),
        ])
    }

    // MARK: Block

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in paragraph.children { result.append(visit(child)) }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        style.paragraphSpacing = paragraph.isContainedInList ? 2 : 8
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(0..<result.length))

        if paragraph.hasSuccessor {
            result.append(paragraph.isContainedInList
                ? .newline(fontSize: baseFontSize)
                : .doubleNewline(fontSize: baseFontSize))
        }
        return result
    }

    mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in heading.children { result.append(visit(child)) }

        let sizes: [Int: CGFloat] = [1: 22, 2: 18, 3: 16, 4: 15, 5: 14, 6: 13]
        let size = sizes[heading.level] ?? baseFontSize
        let r = NSRange(0..<result.length)

        result.enumerateAttribute(.font, in: r, options: []) { val, range, _ in
            let font = (val as? NSFont) ?? NSFont.systemFont(ofSize: size)
            let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            let resized = NSFont(descriptor: bold.fontDescriptor, size: size) ?? bold
            result.addAttribute(.font, value: resized, range: range)
        }

        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = heading.level == 1 ? 16 : (heading.level == 2 ? 14 : 12)
        style.paragraphSpacing = heading.level == 1 ? 8 : 4
        style.lineSpacing = 2
        result.addAttribute(.paragraphStyle, value: style, range: r)

        if heading.hasSuccessor {
            result.append(.doubleNewline(fontSize: baseFontSize))
        }
        return result
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        // Fallback — primary code blocks are extracted by MarkdownContentView
        let result = NSMutableAttributedString(string: codeBlock.code, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: baseFontSize * 0.88, weight: .regular),
            .foregroundColor: NSColor(theme.textPrimary),
            .backgroundColor: NSColor(theme.backgroundTertiary),
        ])
        if codeBlock.hasSuccessor {
            result.append(.newline(fontSize: baseFontSize))
        }
        return result
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for child in blockQuote.children {
            let childStr = visit(child).mutableCopy() as! NSMutableAttributedString

            let depth = blockQuote.quoteDepth
            let indent: CGFloat = 15 + (20 * CGFloat(depth))

            let style = NSMutableParagraphStyle()
            style.headIndent = indent
            style.firstLineHeadIndent = indent
            style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
            style.lineSpacing = 3
            style.paragraphSpacing = 4

            let r = NSRange(0..<childStr.length)
            childStr.addAttribute(.paragraphStyle, value: style, range: r)
            childStr.addAttribute(.foregroundColor, value: NSColor(theme.textSecondary), range: r)

            // Prepend tab for indent
            childStr.insert(NSAttributedString(string: "\t", attributes: [
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .foregroundColor: NSColor(theme.textSecondary),
            ]), at: 0)

            result.append(childStr)
        }

        if blockQuote.hasSuccessor {
            result.append(.doubleNewline(fontSize: baseFontSize))
        }
        return result
    }

    // MARK: Lists

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.systemFont(ofSize: baseFontSize)

        for listItem in unorderedList.listItems {
            let depth = unorderedList.listDepth
            let indent: CGFloat = 15 + (20 * CGFloat(depth))
            let bulletWidth = ceil(NSAttributedString(string: "\u{2022}", attributes: [.font: font]).size().width)
            let firstTab = indent + bulletWidth
            let secondTab = firstTab + 8

            let style = NSMutableParagraphStyle()
            style.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTab),
                NSTextTab(textAlignment: .left, location: secondTab),
            ]
            style.headIndent = secondTab
            style.lineSpacing = 2
            style.paragraphSpacing = 3

            let itemStr = visit(listItem).mutableCopy() as! NSMutableAttributedString
            itemStr.insert(NSAttributedString(string: "\t\u{2022}\t", attributes: [
                .font: font,
                .foregroundColor: NSColor(theme.textPrimary),
                .paragraphStyle: style,
            ]), at: 0)
            // Apply paragraph style to entire item
            itemStr.addAttribute(.paragraphStyle, value: style, range: NSRange(0..<itemStr.length))

            result.append(itemStr)
        }

        if unorderedList.hasSuccessor {
            result.append(.doubleNewline(fontSize: baseFontSize))
        }
        return result
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.systemFont(ofSize: baseFontSize)
        let numFont = NSFont.monospacedDigitSystemFont(ofSize: baseFontSize, weight: .regular)

        for (index, listItem) in orderedList.listItems.enumerated() {
            let depth = orderedList.listDepth
            let indent: CGFloat = 15 + (20 * CGFloat(depth))
            let numWidth = ceil(NSAttributedString(
                string: "\(orderedList.childCount).",
                attributes: [.font: numFont]
            ).size().width)
            let firstTab = indent + numWidth
            let secondTab = firstTab + 8

            let style = NSMutableParagraphStyle()
            style.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTab),
                NSTextTab(textAlignment: .left, location: secondTab),
            ]
            style.headIndent = secondTab
            style.lineSpacing = 2
            style.paragraphSpacing = 3

            let itemStr = visit(listItem).mutableCopy() as! NSMutableAttributedString
            itemStr.insert(NSAttributedString(string: "\t\(index + 1).\t", attributes: [
                .font: numFont,
                .foregroundColor: NSColor(theme.textPrimary),
                .paragraphStyle: style,
            ]), at: 0)
            itemStr.addAttribute(.paragraphStyle, value: style, range: NSRange(0..<itemStr.length))

            result.append(itemStr)
        }

        if orderedList.hasSuccessor {
            result.append(orderedList.isContainedInList
                ? .newline(fontSize: baseFontSize)
                : .doubleNewline(fontSize: baseFontSize))
        }
        return result
    }

    mutating func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in listItem.children { result.append(visit(child)) }
        if listItem.hasSuccessor {
            result.append(.newline(fontSize: baseFontSize))
        }
        return result
    }
}

// MARK: - Extensions

private extension NSMutableAttributedString {
    func applyTrait(_ trait: NSFontTraitMask) {
        enumerateAttribute(.font, in: NSRange(0..<length), options: []) { val, range, _ in
            guard let font = val as? NSFont else { return }
            let newFont = NSFontManager.shared.convert(font, toHaveTrait: trait)
            addAttribute(.font, value: newFont, range: range)
        }
    }
}

private extension NSAttributedString {
    static func newline(fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: fontSize)])
    }
    static func doubleNewline(fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(string: "\n\n", attributes: [.font: NSFont.systemFont(ofSize: fontSize)])
    }
}

private extension Markup {
    var hasSuccessor: Bool {
        guard let childCount = parent?.childCount else { return false }
        return indexInParent < childCount - 1
    }
    var isContainedInList: Bool {
        var el = parent
        while el != nil {
            if el is ListItemContainer { return true }
            el = el?.parent
        }
        return false
    }
}

private extension ListItemContainer {
    var listDepth: Int {
        var depth = 0
        var el = parent
        while el != nil {
            if el is ListItemContainer { depth += 1 }
            el = el?.parent
        }
        return depth
    }
}

private extension BlockQuote {
    var quoteDepth: Int {
        var depth = 0
        var el = parent
        while el != nil {
            if el is BlockQuote { depth += 1 }
            el = el?.parent
        }
        return depth
    }
}
