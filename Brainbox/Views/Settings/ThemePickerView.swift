import SwiftUI

struct ThemePickerView: View {
    @Environment(ThemeManager.self) private var themeManager

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        let theme = themeManager.colors

        VStack(alignment: .leading, spacing: 16) {
            Text("Theme")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ThemePreset.allCases) { preset in
                    ThemeCard(
                        preset: preset,
                        isSelected: themeManager.selectedPreset == preset,
                        onSelect: { themeManager.selectedPreset = preset }
                    )
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(theme.backgroundSecondary)
    }
}

struct ThemeCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let preset: ThemePreset
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.colors

        Button(action: onSelect) {
            VStack(spacing: 6) {
                // Color preview bar
                HStack(spacing: 0) {
                    ForEach(Array(preset.previewColors.enumerated()), id: \.offset) { _, color in
                        Rectangle().fill(color)
                    }
                }
                .frame(height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? theme.accent : (isHovered ? theme.border : Color.clear),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                Text(preset.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
            }
        }
        .buttonStyle(.borderless)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
