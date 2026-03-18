import SwiftUI

struct EmptyStateView: View {
    @Environment(ThemeManager.self) private var themeManager
    let userName: String?
    var keychainService: KeychainService?
    let onSuggestionTapped: (String) -> Void
    let onNewChat: () -> Void

    @State private var selectedCategoryIndex: Int? = nil
    @State private var defaultSuggestions: [SuggestionPrompt] = AppTheme.randomSuggestions()

    private var activeSuggestions: [SuggestionPrompt] {
        if let index = selectedCategoryIndex {
            return AppTheme.categories[index].suggestions
        }
        return defaultSuggestions
    }

    var body: some View {
        let theme = themeManager.colors

        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                // API keys banner
                if let kc = keychainService, kc.configuredProviders.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.warning)
                        Text("Set up API keys in Settings to start chatting")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(theme.warning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                }

                // Greeting
                Text(greeting)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                // Category pills
                HStack(spacing: 10) {
                    ForEach(Array(AppTheme.categories.enumerated()), id: \.element.id) { index, category in
                        CategoryPillButton(
                            category: category,
                            isSelected: selectedCategoryIndex == index
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedCategoryIndex == index {
                                    selectedCategoryIndex = nil
                                } else {
                                    selectedCategoryIndex = index
                                }
                            }
                        }
                    }
                }

                // Suggestion prompts
                VStack(spacing: 0) {
                    ForEach(Array(activeSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                        SuggestionRow(suggestion: suggestion) {
                            onSuggestionTapped(suggestion.text)
                        }

                        if index < activeSuggestions.count - 1 {
                            Rectangle()
                                .fill(theme.border.opacity(0.2))
                                .frame(height: 0.5)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.2), value: selectedCategoryIndex)
            }
            .frame(maxWidth: 520, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var greeting: String {
        if let name = userName, !name.isEmpty {
            return "How can I help you, \(name)?"
        }
        return "How can I help you?"
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let suggestion: SuggestionPrompt
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.colors

        Button(action: onTap) {
            HStack {
                Text(suggestion.text)
                    .font(.system(size: 15))
                    .foregroundStyle(isHovered ? theme.textPrimary : theme.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                    .fill(isHovered ? theme.textPrimary.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.borderless)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Category Pill Button

struct CategoryPillButton: View {
    @Environment(ThemeManager.self) private var themeManager
    let category: CategoryPill
    var isSelected: Bool = false
    var onTap: () -> Void = {}
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.colors
        let useGlass = themeManager.useGlassEffect

        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                Text(category.label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? theme.accent : (isHovered ? theme.textPrimary : theme.textSecondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .buttonStyle(.borderless)
        .if(useGlass) { $0.glassEffect(.regular, in: .capsule) }
        .if(!useGlass) { view in
            view
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                        .stroke(isSelected ? theme.accent : (isHovered ? theme.textTertiary : theme.border), lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                        .fill(isSelected ? theme.accent.opacity(0.1) : .clear)
                )
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
