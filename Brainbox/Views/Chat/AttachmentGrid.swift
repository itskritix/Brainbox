import SwiftUI
import AppKit

struct AttachmentGrid: View {
    @Environment(ThemeManager.self) private var themeManager
    let attachments: [MessageAttachment]

    private var images: [MessageAttachment] { attachments.filter(\.isImage) }
    private var pdfs: [MessageAttachment] { attachments.filter(\.isPDF) }

    var body: some View {
        let theme = themeManager.colors

        VStack(alignment: .leading, spacing: 6) {
            // Image grid
            if !images.isEmpty {
                imageGrid(theme: theme)
            }

            // PDF cards
            ForEach(pdfs) { pdf in
                pdfCard(pdf, theme: theme)
            }
        }
    }

    @ViewBuilder
    private func imageGrid(theme: AppThemeColors) -> some View {
        if images.count == 1 {
            singleImage(images[0], theme: theme)
        } else {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
            ], spacing: 4) {
                ForEach(images) { img in
                    gridImage(img, theme: theme)
                }
            }
            .frame(maxWidth: 260)
        }
    }

    private func singleImage(_ attachment: MessageAttachment, theme: AppThemeColors) -> some View {
        Group {
            if let path = attachment.url, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 260, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            } else {
                imagePlaceholder(theme: theme, failed: true)
                    .frame(width: 200, height: 140)
            }
        }
    }

    private func gridImage(_ attachment: MessageAttachment, theme: AppThemeColors) -> some View {
        Group {
            if let path = attachment.url, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            } else {
                imagePlaceholder(theme: theme, failed: true)
                    .frame(width: 120, height: 120)
            }
        }
    }

    private func imagePlaceholder(theme: AppThemeColors, failed: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
            .fill(theme.backgroundTertiary)
            .overlay {
                if failed {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
    }

    private func pdfCard(_ attachment: MessageAttachment, theme: AppThemeColors) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let size = attachment.fileSize {
                    Text(formatFileSize(size))
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(theme.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        .frame(maxWidth: 280)
    }

    private func formatFileSize(_ bytes: Double) -> String {
        if bytes < 1024 { return "\(Int(bytes)) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / (1024 * 1024))
    }
}
