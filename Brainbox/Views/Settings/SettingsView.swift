import SwiftUI
import KeyboardShortcuts

enum SettingsTab: String, CaseIterable {
    case general
    case apiKeys
    case profiles
    case shortcuts
}

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    let keychainService: KeychainService
    var profileVM: ProfileViewModel
    @State var selectedTab: SettingsTab

    var body: some View {
        let theme = themeManager.colors

        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                // Sidebar
                settingsSidebar(theme: theme)

                // Divider
                Rectangle()
                    .fill(theme.border)
                    .frame(width: 1)

                // Content
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsContent(dismiss: dismiss)
                    case .apiKeys:
                        APIKeysSettingsContent(keychainService: keychainService)
                    case .profiles:
                        ProfilesSettingsContent(profileVM: profileVM)
                    case .shortcuts:
                        ShortcutsSettingsContent()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(theme.surfacePrimary)
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
        .frame(width: 660, height: 460)
        .background(theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    private func settingsSidebar(theme: AppThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 8)

            sidebarItem(icon: "gearshape", label: "General", tab: .general, theme: theme)
            sidebarItem(icon: "key", label: "API Keys", tab: .apiKeys, theme: theme)
            sidebarItem(icon: "person.2", label: "Profiles", tab: .profiles, theme: theme)
            sidebarItem(icon: "keyboard", label: "Shortcuts", tab: .shortcuts, theme: theme)

            Spacer()
        }
        .frame(width: 160)
        .background(theme.backgroundPrimary.opacity(0.5))
    }

    private func sidebarItem(
        icon: String,
        label: String,
        tab: SettingsTab,
        theme: AppThemeColors
    ) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accentLight : theme.textTertiary)
                    .frame(width: 18)

                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? theme.sidebarSelected : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 8)
    }
}

// MARK: - General Settings

private struct GeneralSettingsContent: View {
    @Environment(ThemeManager.self) private var themeManager
    let dismiss: DismissAction

    @State private var draftName = ""
    @State private var isHoveringSave = false

    private var displayName: String {
        UserDefaults.standard.string(forKey: UDKey.userName) ?? ""
    }

    private var initials: String {
        String((displayName.isEmpty ? "U" : displayName).prefix(1)).uppercased()
    }

    private var canSave: Bool {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 60 && trimmed != current
    }

    var body: some View {
        let theme = themeManager.colors

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("General")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                // Profile section
                settingsGroup(theme: theme) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(theme.accent.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(initials)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.accentLight)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName.isEmpty ? "User" : displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)

                            Text("Local user")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textTertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    settingsDivider(theme: theme)

                    // Display name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Text("How your name appears in conversations")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)

                        HStack(spacing: 8) {
                            TextField("Your name", text: $draftName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textPrimary)
                                .padding(8)
                                .background(theme.surfacePrimary)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                            if canSave {
                                Button {
                                    let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    UserDefaults.standard.set(trimmed, forKey: UDKey.userName)
                                } label: {
                                    Text("Save")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(isHoveringSave ? theme.accentLight : theme.accent)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.borderless)
                                .onHover { h in isHoveringSave = h }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.easeOut(duration: 0.2), value: canSave)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                // Quick Chat section
                settingsGroup(theme: theme) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Chat Shortcut")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                            Text("Global shortcut to open the quick chat overlay")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textTertiary)
                        }

                        Spacer()

                        KeyboardShortcuts.Recorder(for: .toggleQuickChat)
                            .environment(\.colorScheme, .dark)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .padding(24)
        }
        .onAppear {
            draftName = displayName
        }
    }
}

// MARK: - API Keys Settings

private struct APIKeysSettingsContent: View {
    @Environment(ThemeManager.self) private var themeManager
    var keychainService: KeychainService

    @State private var keys: [String: String] = [:]
    @State private var savedMessage: String?

