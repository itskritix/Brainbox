import AppKit
import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleQuickChat = Self("toggleQuickChat", default: .init(.space, modifiers: .option))
}

extension Notification.Name {
    static let quickChatExpandToConversation = Notification.Name("quickChatExpandToConversation")
}

@Observable
class QuickChatManager {
    private var panel: FloatingPanel?
    private let themeManager: ThemeManager
    private let keychainService: KeychainService

    /// Set by the SwiftUI layer to reopen the main WindowGroup window.
    var openMainWindow: (() -> Void)?

    private let panelWidth: CGFloat = 720
    private let collapsedHeight: CGFloat = 88

    init(themeManager: ThemeManager, keychainService: KeychainService) {
        self.themeManager = themeManager
        self.keychainService = keychainService
        KeyboardShortcuts.onKeyUp(for: .toggleQuickChat) { [weak self] in
            self?.toggle()
        }
    }

    func toggle() {
        if let panel, panel.isVisible { dismiss() } else { show() }
    }

    func show() {
        createPanel()
        panel?.showCentered(size: NSSize(width: panelWidth, height: collapsedHeight))
    }

    func dismiss() {
        guard let p = panel else { return }
        p.dismissAnimated { [weak self] in self?.panel = nil }
    }

    // MARK: - Expand to Full App

    func expandToFullApp(conversationId: String? = nil, messages: [Message] = []) {
        guard let panel else { return }

        NSApp.activate(ignoringOtherApps: true)

        let mainWindow = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain })

        let convId = conversationId
        let msgs = messages

        if let w = mainWindow, w.isMiniaturized {
            panel.dismissAnimated { [weak self] in
                self?.panel = nil
                Self.postExpandNotification(conversationId: convId, messages: msgs)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    w.deminiaturize(nil)
                    w.makeKeyAndOrderFront(nil)
                }
            }
            return
        }

        if mainWindow == nil {
            panel.dismissAnimated { [weak self] in
                self?.panel = nil
                self?.openMainWindow?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Self.postExpandNotification(conversationId: convId, messages: msgs)
                }
            }
            return
        }

        let targetFrame: NSRect
        if mainWindow!.frame.width > 100 {
            targetFrame = mainWindow!.frame
        } else {
            let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
            let vis = screen.visibleFrame
            let w: CGFloat = 1100, h: CGFloat = 720
            targetFrame = NSRect(
                x: round(vis.midX - w / 2),
                y: round(vis.midY - h / 2),
                width: w,
                height: h
            )
            mainWindow!.setFrame(targetFrame, display: false)
        }

        mainWindow!.alphaValue = 0
        mainWindow!.orderFront(nil)

        panel.morphToFrame(targetFrame, duration: 0.42) { [weak self] in
            self?.panel = nil

            guard let w = mainWindow else { return }
            w.makeKeyAndOrderFront(nil)

            Self.postExpandNotification(conversationId: convId, messages: msgs)

            DispatchQueue.main.async {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    w.animator().alphaValue = 1
                }
            }
        }
    }

    // MARK: - Private

    private static func postExpandNotification(conversationId: String?, messages: [Message] = []) {
        guard let conversationId else { return }
        NotificationCenter.default.post(
            name: .quickChatExpandToConversation,
            object: nil,
            userInfo: ["conversationId": conversationId, "messages": messages]
        )
    }

    private func createPanel() {
        panel?.orderOut(nil)
        panel = nil

        let dataService = SwiftDataService()
        let view = QuickChatView(
            dataService: dataService,
            keychainService: keychainService,
            onExpand: { [weak self] convId, msgs in self?.expandToFullApp(conversationId: convId, messages: msgs) },
            onDismiss: { [weak self] in self?.dismiss() },
            onResize: { [weak self] h in self?.panel?.animateToHeight(h) }
        )
        .environment(themeManager)
        .preferredColorScheme(.dark)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: panelWidth, height: collapsedHeight)

        let p = FloatingPanel(contentView: host)
        panel = p
    }
}
