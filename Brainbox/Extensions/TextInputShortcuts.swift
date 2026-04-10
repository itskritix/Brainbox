import AppKit

// MARK: - NSTextView Standard Editing Shortcuts

extension NSTextView {
    /// Handles standard macOS text-editing key equivalents that the app's menu
    /// bar would otherwise intercept (Cmd+A → Edit ▸ Select All, etc.).
    ///
    /// Call this **first** inside `performKeyEquivalent(with:)`. If it returns
    /// `true`, the shortcut has been handled — return `true` from the override.
    ///
    /// Shortcuts handled:
    /// - ⌘+Delete          delete to beginning of line
    /// - ⌘+A               select all
    /// - ⌥+Delete          delete word backward
    /// - ⌥+Fn+Delete       delete word forward
    /// - ⌘+Left/Right      move to beginning / end of line
    /// - ⇧⌘+Left/Right     select to beginning / end of line
    /// - ⇧⌘+Up/Down        select to beginning / end of document
    /// - ⌥+Left/Right      move word backward / forward
    /// - ⇧⌥+Left/Right     select word backward / forward
    func handleStandardEditingKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        // Key codes
        let kDelete: UInt16 = 51   // Backspace
        let kFwdDel: UInt16 = 117  // Fn+Delete (forward delete)
        let kLeft:   UInt16 = 123
        let kRight:  UInt16 = 124
        let kDown:   UInt16 = 125
        let kUp:     UInt16 = 126

        switch (flags, keyCode) {

        // ── Command + Delete ────────────────────────────────────────────
        case (.command, kDelete):
            deleteToBeginningOfLine(nil)
            return true

        // ── Command + A ─────────────────────────────────────────────────
        case (.command, _) where event.charactersIgnoringModifiers == "a":
            selectAll(nil)
            return true

        // ── Option + Delete  (word backward) ────────────────────────────
        case (.option, kDelete):
            deleteWordBackward(nil)
            return true

        // ── Option + Forward Delete  (word forward) ─────────────────────
        case (.option, kFwdDel):
            deleteWordForward(nil)
            return true

        // ── Cmd + Left / Right  (line start / end) ──────────────────────
        case (.command, kLeft):
            moveToBeginningOfLine(nil)
            return true
        case (.command, kRight):
            moveToEndOfLine(nil)
            return true

        // ── Shift+Cmd + Left / Right  (select to line start / end) ──────
        case ([.command, .shift], kLeft):
            moveToBeginningOfLineAndModifySelection(nil)
            return true
        case ([.command, .shift], kRight):
            moveToEndOfLineAndModifySelection(nil)
            return true

        // ── Shift+Cmd + Up / Down  (select to document start / end) ─────
        case ([.command, .shift], kUp):
            moveToBeginningOfDocumentAndModifySelection(nil)
            return true
        case ([.command, .shift], kDown):
            moveToEndOfDocumentAndModifySelection(nil)
            return true

        // ── Option + Left / Right  (word navigation) ────────────────────
        case (.option, kLeft):
            moveWordBackward(nil)
            return true
        case (.option, kRight):
            moveWordForward(nil)
            return true

        // ── Shift+Option + Left / Right  (word selection) ───────────────
        case ([.option, .shift], kLeft):
            moveWordBackwardAndModifySelection(nil)
            return true
        case ([.option, .shift], kRight):
            moveWordForwardAndModifySelection(nil)
            return true

        default:
            return false
        }
    }
}

// MARK: - NSTextField / NSSearchField Helper

extension NSControl {
    /// Forwards standard editing key equivalents to the active field editor.
    /// Use this in NSTextField / NSSearchField subclasses that override
    /// `performKeyEquivalent(with:)`.
    ///
    /// Returns `true` if the shortcut was handled.
    func handleFieldEditorEditingKeyEquivalent(with event: NSEvent) -> Bool {
        guard let editor = currentEditor() as? NSTextView else { return false }
        return editor.handleStandardEditingKeyEquivalent(with: event)
    }
}
