import SwiftUI

// MARK: - Profile Switcher (bottom bar popover content)

struct ProfileSwitcherView: View {
    @Environment(ThemeManager.self) private var themeManager
    let profiles: [Profile]
    let activeProfile: Profile?
    let onSelect: (Profile?) -> Void
    let onDelete: (String) -> Void
    @Binding var showCreateProfile: Bool

    var body: some View {
        let theme = themeManager.colors

        VStack(alignment: .leading, spacing: 4) {
            // "All Chats" option (no profile filter)
            Button {
                onSelect(nil)
            } label: {
                HStack(spacing: 8) {
                    Text("*")
                        .font(.system(size: 14))
                        .frame(width: 24, height: 24)

                    Text("All Chats")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    if activeProfile == nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(activeProfile == nil ? theme.accent.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
            }
            .buttonStyle(.borderless)

            if !profiles.isEmpty {
                Divider()
                    .overlay(theme.border)

                ForEach(profiles) { profile in
                    profileRow(profile, theme: theme)
                }
            }

            Divider()
                .overlay(theme.border)

            // Add Profile button
            Button {
                showCreateProfile = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accent)

                    Text("New Profile")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .frame(width: 200)
    }

    private func profileRow(_ profile: Profile, theme: AppThemeColors) -> some View {
        let isActive = activeProfile?.id == profile.id

        return Button {
            onSelect(profile)
        } label: {
            HStack(spacing: 8) {
                Text(profile.emoji)
                    .font(.system(size: 14))
                    .frame(width: 24, height: 24)

                Text(profile.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isActive ? theme.accent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        }
        .buttonStyle(.borderless)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(profile.id)
            } label: {
                Label("Delete Profile", systemImage: "trash")
            }
        }
    }
}

// MARK: - Create Profile Sheet

struct CreateProfileView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, String) async -> String?

    @State private var profileName = ""
    @State private var selectedEmoji = "briefcase.fill"
    @State private var isCreating = false
    @FocusState private var isNameFocused: Bool

    private let emojiOptions = [
        "briefcase.fill", "book.fill", "house.fill", "graduationcap.fill",
        "gamecontroller.fill", "heart.fill", "star.fill", "bolt.fill",
        "leaf.fill", "paintbrush.fill", "bubble.left.fill", "bookmark.fill",
    ]

    var body: some View {
        let theme = themeManager.colors

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create a Profile")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Profiles have separate threads and settings")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }

                // Icon + Name
                HStack(spacing: 12) {
                    // Selected icon preview
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: selectedEmoji)
                            .font(.system(size: 16))
                            .foregroundStyle(theme.accentLight)
                    }

                    TextField("Profile name", text: $profileName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                .stroke(theme.accent.opacity(0.5), lineWidth: 1)
                        )
                        .focused($isNameFocused)
                        .onSubmit { createProfile() }
                }

                // Icon grid
                Text("Choose an icon")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(emojiOptions, id: \.self) { icon in
                        Button {
                            selectedEmoji = icon
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(selectedEmoji == icon ? theme.accent.opacity(0.3) : theme.surfacePrimary)
                                    .frame(width: 32, height: 32)
                                Image(systemName: icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(selectedEmoji == icon ? theme.accentLight : theme.textSecondary)
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }

                // Create button
                let canCreate = !profileName.trimmingCharacters(in: .whitespaces).isEmpty && !isCreating

                Button {
                    createProfile()
                } label: {
                    Group {
                        if isCreating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Create Profile")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .foregroundStyle(canCreate ? .white : theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canCreate ? theme.accent : theme.accent.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
            .padding(.top, 12)
            .padding(20)

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
        .frame(width: 300)
        .background(theme.sidebarBackground)
        .onAppear { isNameFocused = true }
    }

    private func createProfile() {
        let name = profileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !isCreating else { return }
        isCreating = true
        Task {
            if let _ = await onCreate(name, selectedEmoji) {
                dismiss()
            }
            isCreating = false
        }
    }
}
