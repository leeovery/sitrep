import AppKit
import SitRepWindow
import SwiftUI

/// The sidebar's Filter field: the system's search field at its large size, 28 tall, its magnifier, placeholder and ×
/// its own. Typing narrows the list as each key lands; Return opens the first match; × or Escape clears it, and
/// Escape in it empty does nothing. ⌘F focuses it (`SideFocus`).
struct FilterField: NSViewRepresentable {
    let text: String

    @Environment(\.windowActions) private var act

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()

        field.placeholderString = Words.filter
        field.setAccessibilityLabel(Spoken.filter)
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.changed(_:))
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.act = act
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(act: act)
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var act: WindowActions

        init(act: WindowActions) {
            self.act = act
        }

        /// A key typed, or the × pressed.
        @objc func changed(_ field: NSSearchField) {
            act.filter(field.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                act.openFirstMatch()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                if !control.stringValue.isEmpty {
                    control.stringValue = ""
                    act.filter("")
                }
                return true
            default:
                return false
            }
        }
    }
}
