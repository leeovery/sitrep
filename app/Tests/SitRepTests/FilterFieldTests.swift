import AppKit
@testable import SitRep
import Testing

/// The Filter field's own keys, as AppKit's field editor hands them to it: Return opens the first match; Escape clears
/// the field and gives the whole board back, and in the field empty is swallowed, leaving things as they are.
@MainActor
struct FilterFieldTests {
    /// What the field asked the window for.
    @MainActor
    private final class Asked {
        var filters: [String] = []
        var opens = 0
    }

    private let asked = Asked()
    private let field = NSSearchField()
    private let editor = NSTextView()

    private var coordinator: FilterField.Coordinator {
        let asked = asked

        return FilterField.Coordinator(act: WindowActions(
            filter: { asked.filters.append($0) },
            openFirstMatch: { asked.opens += 1 }
        ))
    }

    private func command(_ selector: Selector, typed: String) -> Bool {
        field.stringValue = typed
        return coordinator.control(field, textView: editor, doCommandBy: selector)
    }

    @Test func returnOpensTheFirstMatch() {
        #expect(command(#selector(NSResponder.insertNewline(_:)), typed: "ledg"))
        #expect(asked.opens == 1)
        #expect(asked.filters.isEmpty)
    }

    @Test func escapeClearsTheField() {
        #expect(command(#selector(NSResponder.cancelOperation(_:)), typed: "ledg"))
        #expect(field.stringValue.isEmpty)
        #expect(asked.filters == [""])
    }

    @Test func escapeInTheFieldEmptyIsSwallowedAndDoesNothing() {
        #expect(command(#selector(NSResponder.cancelOperation(_:)), typed: ""))
        #expect(asked.filters.isEmpty)
        #expect(asked.opens == 0)
    }

    @Test func everyOtherKeyIsTheEditorsOwn() {
        #expect(!command(#selector(NSResponder.moveLeft(_:)), typed: "ledg"))
        #expect(asked.filters.isEmpty)
    }

    @Test func aKeyTypedOrTheClearButtonSendsWhatTheFieldHolds() {
        field.stringValue = "led"
        coordinator.changed(field)
        #expect(asked.filters == ["led"])
    }
}
