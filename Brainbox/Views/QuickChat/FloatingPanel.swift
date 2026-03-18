import AppKit

/// Floating NSPanel — Spotlight-style overlay. No chrome, no traffic lights.
/// All positioning uses `screen.visibleFrame` to stay clear of the dock and menu bar.
class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }

    // MARK: - Show / Dismiss

    /// Show centered in the upper third of the *visible* screen area (dock & menu-bar safe).
    func showCentered(size: NSSize) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame

        let x = round(visible.midX - size.width / 2)
        let rawY = visible.minY + visible.height * 0.60 - size.height / 2
        let y = clamp(rawY, lo: visible.minY, hi: visible.maxY - size.height)

        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        alphaValue = 0

        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func dismissAnimated(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            completion()
        })
    }

    // MARK: - Resize

    /// Animate height change — expands **symmetrically** from center (half up, half down),
    /// clamped to the visible screen area so the panel never slides under the dock.
    func animateToHeight(_ newHeight: CGFloat) {
        guard let screen = screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let cur = frame

        // Clamp to available visible height
        let clampedHeight = min(newHeight, visible.height)
        let dy = clampedHeight - cur.height

        // Grow equally from top and bottom (center stays pinned)
        var newY = cur.origin.y - dy / 2

        // Ensure the panel stays within the visible screen bounds
        newY = clamp(newY, lo: visible.minY, hi: visible.maxY - clampedHeight)

        let target = NSRect(x: cur.origin.x, y: newY, width: cur.width, height: clampedHeight)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            self.animator().setFrame(target, display: true)
        }
    }

    // MARK: - Morph to full app

    /// Morph the panel frame toward `target` while fading out, then call `completion`.
    /// Temporarily raises window level to `.popUpMenu` so the panel stays on top during the morph.
    func morphToFrame(_ target: NSRect, duration: TimeInterval = 0.42, completion: @escaping () -> Void) {
        level = .popUpMenu // stay above everything during animation

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            self.animator().setFrame(target, display: true)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.level = .floating
            completion()
        })
    }

    // MARK: - Helpers

    private func clamp(_ v: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        max(lo, min(v, hi))
    }
}
