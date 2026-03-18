import SwiftUI

struct MessageInputView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var text: String
    let isDisabled: Bool
    @Binding var selectedModel: AIModel
    let models: [AIModel]
    @Binding var showModelPicker: Bool
    let pendingAttachments: [PendingAttachment]
    let onSend: () -> Void
    let onAttachFile: () -> Void
    let onRemoveAttachment: (UUID) -> Void
    var onFilesDropped: (([URL]) -> Void)?
    var onImagePasted: ((Data) -> Void)?
    @State private var editorHeight: CGFloat = 22

    var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasUploadedAttachments = !pendingAttachments.isEmpty && pendingAttachments.allSatisfy { $0.savedState.isSaved }
        return (hasText || hasUploadedAttachments) && !isDisabled
    }

    private var useGlass: Bool { themeManager.useGlassEffect }

    var body: some View {
        let theme = themeManager.colors

        VStack(spacing: 0) {
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

        if useGlass {
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(canSend ? .white : theme.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .glassEffect(
                .regular.tint(canSend ? theme.accent : theme.surfaceSecondary),
                in: .circle
            )
            .disabled(!canSend)
        } else {
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(canSend ? .white : theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(canSend ? theme.accent : theme.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
            .disabled(!canSend)
        }
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
