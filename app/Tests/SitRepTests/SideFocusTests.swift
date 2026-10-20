import AppKit
@testable import SitRep
import SwiftUI
import Testing

/// Return on the sidebar's list moves keyboard focus into the page, to its first control, and Escape in the page moves
/// it back to the list, in the SitRep window's split over a list and two buttons, made, never shown. A page's buttons
/// take focus only while the Mac's Keyboard navigation setting is on, so what needs them runs only then.
@MainActor
struct SideFocusTests {
    @Test(.enabled { await keyboardNavigation() })
    func returnOnTheListMovesFocusToThePagesFirstControl() throws {
        let sides = try Sides()

        #expect(sides.press(SideFocus.return))
        #expect(sides.focused != nil)
        #expect(sides.focused === sides.firstControl)
    }

    @Test(.enabled { await keyboardNavigation() })
    func enterDoesAsReturnDoes() throws {
        let sides = try Sides()

        #expect(sides.press(SideFocus.enter))
        #expect(sides.focused === sides.firstControl)
    }

    @Test func escapeInThePageMovesFocusBackToTheList() throws {
        let sides = try Sides()

        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.list)
    }

    @Test func escapeOnTheListAndReturnInThePageAreLeftAlone() throws {
        let sides = try Sides()

        #expect(!sides.press(SideFocus.escape))
        sides.window.makeFirstResponder(sides.focus.page)
        #expect(!sides.press(SideFocus.return))
    }

    @Test func returnPassesOnWhereNothingInThePageTakesFocus() throws {
        let sides = try Sides(hasButtons: false)

        #expect(!sides.press(SideFocus.return))
        #expect(sides.focused == nil)
    }

    @Test func returnWithAModifierIsLeftAlone() throws {
        let sides = try Sides()

        #expect(!sides.press(SideFocus.return, with: .command))
        #expect(sides.window.firstResponder === sides.list)
    }
}

/// The Mac's Keyboard navigation setting, by which a page's buttons take focus.
private func keyboardNavigation() async -> Bool {
    await MainActor.run { NSApplication.shared.isFullKeyboardAccessEnabled }
}

/// The window's split over a list and two buttons, its focus on the list.
@MainActor
private struct Sides {
    let window: NSWindow
    let focus: SideFocus
    let list: NSTableView

    /// A page of buttons, or of words alone, as a page is with Keyboard navigation off: nothing in it takes focus.
    init(hasButtons: Bool = true) throws {
        let sidebar = NSHostingController(rootView: List(selection: .constant(Optional("a"))) {
            Text("a").tag("a")
        }.listStyle(.sidebar))
        let page = NSHostingController(rootView: VStack {
            if hasButtons {
                Button("One") {}
                Button("Two") {}
            } else {
                Text("One")
            }
        })

        sidebar.sizingOptions = []
        page.sizingOptions = []
        window = SitRepWindow.window(SitRepWindow.split(sidebar: sidebar, page: page))
        window.contentView?.layoutSubtreeIfNeeded()
        focus = SideFocus(window: window, sidebar: sidebar.view, page: page.view)
        list = try #require(Self.table(in: sidebar.view))
        window.makeFirstResponder(list)
    }

    /// The view in the page with keyboard focus.
    var focused: NSView? {
        (window.firstResponder as? NSView).flatMap { $0.isDescendant(of: focus.page) ? $0 : nil }
    }

    /// The topmost of the page's key views, the one AppKit hosts for its first button.
    var firstControl: NSView? {
        focus.page.subviews.filter(\.canBecomeKeyView).max {
            focus.page.convert($0.frame, to: nil).maxY < focus.page.convert($1.frame, to: nil).maxY
        }
    }

    @discardableResult
    func press(_ key: UInt16, with modifiers: NSEvent.ModifierFlags = []) -> Bool {
        let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
            context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: key
        )

        return event.map(focus.move) ?? false
    }

    private static func table(in view: NSView) -> NSTableView? {
        view.subviews.lazy.compactMap { $0 as? NSTableView ?? table(in: $0) }.first
    }
}
