import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// ⌘F moves keyboard focus into the Filter field; Return on the sidebar's list moves it into the page, to its first
/// control, and Escape in the page moves it back to what holds the pick, in the SitRep window's split over the sidebar
/// as the window draws it, the board's list with Settings at its foot, and two buttons, made, never shown. A page's
/// buttons take focus only while the Mac's Keyboard navigation setting is on, so what needs them runs only then.
@MainActor
struct SideFocusTests {
    /// On the board's list, or on Settings at the foot while it shows.
    @Test(.enabled { await keyboardNavigation() }, arguments: [Pick.session("sr-macapp"), .settings])
    func returnOnTheListMovesFocusToThePagesFirstControl(on pick: Pick) throws {
        let sides = try Sides(pick: pick)

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

    /// With nothing in the page to take focus, AppKit's key loop wraps round to the Filter field, whose Return would
    /// open its first match over the row Lee picked: Return is taken, and focus stays on the list, the board's or the
    /// foot's, never passing through the field on the way, which VoiceOver would announce.
    @Test(arguments: [Pick.session("sr-macapp"), .settings])
    func returnWhereNothingInThePageTakesFocusLeavesFocusOnTheListAndOpensNothing(on pick: Pick) throws {
        let sides = try Sides(pick: pick, hasButtons: false, filter: "le")
        var responders: [NSResponder] = []

        // the key loop as a window on screen has it, through the field
        sides.window.recalculateKeyViewLoop()

        let watching = sides.window.observe(\.firstResponder, options: [.new]) { window, _ in
            MainActor.assumeIsolated { window.firstResponder.map { responders.append($0) } }
        }

        #expect(sides.pressThrough(SideFocus.return))
        watching.invalidate()
        #expect(sides.window.firstResponder === sides.list)
        #expect(responders.isEmpty)
        #expect(!sides.isInField)
        #expect(sides.asked.opens == 0)
    }

    /// The other side of it: Return in the field, as AppKit hands it on, opens the first match.
    @Test func returnInTheFilterFieldOpensTheFirstMatch() throws {
        let sides = try Sides(filter: "le")

        sides.press(Sides.f, with: .command, typing: "f")
        #expect(!sides.pressThrough(SideFocus.return))
        #expect(sides.asked.opens == 1)
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

    /// The window turned to Settings and back, as ⌘, or a click turns it, and focus moved each time before SwiftUI's
    /// next pass shows the pick in the tables, which hold Settings by the time it turns back.
    @Test func escapeFollowsThePickAsTheWindowTurnsToSettingsAndBack() throws {
        let sides = try Sides()

        sides.turn(to: .settings)
        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.foot)

        sides.window.contentView?.layoutSubtreeIfNeeded()
        try #require(sides.foot.isPicked)
        sides.turn(to: .session("sr-macapp"))
        sides.window.makeFirstResponder(sides.focus.page)
        #expect(sides.press(SideFocus.escape))
        #expect(sides.window.firstResponder === sides.board)
    }

    @Test func turningToAPickPutsFocusOnItsList() throws {
        let sides = try Sides()

        sides.turn(to: .settings)
        sides.focus.focusList()
        #expect(sides.window.firstResponder === sides.foot)
        #expect(sides.foot.focusRingType == .none)

        sides.turn(to: .session("sr-macapp"))
        sides.focus.focusList()
        #expect(sides.window.firstResponder === sides.board)
        #expect(sides.foot.focusRingType == .default)
    }

    /// The foot is the stop after the board's list, as Tab and Shift-Tab step, whether Keyboard navigation is on or
    /// not, in the key loop as a window on screen has it.
    @Test func tabFromTheBoardsListGoesToSettingsAtTheFootAndShiftTabComesBack() throws {
        let sides = try Sides()

        sides.window.recalculateKeyViewLoop()
        sides.send(Sides.tab, typing: "\t")
        #expect(sides.window.firstResponder === sides.foot)
        sides.send(Sides.tab, with: .shift, typing: "\u{19}")
        #expect(sides.window.firstResponder === sides.board)
    }

    @Test(.enabled { await keyboardNavigation() })
    func tabFromTheFootGoesToThePagesFirstControl() throws {
        let sides = try Sides(pick: .settings)

        sides.window.recalculateKeyViewLoop()
        sides.send(Sides.tab, typing: "\t")
        #expect(sides.focused === sides.firstControl)
    }

    /// Return as the window's monitor leaves it to the foot, while Settings is not the pick.
    @Test(arguments: [(Sides.space, " "), (SideFocus.return, "\r"), (SideFocus.enter, "\u{3}")])
    func spaceOrReturnOnTheFootOpensSettingsFocusStayingThere(key: UInt16, typing characters: String) throws {
        let sides = try Sides()

        sides.window.makeFirstResponder(sides.foot)
        #expect(!sides.pressThrough(key, typing: characters))
        #expect(sides.asked.picks == [.settings])
        #expect(sides.window.firstResponder === sides.foot)
    }

    /// With a modifier held, Return on the foot is neither the window's nor the foot's, as on the board's list.
    @Test func returnWithAModifierOnTheFootOpensNothing() throws {
        let sides = try Sides()

        sides.window.makeFirstResponder(sides.foot)
        #expect(!sides.pressThrough(SideFocus.return, with: .shift))
        #expect(sides.asked.picks.isEmpty)
        #expect(sides.window.firstResponder === sides.foot)
    }

    /// Past either end of what holds focus, the arrows go nowhere: the board's last row keeps focus, and so does the
    /// foot, picking nothing.
    @Test(arguments: [Sides.downArrow, Sides.upArrow])
    func theArrowsGoNowhereFromTheFoot(key: UInt16) throws {
        let sides = try Sides()

        sides.window.makeFirstResponder(sides.foot)
        sides.send(arrow: key)
        #expect(sides.window.firstResponder === sides.foot)
        #expect(sides.asked.picks.isEmpty)
    }

    @Test func downFromTheBoardsLastRowStaysOnTheBoard() throws {
        let sides = try Sides(pick: .project("kit"))

        try #require(sides.board.selectedRow == sides.board.numberOfRows - 1)
        sides.send(arrow: Sides.downArrow)
        #expect(sides.window.firstResponder === sides.board)
        #expect(sides.asked.picks.isEmpty)
    }

    @Test func withNothingPickedFocusGoesToTheBoardsList() throws {
        let sides = try Sides(pick: nil, focusingList: false)

        #expect(sides.board.selectedRow < 0 && !sides.foot.isPicked)
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
    /// The board's list, and Settings at its foot.
    let board: NSTableView
    let foot: SettingsFootControl
    /// What the sidebar asked the window for.
    let asked: Asked
    private let sidebar: NSHostingController<Column>
    private let picked: Picked
    private let filter: Filter

    /// What holds the pick.
    var list: NSView { picked.pick == .settings ? foot : board }

    /// A page of buttons, or of words alone, as a page is with Keyboard navigation off: nothing in it takes focus.
    init(
        pick: Pick? = .session("sr-macapp"), hasButtons: Bool = true, focusingList: Bool = true, filter: String = ""
    ) throws {
        let picked = Picked(pick)
        let filter = Filter(filter)
        let asked = Asked()
        let sidebar = NSHostingController(rootView: Column(pick: pick, filter: filter, asked: asked))
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
        focus = SideFocus(window: window, sidebar: sidebar.view, page: page.view) { picked.pick }
        self.sidebar = sidebar
        self.picked = picked
        self.filter = filter
        self.asked = asked

        board = try #require(Self.views(NSTableView.self, in: sidebar.view).first)
        foot = try #require(Self.views(SettingsFootControl.self, in: sidebar.view).first)
        if focusingList {
            window.makeFirstResponder(list)
        }
    }

    /// Turned to this pick as the window turns: the sidebar drawn on it again, its tables showing it only at SwiftUI's
    /// next pass.
    func turn(to pick: Pick?) {
        picked.pick = pick
        sidebar.rootView = Column(pick: pick, filter: filter, asked: asked)
    }

    /// The board's list as the real `watch` first printed it.
    fileprivate static let sidebar = {
        var last = LastBoard()
        let run = WindowRun()

        last.begin()
        _ = last.hear(.line(Lines.watch[0]), at: Date())
        _ = run.show(last, at: Date(), reducesMotion: false)
        return run.sidebar(at: Date())
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

    /// The F key, Tab, Space and the arrows.
    nonisolated static let f: UInt16 = 3
    nonisolated static let tab: UInt16 = 48
    nonisolated static let space: UInt16 = 49
    nonisolated static let downArrow: UInt16 = 125
    nonisolated static let upArrow: UInt16 = 126

    private static func views<Kind: NSView>(_ kind: Kind.Type, in view: NSView) -> [Kind] {
        view.subviews.flatMap { ($0 as? Kind).map { [$0] } ?? views(kind, in: $0) }
    }
}

/// The sidebar as the window draws it, its presses heard.
private struct Column: View {
    let pick: Pick?
    let filter: Filter
    let asked: Asked

    var body: some View {
        BoardColumn(
            sidebar: Sides.sidebar, spot: pick.flatMap { $0 == .settings ? nil : .board($0) }, pick: pick, filter: filter,
            now: Date()
        )
            .environment(\.windowActions, WindowActions(
                pick: { [asked] in asked.picks.append($0) }, openFirstMatch: { [asked] in asked.opens += 1 }
            ))
    }
}

/// What the sidebar asked the window for.
@MainActor
private final class Asked {
    var opens = 0
    var picks: [Pick] = []
}

/// What the window shows, as its model holds it.
private final class Picked {
    var pick: Pick?

    init(_ pick: Pick?) {
        self.pick = pick
    }
}
