import SwiftUI

// MARK: - Anchor Preference Key

/// Captures the model-selector pill's bounds so the picker panel
/// can be positioned precisely at a higher level in the view tree.
struct ModelSelectorAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

// MARK: - Provider Tooltip Preference

private struct ProviderTooltip: Equatable {
    let label: String
    let anchor: Anchor<CGPoint>
}

private struct ProviderTooltipKey: PreferenceKey {
    static var defaultValue: ProviderTooltip? = nil
    static func reduce(value: inout ProviderTooltip?, nextValue: () -> ProviderTooltip?) {
        value = nextValue() ?? value
    }
}

// MARK: - Model Selector Trigger (the small pill in the input bar)

struct ModelSelectorView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedModel: AIModel
    let models: [AIModel]
    @Binding var showPicker: Bool

    private var useGlass: Bool { themeManager.useGlassEffect }

    var body: some View {
        let theme = themeManager.colors

        Button {
            showPicker.toggle()
        } label: {
            HStack(spacing: 4) {
                ProviderIcon(
                    key: iconKey(for: selectedModel),
                    size: 10,
                    fallbackTint: theme.textSecondary
                )
                Text(selectedModel.name)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: showPicker ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .if(!useGlass) { view in
                view
                    .background(theme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
            }
        }
        .buttonStyle(.borderless)
        .if(useGlass) { $0.glassEffect(.regular, in: .capsule) }
        // Publish this button's bounds for the panel to anchor to.
        .anchorPreference(key: ModelSelectorAnchorKey.self, value: .bounds) { $0 }
    }
}

// MARK: - Full Model Picker Panel

struct ModelPickerPanel: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var selectedModel: AIModel
    let models: [AIModel]
    @Binding var isPresented: Bool
    @State private var favoriteModelIds = FavoriteModelStore.load()
    @State private var searchText = ""
    @State private var selectedSection = SidebarSection.favorites.rawValue
    @FocusState private var isSearchFocused: Bool

    static let panelWidth: CGFloat = 380
    static let panelHeight: CGFloat = 420

    private enum SidebarSection: String {
        case favorites
    }

    private var creators: [(String, String)] {
        var seen = Set<String>()
        var result: [(String, String)] = []
        for model in models {
            let creator = creatorKey(for: model)
            if seen.insert(creator).inserted {
                result.append((creator, creatorName(for: model)))
            }
        }
        return result
    }

    private var filteredModels: [AIModel] {
        var list = models

        if selectedSection == SidebarSection.favorites.rawValue {
            list = list.filter { favoriteModelIds.contains($0.id) }
        } else {
            list = list.filter { creatorKey(for: $0) == selectedSection }
        }

        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                creatorName(for: $0).localizedCaseInsensitiveContains(searchText) ||
                $0.providerName.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        let theme = themeManager.colors

        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textTertiary)
                TextField("Search models...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textPrimary)
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Rectangle()
                .fill(theme.border.opacity(0.5))
                .frame(height: 1)

            // Body: provider sidebar + model list
            HStack(spacing: 0) {
                providerSidebar

                Rectangle()
                    .fill(theme.border.opacity(0.3))
                    .frame(width: 1)

                if filteredModels.isEmpty {
                    ContentUnavailableView(
                        selectedSection == SidebarSection.favorites.rawValue
                            ? "No favorite models yet"
                            : "No models found",
                        systemImage: selectedSection == SidebarSection.favorites.rawValue
                            ? "star"
                            : "magnifyingglass",
                        description: Text(
                            selectedSection == SidebarSection.favorites.rawValue
                                ? "Star models from any provider to pin them here."
                                : "Try a different search or provider."
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredModels) { model in
                                ModelRow(
                                    model: model,
                                    isSelected: model.id == selectedModel.id,
                                    isFavorite: favoriteModelIds.contains(model.id)
                                ) {
                                    selectedModel = model
                                    isPresented = false
                                } onToggleFavorite: {
                                    toggleFavorite(model.id)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(width: Self.panelWidth, height: Self.panelHeight)
        .background(theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlayPreferenceValue(ProviderTooltipKey.self) { tooltip in
            if let tooltip {
                GeometryReader { proxy in
                    let pt = proxy[tooltip.anchor]
                    Text(tooltip.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(theme.surfaceSecondary)
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                        )
                        .fixedSize()
                        .position(x: pt.x - 56, y: pt.y)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
                .animation(.easeInOut(duration: 0.15), value: tooltip.label)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 20, y: -4)
        .onAppear {
            isSearchFocused = true
        }
    }

    private var providerSidebar: some View {
        let theme = themeManager.colors

        return ScrollView {
            VStack(spacing: 2) {
                ProviderIconButton(
                    key: nil,
                    systemIcon: "star",
                    isSelected: selectedSection == SidebarSection.favorites.rawValue,
                    theme: theme,
                    label: "Favorites"
                ) {
                    selectedSection = SidebarSection.favorites.rawValue
                }

                ForEach(creators, id: \.0) { creator, name in
                    ProviderIconButton(
                        key: creator,
                        systemIcon: nil,
                        isSelected: selectedSection == creator,
                        theme: theme,
                        label: name
                    ) {
                        selectedSection = creator
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
        .frame(width: 44)
    }

    private func toggleFavorite(_ modelId: String) {
        if favoriteModelIds.contains(modelId) {
            favoriteModelIds.remove(modelId)
        } else {
            favoriteModelIds.insert(modelId)
        }
        FavoriteModelStore.save(favoriteModelIds)
    }
}

// MARK: - Provider Icon Button

private struct ProviderIconButton: View {
    let key: String?
    let systemIcon: String?
    let isSelected: Bool
    let theme: AppThemeColors
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let fallbackTint = isSelected ? theme.accent : (isHovered ? theme.textPrimary : theme.textTertiary)

        Button(action: action) {
            Group {
                if let key {
                    ProviderIcon(
                        key: key,
                        size: 14,
                        fallbackTint: fallbackTint
                    )
                    .opacity(isSelected ? 1 : (isHovered ? 0.95 : 0.72))
                } else if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(fallbackTint)
                }
            }
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                        .fill(isSelected ? theme.accent.opacity(0.15) : (isHovered ? theme.surfaceHover : .clear))
                )
        }
        .buttonStyle(.borderless)
        .anchorPreference(key: ProviderTooltipKey.self, value: .center) { anchor in
            isHovered ? ProviderTooltip(label: label, anchor: anchor) : nil
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let model: AIModel
    let isSelected: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.colors

        HStack(spacing: 10) {
            ProviderIcon(
                key: iconKey(for: model),
                size: 13,
                fallbackTint: colorForProvider(model.provider, theme: theme)
            )
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                        .fill(colorForProvider(model.provider, theme: theme).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(model.providerName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.surfaceSecondary)
                        )
                }

                Text(model.id)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isFavorite ? .yellow : theme.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill(isSelected ? theme.accent.opacity(0.08) : (isHovered ? theme.surfaceHover : .clear))
        )
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Provider Helpers

private struct ProviderIcon: View {
    let key: String
    let size: CGFloat
    let fallbackTint: Color

    var body: some View {
        if let assetName = assetForProviderKey(key) {
            let usesTemplateRendering = key == "openai"
            let iconScale = iconScaleForKey(key)

            Image(assetName)
                .renderingMode(usesTemplateRendering ? .template : .original)
                .resizable()
                .scaledToFit()
                .foregroundStyle(usesTemplateRendering ? fallbackTint : .clear)
                .frame(width: size * iconScale, height: size * iconScale)
                .frame(width: size, height: size)
                .clipped()
        } else {
            Image(systemName: iconForProvider(key))
                .font(.system(size: size))
                .foregroundStyle(fallbackTint)
                .frame(width: size, height: size)
        }
    }
}

private func iconKey(for model: AIModel) -> String {
    if model.id.hasPrefix("openai/") {
        return "openai"
    }

    if model.id.hasPrefix("qwen/") {
        return "qwen"
    }

    if model.id.hasPrefix("meta-llama/") || model.name.localizedCaseInsensitiveContains("llama") {
        return "meta"
    }

    if model.id.hasPrefix("moonshotai/") {
        return "moonshot"
    }

    return model.provider
}

private func creatorKey(for model: AIModel) -> String {
    iconKey(for: model)
}

private func creatorName(for model: AIModel) -> String {
    switch creatorKey(for: model) {
    case "anthropic": return "Anthropic"
    case "deepseek": return "DeepSeek"
    case "google": return "Google"
    case "meta": return "Meta"
    case "mistral": return "Mistral"
    case "moonshot": return "Moonshot"
    case "openai": return "OpenAI"
    case "qwen": return "Qwen"
    case "xai": return "xAI"
    default: return model.providerName
    }
}

private func assetForProviderKey(_ key: String) -> String? {
    switch key {
    case "anthropic": return "ProviderAnthropic"
    case "deepseek": return "ProviderDeepSeek"
    case "google": return "ProviderGoogle"
    case "meta": return "ProviderMeta"
    case "mistral": return "ProviderMistral"
    case "moonshot": return "ProviderMoonshot"
    case "openai": return "ProviderOpenAI"
    case "xai": return "ProviderXAI"
    default: return nil
    }
}

private func iconScaleForKey(_ key: String) -> CGFloat {
    switch key {
    case "deepseek": return 1.8
    case "moonshot": return 1.4
    default: return 1
    }
}

func iconForProvider(_ provider: String) -> String {
    switch provider {
    case "openai": return "sparkle"
    case "anthropic": return "brain"
    case "google": return "globe"
    case "meta": return "circle.hexagongrid"
    case "mistral": return "wind"
    case "qwen": return "cpu"
    case "xai": return "bolt"
    case "deepseek": return "magnifyingglass"
    case "groq": return "hare"
    case "moonshot": return "moon"
    default: return "cpu"
    }
}

private func colorForProvider(_ provider: String, theme: AppThemeColors) -> Color {
    switch provider {
    case "openai": return .green
    case "anthropic": return Color(red: 0.85, green: 0.55, blue: 0.35)
    case "google": return .blue
    case "mistral": return .orange
    case "xai": return .purple
    case "deepseek": return .cyan
    case "groq": return .pink
    case "moonshot": return Color(red: 0.2, green: 0.2, blue: 0.2)
    default: return theme.textSecondary
    }
}

private enum FavoriteModelStore {
    private static let favoritesKey = "favoriteModelIds"
    private static let defaultFavorites = [
        "gemini-3-flash-preview",
        "gpt-4o",
    ]

    static func load() -> Set<String> {
        let defaults = UserDefaults.standard

        if let storedFavorites = defaults.array(forKey: favoritesKey) as? [String] {
            return Set(storedFavorites)
        }

        defaults.set(defaultFavorites, forKey: favoritesKey)
        return Set(defaultFavorites)
    }

    static func save(_ favoriteIds: Set<String>) {
        UserDefaults.standard.set(Array(favoriteIds), forKey: favoritesKey)
    }
}
