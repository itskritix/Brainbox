import SwiftUI
import MarkdownUI

// Message bubbles are CONTENT, not navigation — never apply glass here.
// Per Apple's Liquid Glass guidelines: glass is for navigation layer only.

struct MessageBubble: View, Equatable {
    static func == (lhs: MessageBubble, rhs: MessageBubble) -> Bool {
        lhs.message == rhs.message && lhs.isLastAssistantMessage == rhs.isLastAssistantMessage
    }

    @Environment(ThemeManager.self) private var themeManager
    let message: Message
    let isLastAssistantMessage: Bool
    let onCopy: () -> Void
    let onBranch: () -> Void
    let onRegenerate: (() -> Void)?

    @State private var isHovered = false
    @State private var isReasoningExpanded = false
    @State private var hasAutoCollapsed = false

    /// Parsed thinking content and display content from the message
    private var parsedContent: (thinking: String?, display: String) {
        let content = message.content
        // Match <think>...</think> blocks (greedy, handles newlines)
        let pattern = #"<think>\s*([\s\S]*?)\s*</think>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let thinkingRange = Range(match.range(at: 1), in: content) else {
            // Also handle unclosed <think> during streaming
            if content.contains("<think>") && !content.contains("</think>") {
                let parts = content.components(separatedBy: "<think>")
                let before = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let thinking = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                let display = before.isEmpty ? "" : before
                return (thinking, display)
            }
            return (nil, content)
        }
        let thinking = String(content[thinkingRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = regex.stringByReplacingMatches(
            in: content,
            range: NSRange(content.startIndex..., in: content),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return (thinking.isEmpty ? nil : thinking, cleaned)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isUser {
                Spacer()
                    .frame(minWidth: 60)
                    .layoutPriority(-1)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, message.isUser ? 0 : 16)
        .padding(.vertical, message.isUser ? 6 : 12)
        .onChange(of: message.content, initial: true) {
            guard message.isAssistant, message.isStreaming else { return }
            if message.content.isEmpty {
                hasAutoCollapsed = false
                isReasoningExpanded = false
                return
            }
            guard !hasAutoCollapsed else { return }
            let parsed = parsedContent
            if parsed.thinking != nil && parsed.display.isEmpty {
                isReasoningExpanded = true
            } else if parsed.thinking != nil && !parsed.display.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isReasoningExpanded = false
                }
                hasAutoCollapsed = true
            }
        }
    }

    private var userBubble: some View {
        let theme = themeManager.colors
        let hasAttachments = message.attachments != nil && !message.attachments!.isEmpty
        let hasText = !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .trailing, spacing: 8) {
            // Attachments — displayed OUTSIDE the text bubble, right-aligned
            if hasAttachments {
                AttachmentGrid(attachments: message.attachments!)
            }

            // Text content in its own bubble
            if hasText {
                Text(message.content)
                    .textSelection(.enabled)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            theme.backgroundTertiary
                            theme.accent.opacity(0.3)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantBubble: some View {
        let theme = themeManager.colors
        let parsed = parsedContent

        return VStack(alignment: .leading, spacing: 6) {
            if message.isStreaming && message.content.isEmpty {
                StreamingIndicator()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(theme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                    .transition(.opacity)
            } else {
                // Reasoning disclosure (if thinking content exists)
                if let thinking = parsed.thinking {
                    reasoningDisclosure(thinking: thinking, theme: theme)
                }

                // Main content (skip if empty — e.g. still thinking during stream)
                if !parsed.display.isEmpty {
                    Markdown(parsed.display)
                        .markdownTheme(markdownTheme(theme: theme))
                        .textSelection(.enabled)
                } else if message.isStreaming {
                    // Still thinking, no display content yet
                    StreamingIndicator()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                        .transition(.opacity)
                }
            }

            if !message.isStreaming {
                MessageActionBar(
                    onCopy: onCopy,
                    onBranch: onBranch,
                    onRegenerate: isLastAssistantMessage ? onRegenerate : nil,
                    modelLabel: message.modelIdentifier
                )
                .opacity(isHovered || isLastAssistantMessage ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .padding(.top, 2)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func reasoningDisclosure(thinking: String, theme: AppThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isReasoningExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.textSecondary)

                    Text("Reasoning")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.textSecondary)

                    Image(systemName: isReasoningExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isReasoningExpanded {
                Text(thinking)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.backgroundTertiary.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 4)
    }

    private func markdownTheme(theme: AppThemeColors) -> MarkdownUI.Theme {
        .gitHub.text {
            ForegroundColor(theme.textPrimary)
            BackgroundColor(.clear)
            FontSize(14)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(22)
                    ForegroundColor(theme.textPrimary)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 14, bottom: 6)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(18)
                    ForegroundColor(theme.textPrimary)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 12, bottom: 4)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(16)
                    ForegroundColor(theme.textPrimary)
                }
        }
        .strong {
            FontWeight(.semibold)
            ForegroundColor(theme.textPrimary)
        }
        .emphasis {
            FontStyle(.italic)
            ForegroundColor(theme.textPrimary)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            ForegroundColor(theme.accent)
            BackgroundColor(theme.backgroundTertiary)
        }
        .codeBlock { configuration in
            VStack(spacing: 0) {
                // Header: language label + copy button
                HStack {
                    Text(configuration.language ?? "code")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textTertiary)

                    Spacer()

                    CodeCopyButton(content: configuration.content, tintColor: theme.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.backgroundTertiary.opacity(0.6))

                // Code content
                ScrollView(.horizontal, showsIndicators: false) {
                    configuration.label
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.88))
                            ForegroundColor(theme.textPrimary)
                        }
                }
                .padding(12)
            }
            .background(theme.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
            .markdownMargin(top: 8, bottom: 8)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accent.opacity(0.5))
                    .frame(width: 3)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(theme.textSecondary)
                        FontStyle(.italic)
                    }
                    .padding(.leading, 10)
            }
            .markdownMargin(top: 8, bottom: 8)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .link {
            ForegroundColor(theme.accent)
        }
        .thematicBreak {
            Divider()
                .overlay(theme.border)
                .markdownMargin(top: 12, bottom: 12)
        }
    }
}
