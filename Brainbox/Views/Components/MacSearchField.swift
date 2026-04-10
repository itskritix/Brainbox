import SwiftUI
import AppKit

struct MacSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont
    var textColor: NSColor
    var placeholderColor: NSColor
    var isFocused: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NativeSearchField()
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.sendsSearchStringImmediately = true
        field.maximumRecents = 0
        field.recentsAutosaveName = nil
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.stringValue = text
        context.coordinator.apply(self, to: field)
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(self, to: nsView)

        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        if isFocused, nsView.window?.firstResponder !== nsView.currentEditor() {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: MacSearchField

        init(_ parent: MacSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func apply(_ parent: MacSearchField, to field: NSSearchField) {
            field.placeholderString = parent.placeholder
            field.font = parent.font
            field.textColor = parent.textColor

            let placeholderAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: parent.placeholderColor,
                .font: parent.font,
            ]
            if let cell = field.cell as? NSSearchFieldCell {
                cell.searchButtonCell = nil
                cell.placeholderAttributedString = NSAttributedString(
                    string: parent.placeholder,
                    attributes: placeholderAttributes
                )
            }
        }
    }
}

private final class NativeSearchField: NSSearchField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags == .command && event.keyCode == 51 {
            currentEditor()?.deleteToBeginningOfLine(nil)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
