import SwiftUI
import AppKit
import UniformTypeIdentifiers

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> TrafficLightHostView {
        TrafficLightHostView()
    }
    func updateNSView(_ nsView: TrafficLightHostView, context: Context) {}
}

private class TrafficLightHostView: NSView {
    private let offsetX: CGFloat = 10
    private let offsetFromTop: CGFloat = 4
    private var didConfigure = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, !didConfigure else { return }
        didConfigure = true

        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true

        repositionTrafficLights()

        NotificationCenter.default.addObserver(
            self, selector: #selector(onWindowResize),
            name: NSWindow.didResizeNotification, object: window
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(onWindowResize),
            name: NSWindow.didEnterFullScreenNotification, object: window
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(onWindowResize),
            name: NSWindow.didExitFullScreenNotification, object: window
        )
    }

    @objc private func onWindowResize() {
        repositionTrafficLights()
    }

    private func repositionTrafficLights() {
        guard let window else { return }
        guard !window.styleMask.contains(.fullScreen) else { return }
        guard let close = window.standardWindowButton(.closeButton),
              let container = close.superview,
              let parent = container.superview else { return }

        let y: CGFloat
        if parent.isFlipped {
            y = offsetFromTop
        } else {
            y = parent.frame.height - container.frame.height - offsetFromTop
        }
        container.setFrameOrigin(NSPoint(x: offsetX, y: y))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    let keychainService: KeychainService
    let localModelService: LocalModelService

    @State private var dataService = SwiftDataService()
    @State private var conversationListVM: ConversationListViewModel?
    @State private var chatVM: ChatViewModel?
    @State private var profileVM: ProfileViewModel?
    @State private var selectedConversationId: String?
    @State private var isSidebarVisible = true
    // Auto-compact sidebar behaviour (mirrors Finder / Mail):
    //
    // - Below `compactWidthThreshold`, the sidebar is force-hidden so the
    //   chat column doesn't get crushed.
    // - When the window widens back above the threshold, we restore whatever
    //   the sidebar's visibility was *before* entering compact mode, so the
    //   user's explicit choice is preserved across resize jitter.
    // - Manual toggles while in compact mode also update the remembered
    //   preference, so "I closed the sidebar and then made the window wide"
    //   keeps the sidebar closed.
    @State private var isInCompactLayout = false
    @State private var sidebarPreferenceBeforeCompact = true
    private let compactWidthThreshold: CGFloat = 820

    // Sidebar motion curves.
    //
    // - Drawer close is the motion users notice most — the backdrop has to
    //   fade AND the panel has to slide off-screen, both over a distance
    //   large enough that any front-loaded curve reads as a snap. Springs
    //   (even gentle ones with bounce: 0.1) put ~70% of their motion in the
    //   first 20% of the duration, which is exactly why a 0.4s spring still
    //   *felt* instant. `easeInOut(duration: 0.38)` distributes motion
    //   evenly: noticeable ramp-up, clear middle, perceptible settle. Same
    //   vocabulary Finder uses for its column-width drags.
    // - The inline push keeps a shorter ease — it's just a layout change,
    //   not a hero transition, and matches ConversationRow / SidebarView.
    private static let drawerAnimation: Animation = .easeInOut(duration: 0.38)
    private static let inlineSidebarAnimation: Animation = .easeInOut(duration: 0.2)
    // Single source of truth for sidebar width — referenced both in the
    // sidebar's own `.frame(width:)` and the drawer's offscreen offset
    // so they can never drift out of sync.
    private static let sidebarWidth: CGFloat = 260
    @State private var isFullScreen = false
    @State private var didExpandFromQuickChat = false
    @State private var inputText = ""
    @State private var showModelPicker = false
    @State private var showSettings = false
    @State private var settingsTab: SettingsTab = .general
    @State private var searchFocusTrigger = false
    @State private var isAtBottom = true
    @State private var userDidSend = false
    @State private var suggestionsVisible = true
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var showFilePicker = false
    private let attachmentService = AttachmentService()
    private let localAttachmentService = LocalAttachmentService()

    private var conversationListVMUnwrapped: ConversationListViewModel {
        conversationListVM ?? ConversationListViewModel(dataService: dataService)
    }

    private var chatVMUnwrapped: ChatViewModel {
        chatVM ?? ChatViewModel(dataService: dataService, keychainService: keychainService, localModelService: localModelService)
    }

    private var profileVMUnwrapped: ProfileViewModel {
        profileVM ?? ProfileViewModel(dataService: dataService)
    }

    var body: some View {
        let theme = themeManager.colors

        mainLayout
        .background(theme.backgroundPrimary)
        .background(WindowConfigurator())
        .ignoresSafeArea(.all, edges: .top)
        .onAppear {
            let ds = dataService
            let kc = keychainService
            if conversationListVM == nil {
                conversationListVM = ConversationListViewModel(dataService: ds)
            }
            if chatVM == nil {
                chatVM = ChatViewModel(dataService: ds, keychainService: kc, localModelService: localModelService)
            }
            if profileVM == nil {
                profileVM = ProfileViewModel(dataService: ds)
            }
            chatVMUnwrapped.loadModels()
            conversationListVMUnwrapped.refresh()
        }
        .onChange(of: localModelService.downloadedModels.count) { _, _ in
            chatVMUnwrapped.loadModels()
        }
        .onChange(of: keychainService.revision) { _, _ in
            chatVMUnwrapped.loadModels()
        }
        .onChange(of: profileVMUnwrapped.activeProfileId) { _, newProfileId in
            conversationListVMUnwrapped.setProfileId(newProfileId)
            selectedConversationId = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickChatExpandToConversation)) { notification in
            if let conversationId = notification.userInfo?["conversationId"] as? String {
                let messages = notification.userInfo?["messages"] as? [Message] ?? []
                chatVMUnwrapped.loadConversation(conversationId, initialMessages: messages)
                didExpandFromQuickChat = true
                selectedConversationId = conversationId
            }
        }
        .modifier(ShortcutHandlers(
            conversationListVM: conversationListVMUnwrapped,
            chatVM: chatVMUnwrapped,
            profileVM: profileVMUnwrapped,
            selectedConversationId: $selectedConversationId,
            isSidebarVisible: sidebarVisibleBinding,
            showModelPicker: $showModelPicker,
            showSettings: $showSettings,
            settingsTab: $settingsTab,
            searchFocusTrigger: $searchFocusTrigger,
            inputText: $inputText,
            onCopy: copyToClipboard,
            onNavigate: navigateConversation,
            keychainService: keychainService
        ))
    }

    private var mainLayout: some View {
        let theme = themeManager.colors
        let sidebar = SidebarView(
            viewModel: conversationListVMUnwrapped,
            profileVM: profileVMUnwrapped,
            selectedConversationId: $selectedConversationId,
            isSidebarVisible: sidebarVisibleBinding,
            searchFocusTrigger: searchFocusTrigger,
            keychainService: keychainService,
            streamingConversationIds: chatVMUnwrapped.streamingConversationIds,
            onCancelBackgroundStream: { conversationId in
                chatVMUnwrapped.cancelBackgroundStream(for: conversationId)
            }
        )
        .frame(width: Self.sidebarWidth)

        // Two rendering modes:
        // - Wide windows: sidebar lives INLINE in the HStack and pushes the
        //   chat column aside. Classic macOS layout.
        // - Narrow windows (compact): sidebar floats OVER the chat as a
        //   drawer, with a tap-to-dismiss backdrop. This matches how Finder,
        //   Mail, and iPadOS split views behave below their min width.
        return ZStack(alignment: .leading) {
            // 1. Base layer — chat, plus the inline sidebar when not compact.
            HStack(spacing: 0) {
                if isSidebarVisible && !isInCompactLayout {
                    sidebar
                        .transition(.move(edge: .leading))
                }

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 2. Overlay drawer — compact mode only. Animates via
            //    CONTINUOUS PROPERTIES (offset + opacity), not via
            //    conditional mount + `.transition(...)`.
            //
            //    Why: SwiftUI's insertion/removal transitions through a
            //    conditional-rendered parent were unreliable on macOS —
            //    tapping the backdrop would skip the slide entirely and
            //    read as an instant snap. Continuous property animations
            //    driven by `.animation(_:value:)` are deterministic: they
            //    interpolate every frame between the old and new values,
            //    regardless of transaction state.
            //
            //    The drawer stays mounted while in compact mode; when
            //    hidden it sits at x: -sidebarWidth with opacity 0 and
            //    hit-testing disabled.
            if isInCompactLayout {
                let drawerHidden = !isSidebarVisible

                Color.black
                    .opacity(drawerHidden ? 0 : 0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { toggleSidebarManually(to: false) }
                    .allowsHitTesting(!drawerHidden)
                    .animation(Self.drawerAnimation, value: isSidebarVisible)

                sidebar
                    .shadow(
                        color: .black.opacity(drawerHidden ? 0 : 0.35),
                        radius: 16, x: 4, y: 0
                    )
                    .offset(x: drawerHidden ? -Self.sidebarWidth : 0)
                    .allowsHitTesting(!drawerHidden)
                    .animation(Self.drawerAnimation, value: isSidebarVisible)
            }
        }
        .background(theme.backgroundPrimary)
        .overlay(alignment: .topLeading) {
            // The "open sidebar" button is visible in BOTH layout modes when
            // the sidebar is hidden. In compact mode it opens the drawer
            // overlay; in wide mode it inserts the sidebar inline.
            if !isSidebarVisible {
                Button {
                    toggleSidebarManually(to: true)
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .padding(.leading, isFullScreen ? 12 : 85)
                .padding(.top, 7)
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            applyCompactLayout(for: newWidth)
        }
        .onChange(of: selectedConversationId) { _, _ in
            // Tapping a conversation in the overlay drawer should auto-dismiss
            // it — same UX as iPadOS. In wide mode this is a no-op because
            // `isInCompactLayout` is false and the sidebar stays pinned.
            if isInCompactLayout && isSidebarVisible {
                toggleSidebarManually(to: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
    }

    /// A Binding we hand to children (SidebarView, ShortcutHandlers, etc).
    /// Every external write goes through `toggleSidebarManually` so the
    /// remembered preference stays in sync — otherwise a keyboard-shortcut
    /// close at wide width would silently re-open on the next compact-mode
    /// exit.
    private var sidebarVisibleBinding: Binding<Bool> {
        Binding(
            get: { isSidebarVisible },
            set: { newValue in toggleSidebarManually(to: newValue) }
        )
    }

    /// Called whenever the window width changes. Toggles compact mode and
    /// preserves the user's sidebar preference across compact transitions.
    private func applyCompactLayout(for width: CGFloat) {
        let shouldBeCompact = width < compactWidthThreshold

        if shouldBeCompact, !isInCompactLayout {
            // Entering compact mode — remember current intent, then close.
            // Wrapped in `withAnimation` so the inline sidebar's exit slide
            // and the compact-mode flip share one transaction.
            sidebarPreferenceBeforeCompact = isSidebarVisible
            withAnimation(Self.drawerAnimation) {
                isInCompactLayout = true
                if isSidebarVisible {
                    isSidebarVisible = false
                }
            }
        } else if !shouldBeCompact, isInCompactLayout {
            // Leaving compact mode. Two paths:
            //
            // 1. Drawer was ALREADY OPEN and user wants it open in wide mode.
            //    The overlay drawer and the inline sidebar both render the
            //    same SidebarView at the same leading x, same width. If we
            //    wrap the swap in `withAnimation`, the inline sidebar fires
            //    its `.transition(.move(edge: .leading))` and slides in
            //    from -260 while the drawer vanishes at x=0 — which reads
            //    as "close + reopen" even though the panel never moved.
            //    Fix: SILENT SWAP. No withAnimation → no transition fires.
            //    The drawer unmounts and the inline mounts in the same
            //    render pass at the same visual position. User sees the
            //    scrim disappear and the chat column reflow; the sidebar
            //    panel itself stays put.
            //
            // 2. Drawer was closed (or user's preference is closed). No
            //    visual overlap, so animate normally with the inline curve.
            let drawerWasVisible = isSidebarVisible
            let preferenceKeepsItOpen = sidebarPreferenceBeforeCompact

            if drawerWasVisible && preferenceKeepsItOpen {
                // Silent swap — drawer ↔ inline at identical position.
                isInCompactLayout = false
            } else {
                withAnimation(Self.inlineSidebarAnimation) {
                    isInCompactLayout = false
                    if isSidebarVisible != sidebarPreferenceBeforeCompact {
                        isSidebarVisible = sidebarPreferenceBeforeCompact
                    }
                }
            }
        }
    }

    /// Explicit user-driven sidebar toggle. Updates both the current
    /// visibility AND the remembered preference, so a manual close at
    /// wide width survives a resize loop.
    ///
    /// Picks the animation curve based on *current* mode — the longer
    /// drawer ease when overlaying so the scrim fade + panel slide read
    /// as a real transition, the shorter inline ease when pushing the
    /// HStack layout.
    private func toggleSidebarManually(to visible: Bool) {
        sidebarPreferenceBeforeCompact = visible
        let animation = isInCompactLayout ? Self.drawerAnimation : Self.inlineSidebarAnimation
        withAnimation(animation) {
            isSidebarVisible = visible
        }
    }

    private var detailView: some View {
        let theme = themeManager.colors
        let cvm = chatVMUnwrapped

        return VStack(spacing: 0) {
            ZStack {
                if selectedConversationId != nil {
                    if cvm.isLoading && cvm.messages.isEmpty {
                        VStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(cvm.messages) { message in
                                    let isLastAssistant = message.isAssistant
                                        && message.id == lastAssistantMessageId
                                    MessageBubble(
                                        message: message,
                                        isLastAssistantMessage: isLastAssistant,
                                        onCopy: { copyToClipboard(message.content) },
                                        onBranch: { branchFrom(messageId: message.id) },
                                        onRegenerate: { regenerateMessage(message.id) },
                                        onEditSubmit: message.isUser ? { newContent in
                                            guard let convId = selectedConversationId else { return }
                                            cvm.editAndResend(
                                                messageId: message.id,
                                                newContent: newContent,
                                                conversationId: convId
                                            )
                                        } : nil
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding(.vertical, 16)
                            .frame(maxWidth: 720)
                            .frame(maxWidth: .infinity)
                        }
                        .onScrollGeometryChange(for: Bool.self) { geometry in
                            let maxOffset = geometry.contentSize.height - geometry.containerSize.height
                            return maxOffset <= 0 || geometry.contentOffset.y >= maxOffset - 50
                        } action: { _, isNearBottom in
                            isAtBottom = isNearBottom
                        }
                        .onChange(of: cvm.messages.count) {
                            if userDidSend || isAtBottom {
                                userDidSend = false
                                scrollToBottom(proxy: proxy)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if !isAtBottom {
                                Button {
                                    scrollToBottom(proxy: proxy)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(theme.textSecondary)
                                        .frame(width: 32, height: 32)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(theme.border.opacity(0.5), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, 8)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: isAtBottom)
                    }
                    .transition(.blurReplace)
                } else {
                    let displayName = UserDefaults.standard.string(forKey: UDKey.userName)
                    EmptyStateView(
                        userName: displayName,
                        keychainService: keychainService
                    ) { prompt in
                        inputText = prompt
                        NotificationCenter.default.post(name: .appFocusInput, object: nil)
                    } onNewChat: { }
                    .opacity(suggestionsVisible ? 1 : 0)
                    .allowsHitTesting(suggestionsVisible)
                    .animation(.easeOut(duration: 0.25), value: suggestionsVisible)
                    .transition(.blurReplace)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedConversationId)

            if let error = cvm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.warning)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button {
                        chatVMUnwrapped.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                .frame(maxWidth: 680)
                .padding(.bottom, 4)
                .task(id: error) {
                    try? await Task.sleep(for: .seconds(30))
                    if chatVMUnwrapped.errorMessage == error {
                        chatVMUnwrapped.errorMessage = nil
                    }
                }
            }

            MessageInputView(
                text: $inputText,
                isStreaming: cvm.isAssistantStreaming,
                selectedModel: Bindable(cvm).selectedModel,
                models: cvm.availableModels,
                showModelPicker: $showModelPicker,
                pendingAttachments: pendingAttachments,
                queuedMessagePreviews: cvm.queuedMessagePreviews,
                onSend: { sendMessage() },
                onInterrupt: { cvm.stopStreaming() },
                onRecallLatestQueued: { cvm.popLastQueuedMessage() },
                onAttachFile: { showFilePicker = true },
                onRemoveAttachment: { id in pendingAttachments.removeAll { $0.id == id } },
                onFilesDropped: { urls in handleDroppedFiles(urls) },
                onImagePasted: { data in handlePastedImage(data) }
            )
            .frame(maxWidth: 680)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(theme.backgroundPrimary)
        .overlayPreferenceValue(ModelSelectorAnchorKey.self) { anchor in
            GeometryReader { geometry in
                if showModelPicker, let anchor {
                    let buttonRect = geometry[anchor]
                    let panelW = ModelPickerPanel.panelWidth
                    let panelH = ModelPickerPanel.panelHeight
                    let gap: CGFloat = 8

                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { showModelPicker = false }

                    ModelPickerPanel(
                        selectedModel: Bindable(cvm).selectedModel,
                        models: cvm.availableModels,
                        isPresented: $showModelPicker
                    )
                    .frame(width: panelW, height: panelH)
                    .position(
                        x: buttonRect.minX + panelW / 2,
                        y: buttonRect.minY - gap - panelH / 2
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomLeading)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: showModelPicker)
        }
        .onChange(of: selectedConversationId) { _, newId in
            isAtBottom = true
            userDidSend = false
            if didExpandFromQuickChat {
                didExpandFromQuickChat = false
                return
            }
            if let newId {
                chatVMUnwrapped.loadConversation(newId)
            } else {
                chatVMUnwrapped.unsubscribeMessages()
                inputText = ""
                suggestionsVisible = true
            }
        }
        .onChange(of: inputText) { _, newValue in
            guard selectedConversationId == nil else { return }
            let isEmpty = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isEmpty {
                if !userDidSend {
                    suggestionsVisible = true
                }
            } else {
                suggestionsVisible = false
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.jpeg, .png, .gif, .webP, .pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                handleDroppedFiles(urls)
            case .failure(let error):
                chatVMUnwrapped.errorMessage = error.localizedDescription
            }
        }
    }

    private var lastAssistantMessageId: String? {
        chatVMUnwrapped.messages.last(where: { $0.isAssistant })?.id
    }

    private func branchFrom(messageId: String) {
        guard let conversationId = selectedConversationId else { return }
        Task {
            if let newId = await chatVMUnwrapped.branch(
                fromMessageId: messageId,
                conversationId: conversationId
            ) {
                conversationListVMUnwrapped.refresh()
                selectedConversationId = newId
            }
        }
    }

    private func regenerateMessage(_ messageId: String) {
        guard let conversationId = selectedConversationId else { return }
        chatVMUnwrapped.regenerate(messageId: messageId, conversationId: conversationId)
    }

    private func sendFromEmptyState(_ content: String, attachments: [AttachmentInfo] = []) {
        if let id = conversationListVMUnwrapped.createConversation() {
            chatVMUnwrapped.loadConversation(id)
            selectedConversationId = id
            chatVMUnwrapped.send(content: content, conversationId: id, attachments: attachments)
        } else {
            userDidSend = false
            suggestionsVisible = true
        }
    }

    private func sendMessage() {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentInfos: [AttachmentInfo] = pendingAttachments.compactMap { att in
            guard case .saved(let savedId, let localPath) = att.savedState else { return nil }
            return AttachmentInfo(
                attachmentId: savedId,
                fileName: att.fileName,
                fileType: att.fileType.rawValue,
                mimeType: att.mimeType,
                fileSize: att.fileSize,
                width: att.width,
                height: att.height,
                localPath: localPath
            )
        }
        guard !content.isEmpty || !attachmentInfos.isEmpty else { return }
        inputText = ""
        let currentAttachments = attachmentInfos
        pendingAttachments = []
        userDidSend = true

        if let conversationId = selectedConversationId {
            chatVMUnwrapped.send(content: content, conversationId: conversationId, attachments: currentAttachments)
            conversationListVMUnwrapped.refresh()
        } else {
            sendFromEmptyState(content, attachments: currentAttachments)
        }
    }

    private func handleDroppedFiles(_ urls: [URL]) {
        for url in urls {
            guard pendingAttachments.count < AttachmentService.maxAttachmentsPerMessage else {
                chatVMUnwrapped.errorMessage = "Maximum \(AttachmentService.maxAttachmentsPerMessage) attachments per message."
                break
            }
            do {
                var attachment = try attachmentService.processFile(url: url)
                saveAttachmentLocally(&attachment)
                pendingAttachments.append(attachment)
            } catch {
                chatVMUnwrapped.errorMessage = error.localizedDescription
            }
        }
    }

    private func handlePastedImage(_ data: Data) {
        guard pendingAttachments.count < AttachmentService.maxAttachmentsPerMessage else {
            chatVMUnwrapped.errorMessage = "Maximum \(AttachmentService.maxAttachmentsPerMessage) attachments per message."
            return
        }
        guard let image = NSImage(data: data) else { return }
        do {
            var attachment = try attachmentService.processImageFromPasteboard(image)
            saveAttachmentLocally(&attachment)
            pendingAttachments.append(attachment)
        } catch {
            chatVMUnwrapped.errorMessage = error.localizedDescription
        }
    }

    private func saveAttachmentLocally(_ attachment: inout PendingAttachment) {
        let conversationId: String
        if let existing = selectedConversationId {
            conversationId = existing
        } else if let newId = conversationListVMUnwrapped.createConversation() {
            selectedConversationId = newId
            conversationId = newId
        } else {
            attachment.savedState = .failed(error: "Could not create conversation")
            return
        }

        do {
            let result = try localAttachmentService.save(
                attachment: attachment,
                conversationId: conversationId
            )

            attachment.savedState = .saved(attachmentId: result.attachmentId, localPath: result.localPath)
        } catch {
            attachment.savedState = .failed(error: error.localizedDescription)
        }
    }

    private func navigateConversation(direction: Int) {
        let conversations = conversationListVMUnwrapped.conversations
        guard !conversations.isEmpty else { return }

        if let currentId = selectedConversationId,
           let currentIndex = conversations.firstIndex(where: { $0.id == currentId }) {
            let newIndex = currentIndex + direction
            if conversations.indices.contains(newIndex) {
                selectedConversationId = conversations[newIndex].id
            }
        } else {
            selectedConversationId = conversations.first?.id
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = chatVMUnwrapped.messages.last else { return }
        isAtBottom = true
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

private struct ShortcutHandlers: ViewModifier {
    let conversationListVM: ConversationListViewModel
    let chatVM: ChatViewModel
    let profileVM: ProfileViewModel
    @Binding var selectedConversationId: String?
    @Binding var isSidebarVisible: Bool
    @Binding var showModelPicker: Bool
    @Binding var showSettings: Bool
    @Binding var settingsTab: SettingsTab
    @Binding var searchFocusTrigger: Bool
    @Binding var inputText: String
    let onCopy: (String) -> Void
    let onNavigate: (Int) -> Void
    let keychainService: KeychainService

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .appNewChat)) { _ in
                selectedConversationId = nil
                inputText = ""
            }
            .onReceive(NotificationCenter.default.publisher(for: .appToggleSidebar)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSidebarVisible.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .appOpenSettings)) { _ in
                settingsTab = .general
                showSettings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .appToggleModelPicker)) { _ in
                showModelPicker.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .appCopyLastResponse)) { _ in
                if let lastAssistant = chatVM.messages.last(where: { $0.isAssistant }) {
                    onCopy(lastAssistant.content)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .appDeleteConversation)) { _ in
                guard let id = selectedConversationId else { return }
                chatVM.cancelBackgroundStream(for: id)
                selectedConversationId = nil
                conversationListVM.deleteConversation(id: id)
            }
            .onReceive(NotificationCenter.default.publisher(for: .appSelectPreviousConversation)) { _ in
                onNavigate(-1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .appSelectNextConversation)) { _ in
                onNavigate(1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .appFocusSearch)) { _ in
                if !isSidebarVisible {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarVisible = true
                    }
                }
                searchFocusTrigger.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .appShowShortcuts)) { _ in
                settingsTab = .shortcuts
                showSettings = true
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                chatVM.loadModels()
            }) {
                SettingsView(
                    keychainService: keychainService,
                    profileVM: profileVM,
                    conversationListVM: conversationListVM,
                    selectedTab: settingsTab
                )
            }
    }
}
