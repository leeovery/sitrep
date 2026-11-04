import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// ⌘F moves keyboard focus into the Filter field; Return moves it a region to the right, from the sidebar's list into
/// the list beside the page and from there into the page, to its first control; Escape a region to the left, from the
/// page to the list and from the list to the sidebar's; with the list folded away, as the page fills the window, each
/// passes it by. In the SitRep window's split over the sidebar and the list as the window draws them, and two buttons,
/// made, never shown. A page's buttons take focus only while the Mac's Keyboard navigation setting is on, so what
/// needs them runs only then.
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

    @Test func returnOnTheSidebarsListMovesFocusToTheList() throws {
        let sides = try Sides()

        sides.window.makeFirstResponder(sides.places)
        #expect(sides.press(SideFocus.return))
        #expect(sides.window.firstResponder === sides.board)
    }

    /// As where the window first opened before SwiftUI had made the sidebar's table, and focus fell to the sidebar.
    @Test func returnFromTheSidebarOutsideItsListMovesFocusToTheList() throws {
        let sides = try Sides(focusingList: false)

        try #require(sides.window.makeFirstResponder(sides.focus.sidebar))
        #expect(sides.press(SideFocus.return))
        #expect(sides.window.firstResponder === sides.board)
    }

    @Test(.enabled { await keyboardNavigation() })
    func withTheListFoldedReturnOnTheSidebarMovesFocusToThePage() throws {
        let sides = try Sides()

        sides.foldTheList()
        sides.window.makeFirstResponder(sides.places)
        #expect(sides.press(SideFocus.return))
        #expect(sides.focused === sides.firstControl)
    }

    @Test func escapeInThePageMovesFocusBackToTheList() throws {
        let sides = try Sides()

        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.board)
    }

    @Test func escapeOnTheListMovesFocusToTheSidebarsList() throws {
        let sides = try Sides()

        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.places)
    }

    @Test func withTheListFoldedEscapeInThePageMovesFocusToTheSidebarsList() throws {
        let sides = try Sides()

        sides.foldTheList()
        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.places)
    }

    /// The list folds away, as the page fills the window, by the window alone: Lee can neither drag it nor narrow it
    /// away.
    @Test func theListFoldsAwayAndBack() throws {
        let sides = try Sides()
        let list = sides.split.splitViewItems[1]

        sides.foldTheList()
        #expect(list.isCollapsed)
        #expect(sides.focus.list.isHiddenOrHasHiddenAncestor)
        SitRepWindow.fold(list, isFullPage: false)
        sides.window.contentView?.layoutSubtreeIfNeeded()
        #expect(!list.isCollapsed)
        #expect(!sides.focus.list.isHiddenOrHasHiddenAncestor)
    }

    @Test func escapeOnTheSidebarAndReturnInThePageAreLeftAlone() throws {
        let sides = try Sides()

        sides.window.makeFirstResponder(sides.places)
        #expect(!sides.press(SideFocus.escape))
        sides.window.makeFirstResponder(sides.focus.page)
        #expect(!sides.press(SideFocus.return))
    }

    /// With nothing in the page to take focus, AppKit's key loop wraps round to the Filter field, whose Return would
    /// open its first match over the row Lee picked: Return is taken, and focus stays on the list, never passing
    /// through the field on the way, which VoiceOver would announce.
    @Test func returnWhereNothingInThePageTakesFocusLeavesFocusOnTheListAndOpensNothing() throws {
        let sides = try Sides(hasButtons: false, filter: "le")
        var responders: [NSResponder] = []

        // the key loop as a window on screen has it, through the field
        sides.window.recalculateKeyViewLoop()

        let watching = sides.window.observe(\.firstResponder, options: [.new]) { window, _ in
            MainActor.assumeIsolated { window.firstResponder.map { responders.append($0) } }
        }

        #expect(sides.pressThrough(SideFocus.return))
        watching.invalidate()
        #expect(sides.window.firstResponder === sides.board)
        #expect(responders.isEmpty)
        #expect(!sides.isInField)
        #expect(sides.asked.matches == 0)
    }

    /// The other side of it: Return in the field, as AppKit hands it on, opens the first match.
    @Test func returnInTheFilterFieldOpensTheFirstMatch() throws {
        let sides = try Sides(filter: "le")

        sides.press(Sides.f, with: .command, typing: "f")
        #expect(!sides.pressThrough(SideFocus.return))
        #expect(sides.asked.matches == 1)
    }

    @Test func returnWithAModifierIsLeftAlone() throws {
        let sides = try Sides()

        #expect(!sides.press(SideFocus.return, with: .command))
        #expect(sides.window.firstResponder === sides.board)
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
        #expect(sides.window.firstResponder === sides.board)
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

    /// Escape on the list takes back an answer waiting, focus staying; with none, it moves focus to the sidebar.
    @Test func escapeOnTheListTakesBackAnAnswerWaitingBeforeMovingFocus() throws {
        let sides = try Sides()

        #expect(sides.take(SideFocus.escape) { true })
        #expect(sides.window.firstResponder === sides.board)
        #expect(sides.take(SideFocus.escape) { false })
        #expect(sides.window.firstResponder === sides.places)
    }

    /// Where AppKit would give the window's first focus to the field, the first of its key views.
    @Test func openingAfreshPutsFocusOnTheList() throws {
        let sides = try Sides(focusingList: false)

        #expect(sides.window.firstResponder !== sides.board)
        sides.focus.focusList()
        #expect(sides.window.firstResponder === sides.board)
    }

    @Test func openingAfreshWithTheListFoldedPutsFocusOnTheSidebarsList() throws {
        let sides = try Sides(focusingList: false)

        sides.foldTheList()
        sides.focus.focusList()
        #expect(sides.window.firstResponder === sides.places)
    }

    /// The list holding focus folds away, as a project's name pressed on the page fills the window: focus goes to the
    /// sidebar's list.
    @Test func theListFoldingAwayUnderFocusGivesItToTheSidebarsList() throws {
        let sides = try Sides()

        #expect(sides.focus.isOnTheList)
        sides.foldTheList()
        sides.focus.keepOffTheList()
        #expect(sides.window.firstResponder === sides.places)
    }

    /// The list holding focus empties to its one centred line, its table gone: focus goes to the sidebar's list.
    @Test func theListEmptyingUnderFocusGivesItToTheSidebarsList() throws {
        let sides = try Sides()

        #expect(sides.focus.isOnTheList)
        sides.emptyTheList()
        sides.focus.keepOffTheList()
        #expect(sides.window.firstResponder === sides.places)
    }

    /// The list changing under focus while its table stays leaves focus where it is.
    @Test func theListChangingUnderFocusKeepsIt() throws {
        let sides = try Sides()

        sides.focus.keepOffTheList()
        #expect(sides.window.firstResponder === sides.board)
    }

    /// Tab from the list leaves it for the page's first control, in the key loop as a window on screen has it.
    @Test(.enabled { await keyboardNavigation() })
    func tabFromTheListGoesToThePagesFirstControl() throws {
        let sides = try Sides()

        sides.window.recalculateKeyViewLoop()
        sides.send(Sides.tab, typing: "\t")
        #expect(sides.focused === sides.firstControl)
    }

    /// With nothing in the page to take focus, Tab from the list wraps round to the Filter field, and Shift-Tab comes
    /// back.
    @Test func tabFromTheListWithNothingInThePageWrapsToTheFilterField() throws {
        let sides = try Sides(hasButtons: false)

        sides.window.recalculateKeyViewLoop()
        sides.send(Sides.tab, typing: "\t")
        #expect(sides.isInField)
        sides.send(Sides.tab, with: .shift, typing: "\u{19}")
        #expect(sides.window.firstResponder === sides.board)
    }

    /// Before the sidebar's first row, ↑ goes nowhere: the sidebar keeps focus, going nowhere.
    @Test func upFromTheSidebarsFirstRowStaysOnIt() throws {
        let sides = try Sides()

        try #require(sides.places.selectedRow == 0)
        sides.window.makeFirstResponder(sides.places)
        sides.send(arrow: Sides.upArrow)
        #expect(sides.window.firstResponder === sides.places)
        #expect(sides.asked.clicks.isEmpty)
    }

    @Test func withNothingPickedFocusGoesToTheList() throws {
        let sides = try Sides(isPicked: false, focusingList: false)

        #expect(sides.board.selectedRow < 0)
        sides.focus.focusList()
        #expect(sides.window.firstResponder === sides.board)
        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.board)
    }
}

