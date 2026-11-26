import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The shortcut in the notch's run (DESIGN, "Keys"): it pours the panel open with no pointer, which stays open wherever
/// the pointer is until the pointer has come onto it and left; its lit row the first in Needs you, else the first row;
/// holding every key until it closes, a key of the set acting as under a hover's hold, the pointer moving on it taking
/// the lit row back while the hold stays the shortcut's; closed by the shortcut again, a key with ⌘, ⌃ or ⌥, `o`,
/// `esc` once nothing inside is open, or a click elsewhere. Without the leave, or under secure input, it opens holding
/// nothing, no row lit.
@Suite(.backstop)
struct ShortcutRunTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)
    private static let frameMS = 1000.0 / 60
    private static let away = CGPoint(x: 1300, y: 300), elsewhere = CGPoint(x: 900, y: 700)
    private static let onTheNotch = CGPoint(x: 3, y: 491)
    private static let helpDesk = "needs:\(AsksBoard.helpDesk)", working = "sr-wg0005"

    private static func setting(
        _ style: NotchStyle = .meniscus, takesKeys: Bool = true, reducesMotion: Bool = false
    ) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: stage, mirror: .identity, style: style, reducesMotion: reducesMotion, takesKeys: takesKeys
        )
    }

    private static func at(_ run: NotchRun, _ pointer: CGPoint?, _ setting: NotchRun.Setting) -> NotchRun.Moment {
        NotchRun.Moment(time: run.time + frameMS, pointer: pointer, setting: setting)
    }

    private static func frames(
        _ run: NotchRun, for ms: Double, _ pointer: CGPoint?, _ setting: NotchRun.Setting,
        until done: () -> Bool = { false }
    ) {
        let end = run.time + ms

        while run.time < end, !done() {
            run.step(at(run, pointer, setting))
        }
    }

    /// A run over `board`, the asks' unless given, at rest closed, the pointer away.
    private static func closed(_ setting: NotchRun.Setting, board: PanelBoard = AsksBoard.board()) -> NotchRun {
        let run = NotchRun(at: 1000, in: setting, folding: Folding())

        _ = run.show(board, at(run, away, setting))
        frames(run, for: 1000, away, setting)
        return run
    }

    /// The shortcut pressed with the pointer away, and the panel at rest open.
    private static func summoned(
        _ setting: NotchRun.Setting = setting(), board: PanelBoard = AsksBoard.board()
    ) throws -> NotchRun {
        let run = closed(setting, board: board)

        run.summon(at(run, away, setting))
        frames(run, for: 3000, away, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open)
        return run
    }

    /// A row's words, near its left.
    private static func words(_ key: String, _ run: NotchRun) throws -> CGPoint {
        let panel = try #require(run.frame.panel), index = try #require(run.list.index(of: key))
        let row = run.list.content.laidFrame(index)

        return CGPoint(x: panel.frame.minX + row.minX + 60, y: panel.frame.minY + row.midY - run.scroll)
    }

    private static func rows(_ run: NotchRun) -> [String] {
        run.list.content.entries.filter(\.jumps).map(\.item.key)
    }

    private static func lit(_ run: NotchRun, _ setting: NotchRun.Setting = setting()) -> String? {
        run.lit(in: setting).flatMap { run.list.item($0)?.key }
    }

    /// A key pressed, the pointer where it was, the hold the tap ended with it `ending`, as it ends one with `o`.
    @discardableResult
    private static func press(
        _ key: PanelKey, _ run: NotchRun, _ pointer: CGPoint = away, _ setting: NotchRun.Setting = setting(),
        ending: Int? = nil
    ) -> NotchRun.Press? {
        run.key(key, ending: ending, at(run, pointer, setting))
    }

    /// Frames with the pointer `at` until the panel is in, or `ms` pass.
    private static func closes(_ run: NotchRun, at pointer: CGPoint, _ setting: NotchRun.Setting = setting()) -> Bool {
        frames(run, for: 3000, pointer, setting) { run.phase == .closed }
        return run.phase == .closed
    }

    // MARK: The open

    /// It pours open with the pointer away, and stays open, in either style, with motion or without: the pointer
    /// elsewhere never closes it by itself.
    @Test(arguments: [NotchStyle.meniscus, .card], [false, true])
    func itOpensWithThePointerAwayAndStaysOpen(style: NotchStyle, reducesMotion: Bool) throws {
        let setting = Self.setting(style, reducesMotion: reducesMotion)
        let run = Self.closed(setting)

        run.summon(Self.at(run, Self.away, setting))
        #expect(run.isOut)
        Self.frames(run, for: 3000, Self.away, setting)
        #expect(run.phase == .open)
        Self.frames(run, for: 2000, Self.elsewhere, setting)
        #expect(run.phase == .open)
    }

    @Test func itsLitRowIsTheFirstInNeedsYou() throws {
        let run = try Self.summoned()

        #expect(Self.lit(run) == Self.helpDesk)
        #expect(Self.rows(run).first == Self.helpDesk)
    }

    /// With nothing in Needs you, the first row.
    @Test func withNothingInNeedsYouItsLitRowIsTheFirstRow() throws {
        let run = try Self.summoned(board: Self.workingAlone())

        #expect(Self.lit(run) == Self.working)
    }

    @Test func itHoldsEveryKeyInAHoldOfItsOwn() throws {
        let run = try Self.summoned()

        #expect(run.holdsKeys)
        #expect(run.keySnapshot == .panel(hold: 1, takesAll: true))
    }

    /// A key of the set acts at once, the panel still pouring.
    @Test func aKeyActsAsThePanelPours() {
        let setting = Self.setting(), run = Self.closed(setting)

        run.summon(Self.at(run, Self.away, setting))
        Self.press(.down, run)
        #expect(run.phase == .opening)
        #expect(Self.lit(run) == Self.rows(run).dropFirst().first)
    }

    /// `⏎` as the panel still pours opens the lit row's asks panel, as on the open panel, and the asks panel stays open
    /// as the panel opens; its keys act at once, as on the open panel, in either style.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func returnAsThePanelPoursOpensTheAsksPanel(style: NotchStyle) throws {
        let setting = Self.setting(style), run = Self.closed(setting)
        let threaded = Answering(.words("Threaded"), to: "k1", of: AsksBoard.helpDesk, wanting: .choice)

        run.summon(Self.at(run, Self.away, setting))
        #expect(Self.press(.enter, run, Self.away, setting) == .asks)
        #expect(run.phase == .opening && run.asksShown?.row == Self.helpDesk)
        #expect(Self.press(.digit(1), run, Self.away, setting) == .answer(threaded))
        guard case .snooze(ask: "k1", of: AsksBoard.helpDesk, at: _)? = Self.press(.snooze, run, Self.away, setting)
        else {
            Issue.record("z offered no snooze")
            return
        }
        #expect(run.phase == .opening)

        Self.frames(run, for: 3000, Self.away, setting) { run.phase == .open && !run.frame.isMoving }
        #expect(run.phase == .open && run.asksShown?.row == Self.helpDesk)
    }

    /// On the list as the panel pours, `z` offers the lit row's snooze beside it, and a digit, with no use on the list,
    /// does nothing, as on the open panel.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func zAndADigitAsThePanelPoursActAsOnTheOpenPanel(style: NotchStyle) {
        let setting = Self.setting(style), run = Self.closed(setting)

        run.summon(Self.at(run, Self.away, setting))
        #expect(Self.press(.digit(1), run, Self.away, setting) == nil)
        guard case let .snoozeRow(session, row: _)? = Self.press(.snooze, run, Self.away, setting) else {
            Issue.record("z offered no snooze menu")
            return
        }
        #expect(session.id == AsksBoard.helpDesk && run.phase == .opening)
    }

    // MARK: The pointer

    /// Moving elsewhere, the pointer leaves the lit row the keys', and the panel open.
    @Test func thePointerMovingElsewhereKeepsTheLitRowAndThePanel() throws {
        let setting = Self.setting(), run = try Self.summoned()

        Self.press(.down, run)

        let second = Self.lit(run)

        Self.frames(run, for: 1500, Self.elsewhere, setting)
        #expect(Self.lit(run) == second && run.phase == .open && run.holdsKeys)
    }

    /// Moving on it, the pointer takes the lit row back, as under a hover's hold, and the hold stays the shortcut's;
    /// leaving it again, the panel closes.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func thePointerComingOntoItTakesTheLitRowAndLeavingClosesIt(style: NotchStyle) throws {
        let setting = Self.setting(style), run = try Self.summoned(setting)
        let row = try #require(Self.rows(run).dropFirst(2).first), pointer = try Self.words(row, run)

        run.step(Self.at(run, pointer, setting))
        #expect(Self.lit(run, setting) == row)
        #expect(run.keySnapshot == .panel(hold: 1, takesAll: true))
        #expect(Self.closes(run, at: Self.away, setting))
        #expect(!run.holdsKeys)
    }

    /// A menu's held place is no move of the pointer's: `z` opens the row's snooze menu, which holds the panel at the
    /// row as it shows, and closed, the pointer is where it was, which is no move either. The panel stays open as the
    /// pointer, away or resting on the panel, then moves off.
    @Test(arguments: [NotchStyle.meniscus, .card], [false, true])
    func aMenuHoldingThePanelIsNoPointerComingOntoIt(style: NotchStyle, resting: Bool) throws {
        let setting = Self.setting(style)
        let (run, pointer) = resting ? try Self.summonedUnder(setting) : (try Self.summoned(setting), Self.away)

        guard case let .snoozeRow(_, row: row)? = Self.press(.snooze, run, pointer, setting) else {
            Issue.record("z offered no snooze menu")
            return
        }

        run.menuOpened(at: CGPoint(x: row.midX, y: row.midY))
        Self.frames(run, for: 500, pointer, setting)
        run.menuClosed()
        Self.frames(run, for: 500, pointer, setting)
        Self.frames(run, for: 2000, Self.away, setting)
        #expect(run.phase == .open)
    }

    /// `⏎` opening the asks panel beside the lit row, the pointer away, leaves the panel open.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func theAsksPanelOpeningIsNoPointerComingOntoIt(style: NotchStyle) throws {
        let setting = Self.setting(style), run = try Self.summoned(setting)

        #expect(Self.press(.enter, run, Self.away, setting) == .asks)
        Self.frames(run, for: 2000, Self.away, setting)
        #expect(run.phase == .open && run.asksShown != nil)
    }

    /// A pointer left resting on the panel, as `esc` closed it under it, comes onto the panel the shortcut opens only
    /// as it moves; then leaving it closes it, with motion or without.
    @Test(arguments: [(NotchStyle.meniscus, false), (.meniscus, true), (.card, false), (.card, true)])
    func aPointerRestingOnThePanelComesOntoItOnlyAsItMoves(style: NotchStyle, reducesMotion: Bool) throws {
        let setting = Self.setting(style, reducesMotion: reducesMotion)
        let (run, resting) = try Self.summonedUnder(setting)

        Self.frames(run, for: 2000, resting, setting)
        #expect(run.phase == .open)
        Self.frames(run, for: 2000, Self.elsewhere, setting)
        #expect(run.phase == .open)

        run.step(Self.at(run, CGPoint(x: resting.x, y: resting.y + 2), setting))
        #expect(Self.closes(run, at: Self.away, setting))
    }

    /// The panel the shortcut opened, at rest, under a pointer left resting on its first row's words, as `esc` closed
    /// the panel the pointer had opened under it.
    private static func summonedUnder(_ setting: NotchRun.Setting) throws -> (NotchRun, CGPoint) {
        let run = closed(setting)

        frames(run, for: 3000, onTheNotch, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open)

        let resting = try words(helpDesk, run)

        run.step(at(run, resting, setting))
        press(.escape, run, resting, setting)
        try #require(closes(run, at: resting, setting))
        run.summon(at(run, resting, setting))
        frames(run, for: 3000, resting, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open)
        return (run, resting)
    }

    // MARK: What closes it

    /// Closing, the panel takes no shortcut: it goes on closing.
    @Test func closingItTakesNoShortcut() throws {
        let setting = Self.setting(), run = try Self.summoned()

        Self.press(.escape, run)
        try #require(run.phase == .closing)
        run.summon(Self.at(run, Self.away, setting))
        #expect(run.phase == .closing && !run.holdsKeys)
        #expect(Self.closes(run, at: Self.away))
    }

    /// The shortcut again closes it, whether it opened, or the pointer opened it.
    @Test func theShortcutAgainClosesIt() throws {
        let setting = Self.setting(), run = try Self.summoned()

        run.summon(Self.at(run, Self.away, setting))
        #expect(run.phase == .closing && !run.holdsKeys)

        let hovered = Self.closed(setting)

        Self.frames(hovered, for: 3000, Self.onTheNotch, setting) { hovered.phase == .open }
        try #require(hovered.phase == .open)
        hovered.summon(Self.at(hovered, Self.onTheNotch, setting))
        #expect(hovered.phase == .closing)
    }

    /// A key with ⌘, ⌃ or ⌥, which the tap let go of in its hold, closes it.
    @Test func aKeyItLetGoOfClosesIt() throws {
        let setting = Self.setting(), run = try Self.summoned()

        run.letGoOfKeys(in: 1, Self.at(run, Self.away, setting))
        #expect(run.phase == .closing && !run.holdsKeys)
    }

    /// `o` jumps to the lit row; with none to jump to, it closes the panel all the same.
    @Test func oJumpsOrClosesIt() throws {
        let run = try Self.summoned()

        guard case .jump(_, to: AsksBoard.helpDesk, click: _)? = Self.press(.open, run, ending: 1) else {
            Issue.record("o did not jump to the lit row")
            return
        }
        #expect(!run.holdsKeys)

        let empty = try Self.summoned(board: PanelBoard())

        #expect(Self.lit(empty) == nil)
        #expect(Self.press(.open, empty, ending: 1) == nil)
        #expect(empty.phase == .closing && !empty.holdsKeys)
    }

    /// The tap alone decides whether `o` ends the hold: `1` then `o` on the asks panel, the tap ending the hold at `o`
    /// before the answer showed, closes the panel, though the sending line shows by the time the panel hears `o`.
    @Test func oTheTapEndedTheHoldWithClosesItThoughTheSendingLineShowsBy() throws {
        let setting = Self.setting(), run = try Self.summoned()
        let threaded = Answering(.words("Threaded"), to: "k1", of: AsksBoard.helpDesk, wanting: .choice)
        let now = Date(timeIntervalSince1970: Double(AsksBoard.at) / 1000)

        #expect(Self.press(.enter, run) == .asks)
        #expect(Self.press(.digit(1), run) == .answer(threaded))
        run.heard(
            .held(HeldAnswer(answering: threaded, heldAt: now, goesAt: now.addingTimeInterval(2))),
            Self.at(run, Self.away, setting)
        )
        try #require(run.asksShown?.sending != nil)
        #expect(Self.press(.open, run, ending: 1) == nil)
        #expect(run.phase == .closing && !run.holdsKeys && run.keySnapshot == .none)
    }

    /// A hold the tap ended while a menu holds the card, as `o` or a chord racing the snooze menu `z` opened, is let
    /// go, but the panel stays open under the menu, holding nothing.
    @Test(arguments: [false, true])
    func aHoldEndedUnderAMenuLeavesThePanelOpen(byChord: Bool) throws {
        let setting = Self.setting(), run = try Self.summoned()

        guard case let .snoozeRow(_, row: row)? = Self.press(.snooze, run) else {
            Issue.record("z offered no snooze menu")
            return
        }

        run.menuOpened(at: CGPoint(x: row.midX, y: row.midY))
        if byChord {
            run.letGoOfKeys(in: 1, Self.at(run, Self.away, setting))
        } else {
            #expect(Self.press(.open, run, ending: 1) == nil)
        }
        #expect(run.phase == .open && !run.holdsKeys)
    }

    /// `⌘Z` stays the panel's through the beat after the sending line goes in the shortcut's hold too, so one pressed
    /// a moment late neither closes the panel nor reaches the window in front.
    @Test func commandZStaysThePanelsThroughTheBeatAfterTheSendingLineGoes() throws {
        let setting = Self.setting(), run = try Self.summoned()
        let threaded = Answering(.words("Threaded"), to: "k1", of: AsksBoard.helpDesk, wanting: .choice)
        let now = Date(timeIntervalSince1970: Double(AsksBoard.at) / 1000)

        #expect(Self.press(.enter, run) == .asks)
        run.heard(
            .held(HeldAnswer(answering: threaded, heldAt: now, goesAt: now.addingTimeInterval(2))),
            Self.at(run, Self.away, setting)
        )
        run.heard(.went(threaded), Self.at(run, Self.away, setting))
        try #require(run.asksShown?.sending == nil && run.asksShown != nil)
        #expect(run.keySnapshot == .panel(hold: 1, undoes: true, takesAll: true))
        #expect(Self.press(.undo, run) == nil && run.phase == .open)

        Self.frames(run, for: AsksPanel.settle, Self.away, setting)
        #expect(run.keySnapshot == .panel(hold: 1, undoes: false, takesAll: true))
    }

    /// Letting go of the keys, as the screens sleep or a window takes secure input, leaves the panel open holding
    /// nothing, with no row lit, the keys' row let go.
    @Test(arguments: [false, true])
    func lettingGoOfTheKeysLeavesNoRowLit(secureInput: Bool) throws {
        let run = try Self.summoned()

        Self.press(.down, run)
        try #require(Self.lit(run) != nil)
        if secureInput {
            run.step(Self.at(run, Self.away, Self.setting(takesKeys: false)))
        } else {
            run.letGoOfKeys(Self.at(run, Self.away, Self.setting()))
        }
        #expect(!run.holdsKeys && Self.lit(run) == nil && run.phase == .open)
    }

    /// `esc` closes the asks panel first, then the panel.
    @Test func escClosesTheAsksPanelThenThePanel() throws {
        let run = try Self.summoned()

        #expect(Self.press(.enter, run) == .asks)
        try #require(run.asksShown != nil)
        Self.press(.escape, run)
        #expect(run.asksShown == nil && run.phase == .open && run.holdsKeys)
        Self.press(.escape, run)
        #expect(run.phase == .closing && !run.holdsKeys)
    }

    @Test func aClickElsewhereClosesIt() throws {
        let setting = Self.setting(), run = try Self.summoned()

        run.clickElsewhere(Self.at(run, Self.away, setting))
        #expect(Self.closes(run, at: Self.away))
        #expect(!run.holdsKeys)
    }

    // MARK: Without the leave

    /// Without the leave, or under secure input, it opens holding nothing, with no row lit, and stays open wherever the
    /// pointer is, until the pointer comes onto it and leaves.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func withoutTheLeaveItOpensHoldingNothingWithNoRowLit(style: NotchStyle) throws {
        let setting = Self.setting(style, takesKeys: false), run = try Self.summoned(setting)

        #expect(!run.holdsKeys && run.keySnapshot == .none)
        #expect(Self.lit(run, setting) == nil)
        Self.frames(run, for: 2000, Self.elsewhere, setting)
        #expect(run.phase == .open)

        run.step(Self.at(run, try Self.words(Self.helpDesk, run), setting))
        #expect(!run.holdsKeys)
        #expect(Self.closes(run, at: Self.away, setting))
    }

    /// Mobile app of Woodgrove working, alone on the board.
    private static func workingAlone() -> PanelBoard {
        let row = WatchLine.Row(
            session: working, name: "Mobile app", projectName: "Woodgrove",
            lines: [.init("work:\(working)", .working, first: "Running the tests", since: AsksBoard.ago(3))]
        )
        var last = LastBoard()

        _ = last.hear(
            .line(WatchLine(at: AsksBoard.at, rows: [row]).text),
            at: Date(timeIntervalSince1970: Double(AsksBoard.at) / 1000)
        )
        return PanelBoard(last)
    }
}
