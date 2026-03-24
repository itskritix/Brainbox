import SwiftUI
import AppKit

/// A custom NSTextView wrapper that supports all standard macOS text editing
/// shortcuts (⌘+Delete, ⌥+Delete, ⌃+K, etc.) which SwiftUI's TextEditor can
/// swallow or lose to menu-command interception.
struct ChatTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var textColor: NSColor = .white
    var font: NSFont = .systemFont(ofSize: 14)
    var placeholderText: String = "Message..."
    var placeholderColor: NSColor = .tertiaryLabelColor
    var minHeight: CGFloat = 22
    var maxHeight: CGFloat = 120
    var onSubmit: (() -> Void)?
    var canSubmit: Bool = true
    var onRecallLatestQueued: (() -> String?)?
    var onFilesDropped: (([URL]) -> Void)?
    var onImagePasted: ((Data) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = InputTextView()
        textView.delegate = context.coordinator
        textView.inputCoordinator = context.coordinator

        // Text configuration
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true

        // Layout
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = .zero

        // Disable smart substitutions that interfere with code/chat
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.textView = textView

        // Listen for focus-input notification (⌘+L)
        context.coordinator.focusObserver = NotificationCenter.default.addObserver(
            forName: .appFocusInput,
            object: nil,
            queue: .main
        ) { [weak textView] _ in
            textView?.window?.makeFirstResponder(textView)
        }

        // Initial height
        DispatchQueue.main.async {
            context.coordinator.recalcHeight()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InputTextView else { return }

        context.coordinator.parent = self
        context.coordinator.onFilesDropped = onFilesDropped
        context.coordinator.onImagePasted = onImagePasted

        // Sync text from SwiftUI → NSTextView (avoid feedback loop)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            textView.needsDisplay = true
            context.coordinator.recalcHeight()
        }

        textView.font = font
        textView.textColor = textColor
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatTextEditor
        weak var textView: InputTextView?
        var focusObserver: Any?
        var onFilesDropped: (([URL]) -> Void)?
        var onImagePasted: ((Data) -> Void)?

        init(_ parent: ChatTextEditor) {
            self.parent = parent
            self.onFilesDropped = parent.onFilesDropped
            self.onImagePasted = parent.onImagePasted
        }

        deinit {
            if let observer = focusObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            recalcHeight()
        }

        func recalcHeight() {
            guard let textView = textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)
            let contentHeight = layoutManager.usedRect(for: textContainer).height
            let clamped = min(max(contentHeight + 2, parent.minHeight), parent.maxHeight)

            if abs(parent.height - clamped) > 0.5 {
                DispatchQueue.main.async {
                    self.parent.height = clamped
                }
            }
        }
    }
}

// MARK: - Custom NSTextView

/// Subclass that intercepts ⌘+Delete (delete-to-beginning-of-line) before the
/// menu bar can claim the shortcut, and routes Return → submit.
final class InputTextView: NSTextView {
    weak var inputCoordinator: ChatTextEditor.Coordinator?

    private static let supportedFileExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "pdf"
    ]

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    // MARK: - Drag and Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL] {
            let hasValid = urls.contains { Self.supportedFileExtensions.contains($0.pathExtension.lowercased()) }
            if hasValid { return .copy }
        }
        if pb.data(forType: .tiff) != nil || pb.data(forType: .png) != nil {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard

        // Check for file URLs
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL] {
            let validURLs = urls.filter { Self.supportedFileExtensions.contains($0.pathExtension.lowercased()) }
            if !validURLs.isEmpty {
                inputCoordinator?.onFilesDropped?(validURLs)
                return true
            }
        }

        // Check for raw image data
        if let imageData = pb.data(forType: .tiff) ?? pb.data(forType: .png) {
            inputCoordinator?.onImagePasted?(imageData)
            return true
        }

        return super.performDragOperation(sender)
    }

    // MARK: - Paste (intercept image paste)

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general

        // Check for file URLs first
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL] {
            let validURLs = urls.filter { Self.supportedFileExtensions.contains($0.pathExtension.lowercased()) }
            if !validURLs.isEmpty {
                inputCoordinator?.onFilesDropped?(validURLs)
                return
            }
        }

        // Check for image data (e.g. screenshot paste)
        if let imageData = pb.data(forType: .tiff) ?? pb.data(forType: .png) {
            // Only intercept if there's no string data (prefer text paste)
            if pb.string(forType: .string) == nil {
                inputCoordinator?.onImagePasted?(imageData)
                return
            }
        }

        // Fall through to normal text paste
        super.paste(sender)
    }

    // MARK: Key equivalents (runs before menu commands)

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘+Delete — delete to beginning of line
        if flags == .command && event.keyCode == 51 {
            deleteToBeginningOfLine(nil)
            return true
        }

        // ⌘+A — make sure select-all always works inside the text view
        if flags == .command, event.charactersIgnoringModifiers == "a" {
            selectAll(nil)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: Regular key handling

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Return (no modifiers) → submit
        if event.keyCode == 36 && flags.isEmpty {
            if inputCoordinator?.parent.canSubmit == true {
                inputCoordinator?.parent.onSubmit?()
            }
            return // swallow — don't insert newline
        }

        // Up Arrow on empty composer → restore the most recent queued prompt
        if event.keyCode == 126 && flags.isEmpty && string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if recallLatestQueuedMessage() {
                return
            }
        }

        // Shift+Return → insert newline (fall through to super)
        super.keyDown(with: event)
    }

    override func doCommand(by selector: Selector) {
        if selector == #selector(moveUp(_:)), recallLatestQueuedMessage() {
            return
        }

        super.doCommand(by: selector)
    }

    // MARK: Placeholder drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, let coordinator = inputCoordinator else { return }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: coordinator.parent.font,
            .foregroundColor: coordinator.parent.placeholderColor,
        ]
        let placeholder = NSAttributedString(
            string: coordinator.parent.placeholderText,
            attributes: attrs
        )
        let inset = textContainerInset
        let padding = textContainer?.lineFragmentPadding ?? 0
        placeholder.draw(at: NSPoint(x: inset.width + padding, y: inset.height))
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }

    @discardableResult
    private func recallLatestQueuedMessage() -> Bool {
        guard string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let recalledText = inputCoordinator?.parent.onRecallLatestQueued?(),
              !recalledText.isEmpty else {
            return false
        }

        string = recalledText
        setSelectedRange(NSRange(location: (recalledText as NSString).length, length: 0))
        inputCoordinator?.parent.text = recalledText
        inputCoordinator?.recalcHeight()
        needsDisplay = true
        return true
    }
}
