import SwiftUI

struct AttachmentPreviewStrip: View {
    @Environment(ThemeManager.self) private var themeManager
    let attachments: [PendingAttachment]
    let onRemove: (UUID) -> Void

    var body: some View {
        let theme = themeManager.colors

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    attachmentTile(attachment, theme: theme)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(height: 76)
        .animation(.easeInOut(duration: 0.2), value: attachments.count)
    }

    @ViewBuilder
    private func attachmentTile(_ attachment: PendingAttachment, theme: AppThemeColors) -> some View {
        ZStack(alignment: .topTrailing) {
            if attachment.fileType == .image, let thumbnail = attachment.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
            } else {
                // PDF tile
                VStack(spacing: 4) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.accent)
                    Text(attachment.fileName)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(width: 60, height: 60)
                .background(theme.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
            }

            // Upload state overlay
            savedStateOverlay(attachment, theme: theme)

            // Remove button
            Button {
                onRemove(attachment.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
            .offset(x: 4, y: -4)
        }
    }

    @ViewBuilder
    private func savedStateOverlay(_ attachment: PendingAttachment, theme: AppThemeColors) -> some View {
        switch attachment.savedState {
        case .pending:
            EmptyView()
        case .saved:
            EmptyView()
        case .failed:
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill(.black.opacity(0.4))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.warning)
                }
        }
    }
}