    var body: some View {
        let theme = themeManager.colors
        let _ = keychainService.revision

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Keys")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    Text("Enter API keys for the providers you want to use. Keys are stored securely in your Mac's Keychain.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.trailing, 36)

                if let msg = savedMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .transition(.opacity)
                }

                settingsGroup(theme: theme) {
                    ForEach(Array(KeychainService.providers.enumerated()), id: \.element) { index, provider in
                        apiKeyRow(provider: provider, theme: theme)

                        if index < KeychainService.providers.count - 1 {
                            settingsDivider(theme: theme)
                        }
                    }
                }
            }
            .padding(24)
            .animation(.easeInOut(duration: 0.2), value: keychainService.revision)
        }
        .onAppear {
            loadKeys()
        }
    }

    private func loadKeys() {
        for provider in KeychainService.providers {
            if keys[provider] == nil || keys[provider]?.isEmpty == true {
                keys[provider] = keychainService.apiKey(for: provider) ?? ""
            }
        }
    }

    private func showSaved(_ provider: String) {
        let name = KeychainService.providerDisplayName(provider)
        withAnimation { savedMessage = "\(name) API key saved" }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { savedMessage = nil }
        }
    }

    private func apiKeyRow(provider: String, theme: AppThemeColors) -> some View {
        let displayName = KeychainService.providerDisplayName(provider)
        let hasKey = keychainService.hasKey(for: provider)
        let binding = Binding<String>(
            get: { keys[provider] ?? "" },
            set: { keys[provider] = $0 }
        )

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    if hasKey {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }

                if let url = KeychainService.providerKeyURL(provider) {
                    Link("Get API key", destination: url)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                }
            }
            .frame(width: 100, alignment: .leading)

            SecureField("API Key", text: binding)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .padding(6)
                .background(theme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            Button {
                let key = (keys[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if key.isEmpty {
                    keychainService.deleteAPIKey(for: provider)
                } else {
                    keychainService.setAPIKey(key, for: provider)
                    showSaved(provider)
                }
            } label: {
                Text("Save")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)

            if hasKey {
                Button {
                    keychainService.deleteAPIKey(for: provider)
                    keys[provider] = ""
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.error)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Profiles Settings

private struct ProfilesSettingsContent: View {
    @Environment(ThemeManager.self) private var themeManager
    var profileVM: ProfileViewModel

    @State private var showCreateProfile = false

    var body: some View {
        let theme = themeManager.colors

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profiles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.textPrimary)

                        Text("Switch chat context and manage all your profiles")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(.trailing, 36)

                settingsGroup(theme: theme) {
                    allChatsRow(theme: theme)

                    if !profileVM.profiles.isEmpty {
                        settingsDivider(theme: theme)
                    }

                    ForEach(Array(profileVM.profiles.enumerated()), id: \.element.id) { index, profile in
                        profileRow(profile, theme: theme)

                        if index != profileVM.profiles.count - 1 {
                            settingsDivider(theme: theme)
                        }
                    }

                    settingsDivider(theme: theme)

                    newProfileRow(theme: theme)
                }

                if let error = profileVM.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.error)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showCreateProfile) {
            CreateProfileView { name, emoji in
                return profileVM.createProfile(name: name, emoji: emoji)
            }
        }
    }

    private func allChatsRow(theme: AppThemeColors) -> some View {
        let isActive = profileVM.activeProfile == nil

        return Button {
            profileVM.setActiveProfile(nil)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(isActive ? theme.accent.opacity(0.2) : theme.surfacePrimary)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: isActive ? "tray.full.fill" : "tray.full")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isActive ? theme.accentLight : theme.textSecondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("All Chats")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("No profile filter")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private func profileRow(_ profile: Profile, theme: AppThemeColors) -> some View {
        let isActive = profileVM.activeProfile?.id == profile.id

        return HStack(spacing: 10) {
            Circle()
                .fill(isActive ? theme.accent.opacity(0.2) : theme.surfacePrimary)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: isActive ? profile.emoji : outlineVariant(of: profile.emoji))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isActive ? theme.accentLight : theme.textSecondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(isActive ? "Currently Active" : "Tap to activate")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.accent)
            }

            Button {
                profileVM.setActiveProfile(profile)
            } label: {
                Text(isActive ? "Active" : "Use")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? theme.textTertiary : theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isActive ? theme.surfacePrimary : theme.accent.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
            .disabled(isActive)

            Button(role: .destructive) {
                profileVM.deleteProfile(id: profile.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.error)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Delete \(profile.name)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func newProfileRow(theme: AppThemeColors) -> some View {
        Button {
            showCreateProfile = true
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(theme.accent.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("New Profile")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Create a separate chat context")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

}

// MARK: - Shortcuts Settings

private struct ShortcutsSettingsContent: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.colors

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Shortcuts")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        shortcutSection("General", shortcuts: [
                            ShortcutEntry(label: "New Chat", keys: ["⌘", "N"]),
                            ShortcutEntry(label: "Toggle Sidebar", keys: ["⌘", "S"]),
                            ShortcutEntry(label: "Settings", keys: ["⌘", ","]),
                            ShortcutEntry(label: "Search Conversations", keys: ["⌘", "⇧", "F"]),
                            ShortcutEntry(label: "Keyboard Shortcuts", keys: ["⌘", "/"]),
                        ], theme: theme)

                        shortcutSection("Navigation", shortcuts: [
                            ShortcutEntry(label: "Previous Conversation", keys: ["⌘", "⌥", "↑"]),
                            ShortcutEntry(label: "Next Conversation", keys: ["⌘", "⌥", "↓"]),
                            ShortcutEntry(label: "Delete Conversation", keys: ["⌘", "⇧", "⌫"]),
                        ], theme: theme)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 20) {
                        shortcutSection("Chat", shortcuts: [
                            ShortcutEntry(label: "Focus Message Input", keys: ["⌘", "L"]),
                            ShortcutEntry(label: "Switch Model", keys: ["⌘", "K"]),
                            ShortcutEntry(label: "Copy Last Response", keys: ["⌘", "⇧", "C"]),
                            ShortcutEntry(label: "Send Message", keys: ["↩"]),
                            ShortcutEntry(label: "New Line", keys: ["⇧", "↩"]),
                        ], theme: theme)

                        shortcutSection("Quick Chat", shortcuts: [
                            ShortcutEntry(label: "Toggle Quick Chat", keys: ["⌥", "Space"]),
                            ShortcutEntry(label: "Dismiss", keys: ["Esc"]),
                        ], theme: theme)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
    }

    private func shortcutSection(
        _ title: String,
        shortcuts: [ShortcutEntry],
        theme: AppThemeColors
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.bottom, 2)

            VStack(spacing: 2) {
                ForEach(shortcuts) { shortcut in
                    shortcutRow(shortcut, theme: theme)
                }
            }
        }
    }

    private func shortcutRow(_ item: ShortcutEntry, theme: AppThemeColors) -> some View {
        HStack {
            Text(item.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Spacer()

            HStack(spacing: 3) {
                ForEach(item.keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, key.count > 1 ? 6 : 5)
                        .padding(.vertical, 3)
                        .background(theme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.border, lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Shared Helpers

private func settingsGroup<Content: View>(
    theme: AppThemeColors,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(spacing: 0) {
        content()
    }
    .background(theme.surfacePrimary.opacity(0.4))
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    .overlay(
        RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
            .stroke(theme.border.opacity(0.5), lineWidth: 0.5)
    )
}

private func settingsDivider(theme: AppThemeColors) -> some View {
    Rectangle()
        .fill(theme.border.opacity(0.5))
        .frame(height: 0.5)
        .padding(.horizontal, 14)
}

private struct ShortcutEntry: Identifiable {
    let id = UUID()
    let label: String
    let keys: [String]
}
