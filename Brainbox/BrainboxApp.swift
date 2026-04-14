import SwiftUI
import SwiftData

@main
struct BrainboxApp: App {
    @State private var themeManager: ThemeManager
    @State private var keychainService: KeychainService
    @State private var localModelService: LocalModelService
    @State private var quickChatManager: QuickChatManager
    @State private var showOnboarding: Bool

    init() {
        let tm = ThemeManager()
        let kc = KeychainService()
        let lms = LocalModelService()
        _themeManager = State(initialValue: tm)
        _keychainService = State(initialValue: kc)
        _localModelService = State(initialValue: lms)
        _quickChatManager = State(initialValue: QuickChatManager(themeManager: tm, keychainService: kc, localModelService: lms))
        _showOnboarding = State(initialValue: !UserDefaults.standard.bool(forKey: UDKey.hasCompletedOnboarding))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ZStack {
                ContentView(keychainService: keychainService, localModelService: localModelService)
                    .environment(themeManager)
                    .environment(localModelService)
                    .modifier(OpenWindowInjector(manager: quickChatManager))

                if showOnboarding {
                    OnboardingView(keychainService: keychainService) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showOnboarding = false
                        }
                    }
                    .environment(themeManager)
                    .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
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
