import SwiftUI

// MARK: - App Command Notifications

extension Notification.Name {
    static let appNewChat = Notification.Name("appNewChat")
    static let appToggleSidebar = Notification.Name("appToggleSidebar")
    static let appOpenSettings = Notification.Name("appOpenSettings")
    static let appFocusInput = Notification.Name("appFocusInput")
    static let appToggleModelPicker = Notification.Name("appToggleModelPicker")
    static let appCopyLastResponse = Notification.Name("appCopyLastResponse")
    static let appDeleteConversation = Notification.Name("appDeleteConversation")
    static let appSelectPreviousConversation = Notification.Name("appSelectPreviousConversation")
    static let appSelectNextConversation = Notification.Name("appSelectNextConversation")
    static let appFocusSearch = Notification.Name("appFocusSearch")
    static let appShowShortcuts = Notification.Name("appShowShortcuts")
}

// MARK: - App Commands

struct AppCommands: Commands {
    var body: some Commands {
        // File menu: New Chat (Cmd+N)
        CommandGroup(replacing: .newItem) {
            Button("New Chat") {
                NotificationCenter.default.post(name: .appNewChat, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // View menu: Sidebar & Search
        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") {
                NotificationCenter.default.post(name: .appToggleSidebar, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Search Conversations") {
                NotificationCenter.default.post(name: .appFocusSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        // Chat menu
        CommandMenu("Chat") {
            Button("Focus Message Input") {
                NotificationCenter.default.post(name: .appFocusInput, object: nil)
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("Switch Model") {
                NotificationCenter.default.post(name: .appToggleModelPicker, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("Copy Last Response") {
                NotificationCenter.default.post(name: .appCopyLastResponse, object: nil)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Divider()

            Button("Previous Conversation") {
                NotificationCenter.default.post(name: .appSelectPreviousConversation, object: nil)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])

            Button("Next Conversation") {
                NotificationCenter.default.post(name: .appSelectNextConversation, object: nil)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])

            Divider()

            Button("Delete Conversation") {
                NotificationCenter.default.post(name: .appDeleteConversation, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }

        // Help menu: Keyboard Shortcuts (Cmd+/)
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") {
                NotificationCenter.default.post(name: .appShowShortcuts, object: nil)
            }
            .keyboardShortcut("/", modifiers: .command)
        }

        // App menu: Settings (Cmd+,)
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                NotificationCenter.default.post(name: .appOpenSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
