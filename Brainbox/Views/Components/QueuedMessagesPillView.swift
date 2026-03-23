import SwiftUI

struct QueuedMessagesPillView: View {
    let previews: [String]
    let accentColor: Color
    let secondaryTextColor: Color
    let tertiaryTextColor: Color
    let maxVisible: Int

    init(
        previews: [String],
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
            ForEach(Array(visiblePreviews.enumerated()), id: \.offset) { _, preview in
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text(preview)
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
