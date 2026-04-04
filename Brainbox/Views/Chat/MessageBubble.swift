import SwiftUI

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
                    SelectableMarkdownView(markdown: parsed.display, theme: theme)
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

}
