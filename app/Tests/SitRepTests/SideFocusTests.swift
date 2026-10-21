import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// ⌘F moves keyboard focus into the Filter field; Return on the sidebar's list moves it into the page, to its first
/// control, and Escape in the page moves it back to the list holding the pick, in the SitRep window's split over the
/// sidebar as the window draws it, the board's list with Settings' at its foot, and two buttons, made, never shown. A page's buttons take focus only while the Mac's Keyboard navigation setting is
/// on, so what needs them runs only then.
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

    /// As where the window first opened before SwiftUI had made the list's table, and focus fell to the sidebar.
    @Test(.enabled { await keyboardNavigation() })
    func returnFromTheSidebarOutsideTheListMovesFocusToThePage() throws {
        let sides = try Sides(focusingList: false)

        try #require(sides.window.makeFirstResponder(sides.focus.sidebar))
        #expect(sides.press(SideFocus.return))
        #expect(sides.focused === sides.firstControl)
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

    @Test func commandFFocusesTheFilterFieldFromTheListOrThePage() throws {
        let sides = try Sides()

        #expect(!sides.isInField)
        #expect(sides.press(Sides.f, with: .command, typing: "f"))
        #expect(sides.isInField)
        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(Sides.f, with: .command, typing: "f"))
        #expect(sides.isInField)
    }

    @Test func commandFFocusesTheFieldWithCapsLockOn() throws {
        let sides = try Sides()

        #expect(sides.press(Sides.f, with: [.command, .capsLock], typing: "F"))
        #expect(sides.isInField)
    }

    @Test func fWithoutCommandIsLeftAlone() throws {
        let sides = try Sides()

        #expect(!sides.press(Sides.f, typing: "f"))
        #expect(sides.window.firstResponder === sides.list)
    }

    /// The field's Return, which opens the first match, and its Escape, which clears it, are its own: the window takes
    /// neither, and focus stays in the field.
    @Test func returnAndEscapeInTheFilterFieldAreTheFields() throws {
        let sides = try Sides()

        sides.press(Sides.f, with: .command, typing: "f")
        #expect(!sides.take(SideFocus.return))
        #expect(!sides.take(SideFocus.escape))
        #expect(sides.isInField)
    }

    /// An answer waiting is taken back by Escape before the field hears it, as anywhere in the window.
    @Test func escapeInTheFilterFieldTakesBackAnAnswerWaitingFirst() throws {
        let sides = try Sides()
        var asked: [UInt16] = []
        let take = { (key: UInt16, waiting: Bool) in
            sides.take(key) {
                asked.append(key)
                return waiting
            }
        }

        sides.press(Sides.f, with: .command, typing: "f")
        let undone = take(SideFocus.escape, true)
        let leftToTheField = take(SideFocus.escape, false)
        let returned = take(SideFocus.return, true)

        #expect(undone)
        #expect(!leftToTheField)
        #expect(!returned)
        #expect(asked == [SideFocus.escape, SideFocus.escape])
        #expect(sides.isInField)
    }

    @Test func escapeOnTheListTakesBackAnAnswerWaitingAndElseIsLeftAlone() throws {
        let sides = try Sides()

        #expect(sides.take(SideFocus.escape) { true })
        #expect(!sides.take(SideFocus.escape) { false })
        #expect(sides.window.firstResponder === sides.list)
    }

    /// Where AppKit would give the window's first focus to the field, the first of its key views.
    @Test func openingAfreshPutsFocusOnTheList() throws {
        let sides = try Sides(focusingList: false)

        #expect(sides.window.firstResponder !== sides.list)
        sides.focus.focusList()
        #expect(sides.window.firstResponder === sides.list)
    }

    /// The foot's list sits inside the board's, in its bar: it is found, and holds the pick while Settings shows.
    @Test func escapeInThePageMovesFocusToSettingsAtTheFootWhileItShows() throws {
        let sides = try Sides(pick: .settings)

        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.foot)
    }

    @Test func openingAfreshOnSettingsPutsFocusOnTheFoot() throws {
        let sides = try Sides(pick: .settings, focusingList: false)

        sides.focus.focusList()
        #expect(sides.window.firstResponder === sides.foot)
    }

    @Test func withNothingPickedFocusGoesToTheBoardsList() throws {
        let sides = try Sides(pick: nil, focusingList: false)

        #expect(sides.board.selectedRow < 0 && sides.foot.selectedRow < 0)
        sides.focus.focusList()
        #expect(sides.window.firstResponder === sides.board)
        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.board)
    }
}

/// The Mac's Keyboard navigation setting, by which a page's buttons take focus.
private func keyboardNavigation() async -> Bool {
    await MainActor.run { NSApplication.shared.isFullKeyboardAccessEnabled }
}

/// The window's split over the sidebar, on the board `watch` first printed with this picked, and two buttons, its
/// focus on the list holding the pick.
@MainActor
private struct Sides {
    let window: NSWindow
    let focus: SideFocus
    /// The board's list, and Settings' at its foot.
    let board: NSTableView
    let foot: NSTableView

    /// The list holding the pick.
    var list: NSTableView { foot.selectedRow >= 0 ? foot : board }

    /// A page of buttons, or of words alone, as a page is with Keyboard navigation off: nothing in it takes focus.
    init(pick: Pick? = .session("sr-macapp"), hasButtons: Bool = true, focusingList: Bool = true) throws {
        let sidebar = NSHostingController(rootView: BoardColumn(
            listed: Self.listed, pick: pick, sidebar: .projects, filter: Filter(), now: Date()
        ))
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

        let tables = Self.tables(in: sidebar.view)

        board = try #require(tables.first { $0.numberOfRows > 1 })
        foot = try #require(tables.first { $0.numberOfRows == 1 })
        if focusingList {
            window.makeFirstResponder(foot.selectedRow >= 0 ? foot : board)
        }
    }

    /// The board's list as the real `watch` first printed it.
    private static let listed = {
        var last = LastBoard()
        let run = WindowRun()

        last.begin()
        _ = last.hear(.line(Lines.watch[0]), at: Date())
        _ = run.show(last, at: Date(), reducesMotion: false)
        return run.listed(at: Date())
    }()

    /// Keyboard focus is in the Filter field, its field editor inside it.
    var isInField: Bool {
        guard let focus = window.firstResponder as? NSView, let field = Self.field(in: focus.window?.contentView) else {
            return false
        }
        return focus.isDescendant(of: field)
    }

    /// A key, as the window's monitor hands it over, an answer waiting where `undo` says so.
    func take(_ key: UInt16, undo: () -> Bool = { false }) -> Bool {
        Self.event(key, in: window).map { focus.take($0, undo: undo) } ?? false
    }

    private static func field(in view: NSView?) -> NSSearchField? {
        view?.subviews.lazy.compactMap { $0 as? NSSearchField ?? field(in: $0) }.first
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
    func press(_ key: UInt16, with modifiers: NSEvent.ModifierFlags = [], typing characters: String = "\r") -> Bool {
        Self.event(key, with: modifiers, typing: characters, in: window).map(focus.move) ?? false
    }

    private static func event(
        _ key: UInt16, with modifiers: NSEvent.ModifierFlags = [], typing characters: String = "\r", in window: NSWindow
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: window.windowNumber,
            context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false,
            keyCode: key
        )
    }

    /// The F key.
    static let f: UInt16 = 3

    private static func tables(in view: NSView) -> [NSTableView] {
        view.subviews.flatMap { ($0 as? NSTableView).map { [$0] } ?? tables(in: $0) }
    }
}
