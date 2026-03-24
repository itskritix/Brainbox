import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(ThemeManager.self) private var themeManager
    let conversationId: String
    @Bindable var viewModel: ChatViewModel
    var onBranchCreated: ((String) -> Void)?
    @State private var inputText = ""
    @State private var showModelPicker = false
    @State private var shouldAutoScroll = true
    @State private var showFilePicker = false
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var isErrorHovered = false
    private let attachmentService = AttachmentService()
    private let localAttachmentService = LocalAttachmentService()

    var body: some View {
        let theme = themeManager.colors

        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.messages) { message in
                            let isLastAssistant = message.isAssistant
                                && message.id == lastAssistantMessageId
                            MessageBubble(
                                message: message,
                                isLastAssistantMessage: isLastAssistant,
                                onCopy: { copyToClipboard(message.content) },
                                onBranch: { branchFrom(messageId: message.id) },
                                onRegenerate: {
                                    viewModel.regenerate(
                                        messageId: message.id,
                                        conversationId: conversationId
                                    )
                                }
                            )
                            .equatable()
                            .id(message.id)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                            .onAppear { shouldAutoScroll = true }
                            .onDisappear { shouldAutoScroll = false }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.messages.count) {
                    shouldAutoScroll = true
                    scrollToBottom(proxy: proxy)
                }
                .overlay(alignment: .bottom) {
                    if !shouldAutoScroll {
                        Button {
                            shouldAutoScroll = true
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
                .animation(.easeInOut(duration: 0.15), value: shouldAutoScroll)
            }

            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.warning)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button {
                        viewModel.errorMessage = nil
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
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                .onHover { isErrorHovered = $0 }
                .task(id: "\(error)-\(isErrorHovered)") {
                    // Only count down when not hovered
                    guard !isErrorHovered else { return }
                    try? await Task.sleep(for: .seconds(5))
                    if viewModel.errorMessage == error {
                        viewModel.errorMessage = nil
                    }
                }
            }

            MessageInputView(
                text: $inputText,
                isStreaming: viewModel.isAssistantStreaming,
                selectedModel: $viewModel.selectedModel,
                models: viewModel.availableModels,
                showModelPicker: $showModelPicker,
                pendingAttachments: pendingAttachments,
                queuedMessagePreviews: viewModel.queuedMessagePreviews,
                onSend: { sendMessage() },
                onInterrupt: { viewModel.stopStreaming() },
                onRecallLatestQueued: { viewModel.popLastQueuedMessage() },
                onAttachFile: { showFilePicker = true },
                onRemoveAttachment: { id in removeAttachment(id: id) },
                onFilesDropped: { urls in handleDroppedFiles(urls) },
                onImagePasted: { data in handlePastedImage(data) }
            )
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
                        selectedModel: $viewModel.selectedModel,
                        models: viewModel.availableModels,
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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.jpeg, .png, .gif, .webP, .pdf],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                handleDroppedFiles(urls)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .onAppear {
            viewModel.loadConversation(conversationId)
            viewModel.loadModels()
        }
        .onChange(of: conversationId) { _, newId in
            pendingAttachments = []
            viewModel.loadConversation(newId)
        }
        .onDisappear {
            viewModel.unsubscribeMessages()
        }
    }

    private var lastAssistantMessageId: String? {
        viewModel.messages.last(where: { $0.isAssistant })?.id
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func branchFrom(messageId: String) {
        Task {
            if let newId = await viewModel.branch(
                fromMessageId: messageId,
                conversationId: conversationId
            ) {
                onBranchCreated?(newId)
            }
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
        pendingAttachments = []
        viewModel.send(content: content, conversationId: conversationId, attachments: attachmentInfos)
    }

    private func handleDroppedFiles(_ urls: [URL]) {
        for url in urls {
            guard pendingAttachments.count < AttachmentService.maxAttachmentsPerMessage else {
                viewModel.errorMessage = "Maximum \(AttachmentService.maxAttachmentsPerMessage) attachments per message."
                break
            }
            do {
                var attachment = try attachmentService.processFile(url: url)
                pendingAttachments.append(attachment)
                let index = pendingAttachments.count - 1
                saveAttachmentLocally(at: index)
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func handlePastedImage(_ data: Data) {
        guard pendingAttachments.count < AttachmentService.maxAttachmentsPerMessage else {
            viewModel.errorMessage = "Maximum \(AttachmentService.maxAttachmentsPerMessage) attachments per message."
            return
        }
        guard let image = NSImage(data: data) else { return }
        do {
            var attachment = try attachmentService.processImageFromPasteboard(image)
            pendingAttachments.append(attachment)
            let index = pendingAttachments.count - 1
            saveAttachmentLocally(at: index)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func saveAttachmentLocally(at index: Int) {
        let attachment = pendingAttachments[index]

        do {
            let result = try localAttachmentService.save(
                attachment: attachment,
                conversationId: conversationId
            )
            if let idx = pendingAttachments.firstIndex(where: { $0.id == attachment.id }) {
                pendingAttachments[idx].savedState = .saved(attachmentId: result.attachmentId, localPath: result.localPath)
            }
        } catch {
            if let idx = pendingAttachments.firstIndex(where: { $0.id == attachment.id }) {
                pendingAttachments[idx].savedState = .failed(error: error.localizedDescription)
            }
        }
    }

    private func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }
}
