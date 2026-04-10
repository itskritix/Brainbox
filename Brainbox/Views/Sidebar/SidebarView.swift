import SwiftUI

struct SidebarView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var viewModel: ConversationListViewModel
    var profileVM: ProfileViewModel
    @Binding var selectedConversationId: String?
    @Binding var isSidebarVisible: Bool
    let searchFocusTrigger: Bool
    let keychainService: KeychainService
    var streamingConversationIds: Set<String> = []
    var onCancelBackgroundStream: ((String) -> Void)?
    @State private var searchText = ""
    @State private var showThemePicker = false
    @State private var showProfileEditor = false
    @State private var showCreateProfile = false
    @State private var profileScrollTarget: String = "all-chats"
    @FocusState private var isSearchFocused: Bool
    @State private var yesterdayLimit = 10
    @State private var last7DaysLimit = 10
    @State private var olderLimit = 10
    @State private var scrollAreaHeight: CGFloat = 0
    @State private var hasSetInitialLimits = false
    private let pageSize = 10

    private var profileSelectionOrder: [Profile?] {
        [nil] + profileVM.profiles.map { Optional($0) }
    }

    private var activeProfileIndex: Int {
        profileSelectionOrder.firstIndex { candidate in
            candidate?.id == profileVM.activeProfile?.id
        } ?? 0
    }

    private var canMoveToPreviousProfile: Bool {
        activeProfileIndex > 0
    }

    private var canMoveToNextProfile: Bool {
        activeProfileIndex < profileSelectionOrder.count - 1
    }

    private var shouldShowProfileChevrons: Bool {
        profileSelectionOrder.count > 3
    }

    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return viewModel.conversations
        }
        return viewModel.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private struct GroupedConversations {
        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var last7Days: [Conversation] = []
        var older: [Conversation] = []
    }

    private var grouped: GroupedConversations {
        let calendar = Calendar.current
        let now = Date()
        var result = GroupedConversations()

        for conversation in filteredConversations {
            let date = Date(timeIntervalSince1970: conversation.updatedAt / 1000)
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0

            if calendar.isDateInToday(date) {
                result.today.append(conversation)
            } else if calendar.isDateInYesterday(date) {
                result.yesterday.append(conversation)
            } else if days < 7 {
                result.last7Days.append(conversation)
            } else {
                result.older.append(conversation)
            }
        }
        return result
    }

    private var useGlass: Bool { themeManager.useGlassEffect }

    var body: some View {
        let theme = themeManager.colors

        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarVisible = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)

            HStack(spacing: 8) {
                Text("Brainbox")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Button {
                    showThemePicker.toggle()
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showThemePicker, arrowEdge: .bottom) {
                    ThemePickerView()
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 4)

            Button {
                selectedConversationId = nil
            } label: {
                Text("New Chat")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.accentLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
                MacSearchField(
                    text: $searchText,
                    placeholder: "Search your threads...",
                    font: .systemFont(ofSize: 12),
                    textColor: NSColor(theme.textPrimary),
                    placeholderColor: NSColor(theme.textTertiary),
                    isFocused: isSearchFocused
                )
                .frame(height: 18)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(useGlass ? Color.white.opacity(0.06) : theme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if filteredConversations.isEmpty {
                Spacer(minLength: 0)
            } else {
                GeometryReader { geo in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            let data = grouped

                            // Today — show all
                            if !data.today.isEmpty {
                                sectionHeader("Today", theme: theme)
                                ForEach(data.today) { conversation in
                                    conversationRow(conversation, theme: theme)
                                }
                            }

                            // Yesterday — paginated
                            if !data.yesterday.isEmpty {
                                sectionHeader("Yesterday", theme: theme)
                                ForEach(data.yesterday.prefix(yesterdayLimit)) { conversation in
                                    conversationRow(conversation, theme: theme)
                                }
                            }

                            // Last 7 Days — paginated
                            if !data.last7Days.isEmpty {
                                sectionHeader("Last 7 Days", theme: theme)
                                ForEach(data.last7Days.prefix(last7DaysLimit)) { conversation in
                                    conversationRow(conversation, theme: theme)
                                }
                            }

                            // Older — paginated
                            if !data.older.isEmpty && olderLimit > 0 {
                                sectionHeader("Older", theme: theme)
                                ForEach(data.older.prefix(olderLimit)) { conversation in
                                    conversationRow(conversation, theme: theme)
                                }
                            }

                            let totalRemaining = max(0, data.yesterday.count - yesterdayLimit)
                                + max(0, data.last7Days.count - last7DaysLimit)
                                + max(0, data.older.count - olderLimit)

                            Spacer(minLength: 0)

                            if totalRemaining > 0 {
                                showMoreButton(remaining: totalRemaining, theme: theme) {
                                    if data.yesterday.count > yesterdayLimit {
                                        yesterdayLimit += pageSize
                                    }
                                    if data.last7Days.count > last7DaysLimit {
                                        last7DaysLimit += pageSize
                                    }
                                    if data.older.count > olderLimit {
                                        olderLimit += pageSize
                                    }
                                }
                                .padding(.bottom, 12)
                            }
                        }
                        .frame(minHeight: geo.size.height)
                    }
                    .onAppear {
                        scrollAreaHeight = geo.size.height
                        calculateInitialLimits()
                    }
                    .onChange(of: geo.size.height) { _, newHeight in
                        scrollAreaHeight = newHeight
                    }
                    .onChange(of: viewModel.conversations.count) {
                        calculateInitialLimits()
                    }
                }
            }

            Rectangle()
                .fill(theme.border)
                .frame(height: 1)

            ZStack {
                HStack(spacing: 0) {
                    Button {
                        showProfileEditor = true
                    } label: {
                        Circle()
                            .fill(theme.accent.opacity(0.3))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Text(String((UserDefaults.standard.string(forKey: UDKey.userName) ?? "U").prefix(1)).uppercased())
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.accentLight)
                            )
                            .overlay(
                                Circle()
                                    .stroke(theme.accent.opacity(0.5), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                    .frame(width: 34, height: 34)

                    Spacer(minLength: 0)

                    Button {
                        showCreateProfile = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.textTertiary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .help("New Profile")
                    .frame(width: 34, height: 34)
                }

                HStack(spacing: shouldShowProfileChevrons ? 6 : 0) {
                    if shouldShowProfileChevrons {
                        Button {
                            moveToPreviousProfile()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(canMoveToPreviousProfile ? theme.textSecondary : theme.textTertiary.opacity(0.4))
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canMoveToPreviousProfile)
                        .help("Previous Profile")
                        .frame(width: 20, height: 34)
                    }

                    if shouldShowProfileChevrons {
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                profileIconsRow(theme: theme)
                                    .padding(.leading, 6)
                                    .padding(.trailing, 4)
                                    .frame(height: 34)
                            }
                            .frame(height: 34)
                            .onAppear {
                                profileScrollTarget = profileVM.activeProfile?.id ?? "all-chats"
                                proxy.scrollTo(profileScrollTarget, anchor: .center)
                            }
                            .onChange(of: profileVM.activeProfileId) {
                                profileScrollTarget = profileVM.activeProfile?.id ?? "all-chats"
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(profileScrollTarget, anchor: .center)
                                }
                            }
                            .onChange(of: profileVM.profiles.count) {
                                profileScrollTarget = profileVM.activeProfile?.id ?? "all-chats"
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(profileScrollTarget, anchor: .center)
                                }
                            }
                        }
                    } else {
                        profileIconsRow(theme: theme)
                            .frame(height: 34)
                    }

                    if shouldShowProfileChevrons {
                        Button {
                            moveToNextProfile()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(canMoveToNextProfile ? theme.textSecondary : theme.textTertiary.opacity(0.4))
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canMoveToNextProfile)
                        .help("Next Profile")
                        .frame(width: 20, height: 34)
                    }
                }
                .frame(height: 34)
                .padding(.horizontal, 52)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .if(useGlass) {
            $0.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        }
        .if(!useGlass) { $0.background(theme.sidebarBackground) }
        .padding(.top, 6)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .onAppear {
            viewModel.refresh()
        }
        .onChange(of: searchText) {
            hasSetInitialLimits = false
            yesterdayLimit = pageSize
            last7DaysLimit = pageSize
            olderLimit = pageSize
            calculateInitialLimits()
        }
        .sheet(isPresented: $showProfileEditor) {
            SettingsView(
                keychainService: keychainService,
                profileVM: profileVM,
                conversationListVM: viewModel,
                selectedTab: .general
            )
        }
        .sheet(isPresented: $showCreateProfile) {
            CreateProfileView { name, emoji in
                return profileVM.createProfile(name: name, emoji: emoji)
            }
        }
        .onChange(of: searchFocusTrigger) {
            isSearchFocused = true
        }
    }

    private func sectionHeader(_ title: String, theme: AppThemeColors) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.accent)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func conversationRow(_ conversation: Conversation, theme: AppThemeColors) -> some View {
        ConversationRow(
            conversation: conversation,
            isSelected: selectedConversationId == conversation.id,
            isStreaming: streamingConversationIds.contains(conversation.id),
            onSelect: {
                selectedConversationId = conversation.id
            },
            onRename: { newTitle in
                viewModel.renameConversation(id: conversation.id, title: newTitle)
            },
            onArchive: {
                onCancelBackgroundStream?(conversation.id)
                if selectedConversationId == conversation.id {
                    selectedConversationId = nil
                }
                viewModel.archiveConversation(id: conversation.id)
            },
            onDelete: {
                onCancelBackgroundStream?(conversation.id)
                if selectedConversationId == conversation.id {
                    selectedConversationId = nil
                }
                viewModel.deleteConversation(id: conversation.id)
            }
        )
    }

    private func showMoreButton(remaining: Int, theme: AppThemeColors, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Show more (\(remaining))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderless)
    }

    private func calculateInitialLimits() {
        guard !hasSetInitialLimits, scrollAreaHeight > 0 else { return }
        let data = grouped
        let total = data.today.count + data.yesterday.count + data.last7Days.count + data.older.count
        guard total > 0 else { return }
        hasSetInitialLimits = true

        let rowHeight: CGFloat = 30
        let headerHeight: CGFloat = 30
        let showMoreHeight: CGFloat = 36
        let sectionCount = CGFloat(
            [!data.today.isEmpty, !data.yesterday.isEmpty, !data.last7Days.isEmpty, !data.older.isEmpty]
                .filter { $0 }.count
        )
        let availableForRows = scrollAreaHeight - (sectionCount * headerHeight) - showMoreHeight
        let maxRows = max(5, Int(availableForRows / rowHeight))
        let afterToday = max(0, maxRows - data.today.count)

        yesterdayLimit = min(data.yesterday.count, afterToday)
        let afterYesterday = max(0, afterToday - yesterdayLimit)
        last7DaysLimit = min(data.last7Days.count, afterYesterday)
        let afterLast7Days = max(0, afterYesterday - last7DaysLimit)
        olderLimit = min(data.older.count, afterLast7Days)
    }

    private func profileIconsRow(theme: AppThemeColors) -> some View {
        HStack(spacing: 12) {
            let isAllChatsActive = profileVM.activeProfile == nil
            Button {
                profileVM.setActiveProfile(nil)
                selectedConversationId = nil
            } label: {
                Image(systemName: isAllChatsActive ? "tray.full.fill" : "tray.full")
                    .font(.system(size: 18))
                    .foregroundStyle(isAllChatsActive ? theme.accentLight : theme.textTertiary)
                    .frame(width: 24, height: 34)
            }
            .buttonStyle(.plain)
            .help("All Chats")
            .id("all-chats")

            ForEach(profileVM.profiles) { profile in
                let isActive = profileVM.activeProfile?.id == profile.id

                Button {
                    if isActive {
                        profileVM.setActiveProfile(nil)
                    } else {
                        profileVM.setActiveProfile(profile)
                    }
                    selectedConversationId = nil
                } label: {
                    Image(systemName: isActive ? profile.emoji : outlineVariant(of: profile.emoji))
                        .font(.system(size: 18))
                        .foregroundStyle(isActive ? theme.accentLight : theme.textTertiary)
                        .frame(width: 24, height: 34)
                }
                .buttonStyle(.plain)
                .help(profile.name)
                .id(profile.id)
                .contextMenu {
                    Button(role: .destructive) {
                        profileVM.deleteProfile(id: profile.id)
                    } label: {
                        Label("Delete \(profile.name)", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func moveToPreviousProfile() {
        guard canMoveToPreviousProfile else { return }
        let nextIndex = activeProfileIndex - 1
        profileVM.setActiveProfile(profileSelectionOrder[nextIndex])
        selectedConversationId = nil
    }

    private func moveToNextProfile() {
        guard canMoveToNextProfile else { return }
        let nextIndex = activeProfileIndex + 1
        profileVM.setActiveProfile(profileSelectionOrder[nextIndex])
        selectedConversationId = nil
    }

}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