/// The Mac's Keyboard navigation setting, by which buttons take focus.
func keyboardNavigation() async -> Bool {
    await MainActor.run { NSApplication.shared.isFullKeyboardAccessEnabled }
}

/// The window's split over the sidebar and the list, on the board `watch` first printed, the window open on Needs you,
/// and two buttons, its focus on the list holding the pick.
@MainActor
private struct Sides {
    let window: NSWindow
    let split: NSSplitViewController
    let focus: SideFocus
    /// The list beside the page.
    let board: NSTableView
    /// The sidebar's list.
    let places: NSTableView
    /// What the sidebar and the list asked the window for.
    let asked: Asked
    private let listed: NSHostingController<AnyView>
    /// The list as it draws with nothing in it: its one line.
    private let emptied: AnyView

    /// A page of buttons, or of words alone, as a page is with Keyboard navigation off: nothing in it takes focus.
    init(
        isPicked: Bool = true, hasButtons: Bool = true, focusingList: Bool = true, filter: String = ""
    ) throws {
        let run = HostedSidebar.opened()
        let now = HostedSidebar.printed
        let filter = Filter(filter)
        let asked = Asked()
        let list = try #require(run.list(at: now))
        let picked = isPicked ? run.location.picked?.pick : nil
        let sidebar = Self.hosted(SidebarColumn(places: run.places, root: run.location.root, filter: filter), asked)
        let note = Self.hosted(ListNote(words: run.head.title), asked)
        let listed = Self.hosted(ListColumn(list: list, picked: picked, head: run.head, filter: filter, now: now), asked)
        let page = NSHostingController(rootView: AnyView(VStack {
            if hasButtons {
                Button("One") {}
                Button("Two") {}
            } else {
                Text("One")
            }
        }))

        page.sizingOptions = []
        split = SitRepWindow.split(sidebar: sidebar, list: listed, page: page)
        window = SitRepWindow.window(split, toolbar: NSToolbar())
        window.contentView?.layoutSubtreeIfNeeded()
        focus = SideFocus(window: window, sidebar: sidebar.view, list: listed.view, page: page.view)
        self.asked = asked
        self.listed = listed
        emptied = note.rootView

        board = try #require(Self.views(NSTableView.self, in: listed.view).first)
        places = try #require(Self.views(NSTableView.self, in: sidebar.view).first)
        if focusingList {
            window.makeFirstResponder(board)
        }
    }

