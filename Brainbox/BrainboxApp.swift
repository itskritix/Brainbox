import SwiftUI
import SwiftData

@main
struct BrainboxApp: App {
    @State private var themeManager: ThemeManager
    @State private var keychainService: KeychainService
    @State private var quickChatManager: QuickChatManager

    init() {
        let tm = ThemeManager()
        let kc = KeychainService()
        _themeManager = State(initialValue: tm)
        _keychainService = State(initialValue: kc)
        _quickChatManager = State(initialValue: QuickChatManager(themeManager: tm, keychainService: kc))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(keychainService: keychainService)
                .environment(themeManager)
                .preferredColorScheme(.dark)
                .modifier(OpenWindowInjector(manager: quickChatManager))
        }
        .defaultSize(width: 1100, height: 720)
        .windowStyle(.hiddenTitleBar)
        .commands { AppCommands() }
    }
}

/// Captures the SwiftUI `openWindow` action and wires it into QuickChatManager
/// so it can reopen the main window from AppKit code.
private struct OpenWindowInjector: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    let manager: QuickChatManager

    func body(content: Content) -> some View {
        content.onAppear {
            manager.openMainWindow = { [openWindow] in
                openWindow(id: "main")
            }
        }
    }
}
