import SwiftUI

struct QueuedMessagesPillView: View {
    let previews: [QueuedPreview]
    let accentColor: Color
    let secondaryTextColor: Color
    let tertiaryTextColor: Color
    let maxVisible: Int

    /// A stable-identity wrapper for queued message previews.
    struct QueuedPreview: Identifiable {
        let id: UUID
        let text: String
    }

    init(
        previews: [QueuedPreview],
        accentColor: Color,
        secondaryTextColor: Color,
        tertiaryTextColor: Color,
        maxVisible: Int = 2
    ) {
        self.previews = previews
        self.accentColor = accentColor
        self.secondaryTextColor = secondaryTextColor
        self.tertiaryTextColor = tertiaryTextColor
        self.maxVisible = maxVisible
    }

    var body: some View {
        let visiblePreviews = Array(previews.prefix(maxVisible))
        let hiddenCount = max(previews.count - visiblePreviews.count, 0)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(visiblePreviews) { preview in
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text(preview.text)
                        .font(.system(size: 11))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }
            }

            if hiddenCount > 0 {
                Text("+\(hiddenCount) more")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tertiaryTextColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
