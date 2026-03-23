import SwiftUI

struct MessageInputView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var text: String
    let isStreaming: Bool
    @Binding var selectedModel: AIModel
    let models: [AIModel]
    @Binding var showModelPicker: Bool
    let pendingAttachments: [PendingAttachment]
    let queuedMessagePreviews: [String]
    let onSend: () -> Void
    let onInterrupt: () -> Void
    let onRecallLatestQueued: () -> String?
    let onAttachFile: () -> Void
    let onRemoveAttachment: (UUID) -> Void
    var onFilesDropped: (([URL]) -> Void)?
    var onImagePasted: ((Data) -> Void)?
    @State private var editorHeight: CGFloat = 22

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
    }

    @ViewBuilder
    private var sendButton: some View {
        let theme = themeManager.colors
        // Show pause icon only when streaming AND composer is empty (pure interrupt)
        let showInterrupt = isStreaming && !canSend
        let iconName = showInterrupt ? "pause.fill" : "arrow.up"
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
