import SwiftUI
import AppKit

struct ConversationRow: View {
    @Environment(ThemeManager.self) private var themeManager
    let conversation: Conversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: (String) -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.colors

        Button(action: onSelect) {
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: 11)

                Image(systemName: "bubble.left")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? theme.accentLight : theme.textTertiary)
                    .frame(width: 16)
                    .padding(.trailing, 8)

                Text(conversation.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Button(action: onArchive) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.borderless)
                .help("Archive chat")
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .padding(.trailing, 8)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.borderless)
                .help("Delete chat")
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                    .fill(
                        isSelected
                            ? theme.sidebarSelected
                            : (isHovered ? theme.sidebarHover : Color.clear)
                    )
                    .overlay(
                        isSelected
                            ? RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                .fill(theme.accent.opacity(0.1))
                            : nil
                    )
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.borderless)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Rename...") {
                promptRename()
            }
            Button("Archive") {
                onArchive()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }

    private func promptRename() {
        let alert = NSAlert()
        alert.messageText = "Rename Conversation"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        input.stringValue = conversation.title
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let newTitle = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTitle.isEmpty {
                onRename(newTitle)
            }
        }
    }
}
