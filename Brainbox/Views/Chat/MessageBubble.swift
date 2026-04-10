import SwiftUI
import AppKit

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
    let onEditSubmit: ((String) -> Void)?

    @State private var isHovered = false
    @State private var isUserHovered = false
    @State private var isEditing = false
    @State private var editText = ""
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

    private func cancelEdit() {
        withAnimation(.spring(duration: 0.35, bounce: 0.12)) {
            isEditing = false
        }
    }

    private func submitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(duration: 0.35, bounce: 0.12)) {
            isEditing = false
        }
        onEditSubmit?(trimmed)
    }

    private var userBubble: some View {
        let theme = themeManager.colors
        let hasAttachments = message.attachments != nil && !message.attachments!.isEmpty
        let hasText = !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .trailing, spacing: 6) {
            // Attachments
            if hasAttachments {
                AttachmentGrid(attachments: message.attachments!)
            }

            if hasText || isEditing {
                // Single container that morphs between display and edit
                VStack(alignment: .leading, spacing: 0) {
                    if isEditing {
                        EditTextView(text: $editText, onEscape: cancelEdit, onSubmit: submitEdit)
                            .font(.system(size: 14))
                            .frame(minHeight: 36, maxHeight: 200)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        Divider()
                            .background(theme.border.opacity(0.3))

                        HStack {
                            Spacer()

                            Button(action: cancelEdit) {
                                Text("Cancel")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(theme.surfacePrimary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(theme.border.opacity(0.4), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(action: submitEdit) {
                                Text("Send")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 7)
                                    .background(theme.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    } else {
                        Text(message.content)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                }
                .background(
                    ZStack {
                        theme.backgroundTertiary
                        theme.accent.opacity(isEditing ? 0 : 0.3)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: isEditing ? AppTheme.radiusXL : AppTheme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: isEditing ? AppTheme.radiusXL : AppTheme.radiusLarge)
                        .stroke(theme.border.opacity(isEditing ? 0.4 : 0), lineWidth: 1)
                )
                .frame(maxWidth: isEditing ? .infinity : nil, alignment: .leading)
            }

            // Copy & Edit actions
            if !isEditing {
                UserMessageActionBar(
                    onCopy: onCopy,
                    onEdit: onEditSubmit != nil ? {
                        editText = message.content
                        withAnimation(.spring(duration: 0.35, bounce: 0.12)) {
                            isEditing = true
                        }
                    } : nil
                )
                .opacity(isUserHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isUserHovered)
            }
        }
        .frame(maxWidth: .infinity, alignment: isEditing ? .leading : .trailing)
        .animation(.spring(duration: 0.35, bounce: 0.12), value: isEditing)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isUserHovered = hovering
            }
        }
    }

    private var assistantBubble: some View {
        let theme = themeManager.colors
        let parsed = parsedContent
        let showActionBar = isHovered || isLastAssistantMessage

        return VStack(alignment: .leading, spacing: 6) {
            if message.isStreaming && message.content.isEmpty {
                StreamingIndicator()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(theme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                    .transition(.opacity)
            } else {
                if let thinking = parsed.thinking {
                    reasoningDisclosure(thinking: thinking, theme: theme)
                }

                if !parsed.display.isEmpty {
                    MarkdownContentView(markdown: parsed.display, theme: theme)
                } else if message.isStreaming {
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
                .opacity(showActionBar ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: showActionBar)
                .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
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

struct EditTextView: NSViewRepresentable {
    @Binding var text: String
    var onEscape: () -> Void
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = EditNSTextView()
        textView.delegate = context.coordinator
        textView.editDelegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.string = text

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditTextView

        init(_ parent: EditTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func handleEscape() { parent.onEscape() }
        func handleSubmit() { parent.onSubmit() }
    }
}

class EditNSTextView: NSTextView {
    weak var editDelegate: EditTextView.Coordinator?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleStandardEditingKeyEquivalent(with: event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 53 {
            editDelegate?.handleEscape()
            return
        }

        if event.keyCode == 36 && flags.isEmpty {
            editDelegate?.handleSubmit()
            return
        }

        super.keyDown(with: event)
    }
}
