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
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .frame(height: 86)
        .animation(.easeInOut(duration: 0.2), value: attachments.count)
    }

    @ViewBuilder
    private func attachmentTile(_ attachment: PendingAttachment, theme: AppThemeColors) -> some View {
        tileContent(attachment, theme: theme)
            .overlay(alignment: .topTrailing) {
                savedStateOverlay(attachment, theme: theme)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    onRemove(attachment.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
            .frame(width: 60, height: 60)
    }

    @ViewBuilder
    private func tileContent(_ attachment: PendingAttachment, theme: AppThemeColors) -> some View {
        if attachment.fileType == .image, let thumbnail = attachment.thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        } else {
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
                .overlay {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.warning)
                }
        }
    }
}