    /// A column as the window draws it, what it asks for heard.
    private static func hosted(_ column: some View, _ asked: Asked) -> NSHostingController<AnyView> {
        let hosting = NSHostingController(rootView: AnyView(column.environment(\.windowActions, WindowActions(
            click: { [asked] in asked.clicks.append($0) }, openFirstMatch: { [asked] in asked.matches += 1 }
        ))))

        hosting.sizingOptions = []
        return hosting
    }

    /// The list emptied to its one line, as its last row leaves it.
    func emptyTheList() {
        listed.rootView = emptied
        window.contentView?.layoutSubtreeIfNeeded()
    }

    /// The list folded away, as the page fills the window.
    func foldTheList() {
        SitRepWindow.fold(split.splitViewItems[1], isFullPage: true)
        window.contentView?.layoutSubtreeIfNeeded()
    }

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

    /// A key as the window hears it: the monitor's, and where it takes none, what has focus, as AppKit hands it on.
    /// Whether the monitor took it.
    func pressThrough(
        _ key: UInt16, with modifiers: NSEvent.ModifierFlags = [], typing characters: String = "\r"
    ) -> Bool {
        guard let event = Self.event(key, with: modifiers, typing: characters, in: window) else {
            return false
        }
        if focus.take(event, undo: { false }) {
            return true
        }
        window.firstResponder?.keyDown(with: event)
        return false
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

    /// A key as the window sends it to what has focus, past its monitor, which tests the keys above.
    func send(_ key: UInt16, with modifiers: NSEvent.ModifierFlags = [], typing characters: String) {
        Self.event(key, with: modifiers, typing: characters, in: window).map(window.sendEvent)
    }

    /// ↓ or ↑, as the keyboard sends it, with the numeric pad and function flags.
    func send(arrow key: UInt16) {
        send(key, with: [.numericPad, .function], typing: key == Self.downArrow ? "\u{F701}" : "\u{F700}")
    }

    /// The F key, Tab and the arrows.
    nonisolated static let f: UInt16 = 3
    nonisolated static let tab: UInt16 = 48
    nonisolated static let downArrow: UInt16 = 125
    nonisolated static let upArrow: UInt16 = 126

    private static func views<Kind: NSView>(_ kind: Kind.Type, in view: NSView) -> [Kind] {
        view.subviews.flatMap { ($0 as? Kind).map { [$0] } ?? views(kind, in: $0) }
    }
}

/// What the sidebar and the list asked the window for: the Filter field's first match, or a row of the sidebar.
@MainActor
private final class Asked {
    var matches = 0
    var clicks: [Root] = []
}
