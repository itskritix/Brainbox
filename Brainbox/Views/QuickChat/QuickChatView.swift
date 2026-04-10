import SwiftUI
import AppKit

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.wantsLayer = true
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Constants

private enum QC {
    static let width: CGFloat = 720
    static let barH: CGFloat = 88
    static let expandedH: CGFloat = 560
    static let radius: CGFloat = 20
}

// MARK: - QuickChatView

struct QuickChatView: View {
    @Environment(ThemeManager.self) private var themeManager
    let dataService: DataServiceProtocol
    let keychainService: KeychainService
    let localModelService: LocalModelService

    @State private var chatVM: ChatViewModel?
    @State private var conversationListVM: ConversationListViewModel?
    @State private var text = ""
    @State private var convId: String?
    @State private var expanded = false
    @State private var hoveredAction: String?
    @State private var copiedId: String?

    let onExpand: (String?, [Message]) -> Void
    let onDismiss: () -> Void
    let onResize: (CGFloat) -> Void

    private var cvm: ChatViewModel {
        chatVM ?? ChatViewModel(dataService: dataService, keychainService: keychainService, localModelService: localModelService)
    }

    private var clvm: ConversationListViewModel {
        conversationListVM ?? ConversationListViewModel(dataService: dataService)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                expandedHeader

                chatArea
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)),
                        removal: .opacity
                    ))
            }

            Spacer(minLength: 0)

            inputBar
        }
        .frame(width: QC.width)
        .frame(height: expanded ? QC.expandedH : QC.barH)
        .background { panelBackground }
        .clipShape(RoundedRectangle(cornerRadius: QC.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QC.radius, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.5), radius: 50, y: 16)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .onAppear {
            if chatVM == nil {
                chatVM = ChatViewModel(dataService: dataService, keychainService: keychainService, localModelService: localModelService)
            }
            if conversationListVM == nil {
                conversationListVM = ConversationListViewModel(dataService: dataService)
            }
            cvm.loadModels()
        }
        .onChange(of: cvm.messages.count) { _, n in
            if n > 0 && !expanded { doExpand() }
        }
        .animation(.spring(duration: 0.5, bounce: 0.1), value: expanded)
    }

    // MARK: - Background (translucent blur like ChatGPT)

    private var panelBackground: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            Color.black.opacity(0.15)
        }
    }

    // MARK: - Expanded Header (close / copy / new chat)

    private var expandedHeader: some View {
        let theme = themeManager.colors

        return HStack {
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)

            Spacer()

            HStack(spacing: 4) {
                headerButton(copiedId == "conv" ? "checkmark" : "doc.on.doc") {
                    let all = cvm.messages.map { $0.content }.joined(separator: "\n\n")
                    copyWithFeedback(all, id: "conv")
                }

                headerButton("square.and.pencil") {
                    resetChat()
                }

                headerButton("arrow.up.left.and.arrow.down.right") {
                    onExpand(convId, cvm.messages)
                }
                .help("Open Full App")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    private func headerButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.colors.textSecondary)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Input Bar (ChatGPT-style two-row)

    private var inputBar: some View {
        let theme = themeManager.colors

        return VStack(spacing: 0) {
            if expanded {
                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 0.5)
            }

            if !cvm.queuedMessagePreviews.isEmpty {
                queuedMessagesView
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
            }

            TextField("Ask anything", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15.5))
                .foregroundStyle(theme.textPrimary)
                .tint(theme.accent)
                .lineLimit(1...4)
                .onSubmit { if canSend { send() } }
                .onKeyPress(keys: [.escape], phases: .down) { _ in
                    onDismiss()
                    return .handled
                }
                .onKeyPress(keys: [.upArrow], phases: .down) { _ in
                    recallLatestQueuedMessage() ? .handled : .ignored
                }
                .onMoveCommand { direction in
                    guard direction == .up else { return }
                    _ = recallLatestQueuedMessage()
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 6)

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                    Text(cvm.selectedModel.name)
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(theme.textSecondary.opacity(0.6))

                Spacer()

                Button {
                    if canSend {
                        send()  // sends normally or queues if streaming
                    } else if cvm.isAssistantStreaming {
                        cvm.stopStreaming()
                    }
                } label: {
                    // Streaming + no content → interrupt (pause icon)
                    // Streaming + has content → queue (text.append icon)
                    // Not streaming + has content → send (arrow up icon)
                    let showInterrupt = cvm.isAssistantStreaming && !canSend
                    let showQueue = cvm.isAssistantStreaming && canSend
                    let isEnabled = canSend || cvm.isAssistantStreaming
                    let iconName = showInterrupt ? "pause.fill" : (showQueue ? "text.append" : "arrow.up")
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            isEnabled ? .white : theme.textTertiary.opacity(0.35)
                        )
                        .frame(width: 32, height: 32)
                        .background(isEnabled ? theme.accent : .white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .disabled(!cvm.isAssistantStreaming && !canSend)
                .animation(.easeOut(duration: 0.2), value: canSend)
                .animation(.easeOut(duration: 0.2), value: cvm.isAssistantStreaming)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .animation(.spring(duration: 0.35), value: expanded)
        }
        .frame(height: QC.barH)
    }

    // MARK: - Chat Area

    private var queuedMessagesView: some View {
        let theme = themeManager.colors
        return QueuedMessagesPillView(
            previews: cvm.queuedMessagePreviews,
            accentColor: theme.accent.opacity(0.9),
            secondaryTextColor: theme.textSecondary.opacity(0.8),
            tertiaryTextColor: theme.textTertiary.opacity(0.75)
        )
    }

    @discardableResult
    private func recallLatestQueuedMessage() -> Bool {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let recalledText = cvm.popLastQueuedMessage() else {
            return false
        }

        text = recalledText
        return true
    }

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(cvm.messages) { msg in
                        msgRow(msg).id(msg.id)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .textSelection(.enabled)
            .onChange(of: cvm.messages.count) { autoScroll(proxy) }
            .onChange(of: cvm.messages.last?.content) { autoScroll(proxy) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Message Row

    @ViewBuilder
    private func msgRow(_ msg: Message) -> some View {
        let theme = themeManager.colors

        if msg.isUser {
            HStack {
                Spacer(minLength: 120)
                Text(msg.content)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if msg.isStreaming && msg.content.isEmpty {
                    HStack {
                        StreamingIndicator()
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else {
                    MarkdownContentView(markdown: msg.content, theme: theme)

                    if !msg.isStreaming {
                        HStack(spacing: 2) {
                            actionIcon(
                                copiedId == "copy-\(msg.id)" ? "checkmark" : "doc.on.doc",
                                id: "copy-\(msg.id)"
                            ) {
                                copyWithFeedback(msg.content, id: "copy-\(msg.id)")
                            }

                            actionIcon("arrow.counterclockwise", id: "regen-\(msg.id)") {
                                if let cid = convId {
                                    cvm.regenerate(messageId: msg.id, conversationId: cid)
                                }
                            }

                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Action Icon Button

    private func actionIcon(_ icon: String, id: String, action: @escaping () -> Void) -> some View {
        let theme = themeManager.colors
        let isHovered = hoveredAction == id

        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovered ? theme.textSecondary : theme.textTertiary.opacity(0.5))
                .frame(width: 26, height: 26)
                .background(isHovered ? .white.opacity(0.06) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.borderless)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredAction = h ? id : nil
            }
        }
    }

    // MARK: - Actions

    private func doExpand() {
        withAnimation(.spring(duration: 0.5, bounce: 0.1)) { expanded = true }
        onResize(QC.expandedH)
    }

    private func resetChat() {
        cvm.unsubscribeMessages()
        convId = nil
        text = ""
    }

    private func send() {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        text = ""

        if let cid = convId {
            cvm.send(content: content, conversationId: cid)
        } else {
            if let id = clvm.createConversation() {
                convId = id
                cvm.loadConversation(id)
                cvm.send(content: content, conversationId: id)
            }
        }
    }

    private func copyWithFeedback(_ text: String, id: String) {
        copyToClipboard(text)
        withAnimation(.easeOut(duration: 0.15)) { copiedId = id }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.15)) {
                if copiedId == id { copiedId = nil }
            }
        }
    }

    private func autoScroll(_ proxy: ScrollViewProxy) {
        guard let last = cvm.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(last.id, anchor: .bottom) }
    }
}
