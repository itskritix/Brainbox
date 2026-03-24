import SwiftUI
import UniformTypeIdentifiers

struct MessageInputView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var text: String
    let isStreaming: Bool
    @Binding var selectedModel: AIModel
    let models: [AIModel]
    @Binding var showModelPicker: Bool
    let pendingAttachments: [PendingAttachment]
    let queuedMessagePreviews: [QueuedMessagesPillView.QueuedPreview]
    let onSend: () -> Void
    let onInterrupt: () -> Void
    let onRecallLatestQueued: () -> String?
    let onAttachFile: () -> Void
    let onRemoveAttachment: (UUID) -> Void
    var onFilesDropped: (([URL]) -> Void)?
    var onImagePasted: ((Data) -> Void)?
    @State private var editorHeight: CGFloat = 22
    @State private var isDragOver = false

    private static let supportedDropTypes: [UTType] = [
        .fileURL, .image, .jpeg, .png, .gif, .webP, .pdf
    ]
    private static let supportedFileExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "pdf"
    ]

    var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasUploadedAttachments = !pendingAttachments.isEmpty && pendingAttachments.allSatisfy { $0.savedState.isSaved }
        return hasText || hasUploadedAttachments
    }

    private var useGlass: Bool { themeManager.useGlassEffect }

    var body: some View {
        let theme = themeManager.colors

        VStack(spacing: 0) {
            if !queuedMessagePreviews.isEmpty {
                queuedMessagesView
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
            }

            // Attachment preview strip
            if !pendingAttachments.isEmpty {
                AttachmentPreviewStrip(
                    attachments: pendingAttachments,
                    onRemove: onRemoveAttachment
                )

                // Provider compatibility warning
                if let warning = providerWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.warning)
                        Text(warning)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                }
            }

            // Text input area — uses NSTextView for full macOS shortcut support
            ChatTextEditor(
                text: $text,
                height: $editorHeight,
                textColor: NSColor(theme.textPrimary),
                font: .systemFont(ofSize: 14),
                placeholderText: "Message...",
                placeholderColor: NSColor(theme.textTertiary),
                onSubmit: onSend,
                canSubmit: canSend,
                onRecallLatestQueued: onRecallLatestQueued,
                onFilesDropped: onFilesDropped,
                onImagePasted: onImagePasted
            )
            .frame(height: editorHeight)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Bottom toolbar — controls inside GlassEffectContainer
            GlassEffectContainer {
                HStack(spacing: 8) {
                    // Attach button
                    Button(action: onAttachFile) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.borderless)

                    ModelSelectorView(
                        selectedModel: $selectedModel,
                        models: models,
                        showPicker: $showModelPicker
                    )

                    Spacer()

                    // Send button
                    sendButton
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .if(useGlass) { view in
            view.glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        }
        .if(!useGlass) { view in
            view
                .background(theme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                        .stroke(theme.border, lineWidth: 1)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(theme.accent, lineWidth: 2)
                .opacity(isDragOver ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isDragOver)
        )
        .overlay {
            if isDragOver {
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .fill(theme.accent.opacity(0.06))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onDrop(of: Self.supportedDropTypes, isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
    }

    @ViewBuilder
    private var sendButton: some View {
        let theme = themeManager.colors
        // Streaming + no content → interrupt (pause icon)
        // Streaming + has content → queue (adds to queue, shown as "text.append" icon)
        // Not streaming + has content → send (arrow up icon)
        let showInterrupt = isStreaming && !canSend
        let showQueue = isStreaming && canSend
        let iconName = showInterrupt ? "pause.fill" : (showQueue ? "text.append" : "arrow.up")
        let isButtonEnabled = canSend || isStreaming
        let fillColor = isButtonEnabled ? theme.accent : theme.surfaceSecondary
        // Has content → send/queue; no content + streaming → interrupt
        let buttonAction: () -> Void = canSend ? onSend : onInterrupt

        if useGlass {
            Button(action: buttonAction) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isButtonEnabled ? .white : theme.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .glassEffect(
                .regular.tint(fillColor),
                in: .circle
            )
            .disabled(!isButtonEnabled)
            .animation(.easeOut(duration: 0.2), value: iconName)
        } else {
            Button(action: buttonAction) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isButtonEnabled ? .white : theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(fillColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
            .disabled(!isButtonEnabled)
            .animation(.easeOut(duration: 0.2), value: iconName)
        }
    }

    private var queuedMessagesView: some View {
        let theme = themeManager.colors
        return QueuedMessagesPillView(
            previews: queuedMessagePreviews,
            accentColor: theme.accent,
            secondaryTextColor: theme.textSecondary,
            tertiaryTextColor: theme.textTertiary
        )
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false

        for provider in providers {
            // Handle file URLs (images and PDFs)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let ext = url.pathExtension.lowercased()
                    guard Self.supportedFileExtensions.contains(ext) else { return }
                    DispatchQueue.main.async {
                        self.onFilesDropped?([url])
                    }
                }
                handled = true
            }
            // Handle raw image data (e.g. dragged from browser/preview)
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data = data else { return }
                    DispatchQueue.main.async {
                        self.onImagePasted?(data)
                    }
                }
                handled = true
            }
        }

        return handled
    }

    private var providerWarning: String? {
        guard !pendingAttachments.isEmpty else { return nil }

        let hasImages = pendingAttachments.contains { $0.fileType == .image }
        let hasPDFs = pendingAttachments.contains { $0.fileType == .pdf }

        if hasImages && !selectedModel.supportsVision {
            return "\(selectedModel.providerName) doesn't support image attachments. The model will only see your text."
        }
        if hasPDFs && !selectedModel.supportsPDF {
            return "\(selectedModel.providerName) doesn't support PDF attachments."
        }
        return nil
    }
}
