import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The notch's panel's keys as its run has them (DESIGN, "Keys"): the panel holds them once the pointer moves on its
/// open list or asks panel, never on an open under a resting pointer, until the pointer moves off, a key it doesn't take
/// lets go, or it closes; `↑` `↓` move a lit row over the rows, past eyebrows and folded sections, scrolled into view,
/// the pointer moving taking it back; and each row key does what its click does: `⏎` the arrow, `o` the words, `z` the
/// row's Snooze or Wake now, `s` Snoozed's eyebrow, `esc` a click elsewhere. With the asks panel open, `↑` `↓` move
/// and close it, `⏎` and `esc` close it, and closed by a key under the pointer, it holds the panel until the pointer
/// moves.
@Suite(.backstop)
struct NotchKeysRunTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)
    private static let frameMS = 1000.0 / 60
    private static let onTheNotch = CGPoint(x: 3, y: 491), away = CGPoint(x: 1300, y: 491)
    private static let helpDesk = "needs:\(AsksBoard.helpDesk)", shifts = "needs:\(AsksBoard.shifts)"
    private static let ledger = "needs:\(AsksBoard.ledger)", turn = "turn:sr-ts0004", working = "sr-wg0005"
    private static let snoozed = "snoozed:\(AsksBoard.helpDesk)"

    private static func setting(right: Bool = false, takesKeys: Bool = true) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: stage, mirror: right ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 800, ty: 0) : .identity,
            style: .meniscus, reducesMotion: false, isChosen: true, takesKeys: takesKeys
        )
    }

    /// The run, a frame on, the pointer here.
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

    /// A run over `board`, the asks' unless given, Snoozed unfolded unless `folded`, its panel opened by the pointer
    /// held on the notch, and at rest, the pointer still there.
    private static func opened(
        _ setting: NotchRun.Setting = setting(), board: PanelBoard = AsksBoard.board(), folded: Bool = false
    ) -> NotchRun {
        let folding = Folding()

        folding.set(.snoozed, folded: folded)

        let run = NotchRun(at: 1000, in: setting, folding: folding)

        _ = run.show(board, at(run, nil, setting))
        frames(run, for: 3000, CGPoint(x: 3, y: setting.stage.notchY), setting) {
            run.phase == .open && !run.frame.isMoving
        }
        return run
    }

    /// The run opened, the pointer moved onto the row `key`'s words, so the panel holds the keys.
    private static func holding(
        _ key: String = helpDesk, _ setting: NotchRun.Setting = setting(), board: PanelBoard = AsksBoard.board(),
        folded: Bool = false
    ) throws -> (run: NotchRun, pointer: CGPoint) {
        let run = opened(setting, board: board, folded: folded), pointer = try words(key, run, setting)

        run.step(at(run, pointer, setting))
        try #require(run.holdsKeys)
        return (run, pointer)
    }

    /// A point on the content, on the stage, through the edge's mirror.
    private static func onStage(
        _ x: Double, _ y: Double, _ run: NotchRun, _ setting: NotchRun.Setting
    ) throws -> CGPoint {
        let panel = try #require(run.frame.panel)

        return CGPoint(
            x: setting.mirror.a < 0 ? panel.frame.maxX - x : panel.frame.minX + x,
            y: panel.frame.minY + y - run.scroll
        )
    }

    private static func laid(_ key: String, _ run: NotchRun) throws -> CGRect {
        let index = try #require(run.list.index(of: key), "no row \(key)")

        return run.list.content.laidFrame(index)
    }

    /// A row's words, near its left.
    private static func words(_ key: String, _ run: NotchRun, _ setting: NotchRun.Setting) throws -> CGPoint {
        let row = try laid(key, run)

        return try onStage(row.minX + 60, row.midY, run, setting)
    }

    /// The middle of a row's arrow.
    private static func arrow(_ key: String, _ run: NotchRun, _ setting: NotchRun.Setting) throws -> CGPoint {
        let row = try laid(key, run), box = RowArrow.box(in: row.size, pointsLeft: setting.mirror.a < 0)

        return try onStage(row.minX + box.midX, row.minY + box.midY, run, setting)
    }

    /// The rows' keys, in the list's order.
    private static func rows(_ run: NotchRun) -> [String] {
        run.list.content.entries.filter(\.jumps).map(\.item.key)
    }

    /// The key of the item lit, the keys' or the pointer's.
    private static func lit(_ run: NotchRun, _ setting: NotchRun.Setting = setting()) -> String? {
        run.lit(in: setting).flatMap { run.list.item($0)?.key }
    }

    /// A key pressed, the pointer where it was.
    @discardableResult
    private static func press(
        _ key: PanelKey, _ run: NotchRun, _ pointer: CGPoint, _ setting: NotchRun.Setting = setting()
    ) -> NotchRun.Press? {
        run.key(key, at(run, pointer, setting))
    }

    // MARK: The hold

    @Test func aPanelOpenedUnderARestingPointerHoldsNothingUntilItMovesOnTheList() throws {
        let run = Self.opened(), setting = Self.setting()

        #expect(run.phase == .open)
        Self.frames(run, for: 500, Self.onTheNotch, setting)
        #expect(!run.holdsKeys && run.keySnapshot == .none)
        #expect(Self.press(.down, run, Self.onTheNotch) == nil)
        #expect(Self.lit(run) != Self.rows(run).first)

        run.step(Self.at(run, try Self.words(Self.helpDesk, run, setting), setting))
        #expect(run.holdsKeys && run.keySnapshot == .panel(hold: 1))
    }

    @Test func movingOnTheAsksPanelHoldsTheKeysToo() throws {
        let run = Self.opened(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.arrow(Self.helpDesk, run, setting), setting)) == .asks)
        run.letGoOfKeys(in: 1, Self.at(run, try Self.arrow(Self.helpDesk, run, setting), setting))

        let asks = try #require(run.asksShown)

        run.step(Self.at(run, CGPoint(x: asks.frame.maxX - 40, y: asks.frame.midY), setting))
        #expect(run.holdsKeys)
    }

    /// The hold ends as the pointer moves off the list and the asks panel, before the panel's grace closes it, so a key
    /// typed meanwhile goes to the window in front.
    @Test func aMoveOffThePanelEndsTheHoldAtOnce() throws {
        var (run, pointer) = try Self.holding()
        let setting = Self.setting(), onList = { run.frame.panel?.contains(pointer) == true }

        while onList() {
            pointer.x += 2
            run.step(Self.at(run, pointer, setting))
            #expect(run.holdsKeys == onList())
        }
        #expect(run.phase == .open)
        #expect(run.keySnapshot == .none)
    }

    @Test func aKeyThePanelDoesntTakeLetsGoUntilThePointerMovesAgain() throws {
        let (run, pointer) = try Self.holding(), setting = Self.setting()

        run.letGoOfKeys(in: 1, Self.at(run, pointer, setting))
        #expect(run.keySnapshot == .none)
        Self.frames(run, for: 300, pointer, setting)
        #expect(run.keySnapshot == .none)
        #expect(Self.press(.down, run, pointer) == nil && Self.lit(run) == Self.helpDesk)

        run.step(Self.at(run, try Self.words(Self.shifts, run, setting), setting))
        #expect(run.keySnapshot == .panel(hold: 2))
    }

    /// A let-go heard late, the pointer having moved since and begun another hold, leaves that hold: the key never
    /// ended it.
    @Test func aLetGoOfAnEarlierHoldLeavesTheHoldBegunSince() throws {
        let (run, pointer) = try Self.holding(), setting = Self.setting()
        let shifts = try Self.words(Self.shifts, run, setting)

        run.letGoOfKeys(in: 1, Self.at(run, pointer, setting))
        run.step(Self.at(run, shifts, setting))
        try #require(run.keySnapshot == .panel(hold: 2))
        run.letGoOfKeys(in: 1, Self.at(run, shifts, setting))
        #expect(run.keySnapshot == .panel(hold: 2))
    }

    /// The screens sleeping, or the session going to another user, lets go of whichever hold it is, until the pointer
    /// moves again.
    @Test func lettingGoOfEveryHoldLastsUntilThePointerMovesAgain() throws {
        let (run, pointer) = try Self.holding(), setting = Self.setting()

        run.letGoOfKeys(Self.at(run, pointer, setting))
        Self.frames(run, for: 300, pointer, setting)
        #expect(run.keySnapshot == .none)

        run.step(Self.at(run, try Self.words(Self.shifts, run, setting), setting))
        #expect(run.keySnapshot == .panel(hold: 2))
    }

    /// While a menu holds the card, the keys are the menu's: one the panel heard meanwhile does nothing.
    @Test func whileAMenuHoldsTheCardAKeyDoesNothing() throws {
        let (run, pointer) = try Self.holding()

        run.menuOpened(at: pointer)
        #expect(Self.press(.down, run, pointer) == nil)
        #expect(Self.press(.open, run, pointer) == nil)
        #expect(Self.lit(run) == Self.helpDesk)
        run.menuClosed()
        Self.press(.down, run, pointer)
        #expect(Self.lit(run) != Self.helpDesk)
    }

    @Test func theHoldEndsAsThePanelCloses() throws {
        let (run, pointer) = try Self.holding(), setting = Self.setting()

        run.clickElsewhere(Self.at(run, pointer, setting))
        run.step(Self.at(run, pointer, setting))
        #expect(run.phase != .open)
        #expect(run.keySnapshot == .none)
    }

    /// Without the Accessibility leave, or while a window holds secure input, the panel holds nothing, a move on it
    /// and all.
    @Test func whileTheMacLetsThePanelTakeNoKeysItHoldsNothing() throws {
        let setting = Self.setting(takesKeys: false), run = Self.opened(setting)

        run.step(Self.at(run, try Self.words(Self.shifts, run, setting), setting))
        #expect(!run.holdsKeys && run.keySnapshot == .none)

        let (held, pointer) = try Self.holding()

        held.step(Self.at(held, pointer, Self.setting(takesKeys: false)))
        #expect(held.keySnapshot == .none)
    }

    @Test func hiddenItHoldsNothing() throws {
        let (run, pointer) = try Self.holding()
        var hidden = Self.at(run, pointer, Self.setting())

        hidden.isShown = false
        run.catchUp(hidden)
        #expect(run.keySnapshot == .none)
    }

    // MARK: The lit row

    /// `↓` and `↑` move the lit row over the rows, across from Needs you to Working past its eyebrow, the pointer still.
    @Test func upAndDownMoveTheLitRowOverTheRowsPastTheEyebrows() throws {
        let (run, pointer) = try Self.holding()
        let rows = Self.rows(run), start = try #require(rows.firstIndex(of: Self.helpDesk))

        Self.press(.down, run, pointer)
        #expect(Self.lit(run) == rows[start + 1])
        for _ in 0 ..< rows.count {
            Self.press(.down, run, pointer)
        }
        #expect(Self.lit(run) == rows.last)
        #expect(Self.lit(run) == Self.snoozed)
        Self.press(.up, run, pointer)
        #expect(Self.lit(run) == rows[rows.count - 2])
    }

    /// As the terminal view's band does, the lit row stops at the first and the last.
    @Test func theLitRowStopsAtTheFirstAndTheLastRow() throws {
        let (run, pointer) = try Self.holding()
        let rows = Self.rows(run)

        Self.press(.up, run, pointer)
        #expect(Self.lit(run) == rows.first)
        for _ in 0 ... rows.count {
            Self.press(.down, run, pointer)
        }
        #expect(Self.lit(run) == rows.last)
    }

    /// With the pointer on an eyebrow, no row is lit: `↓` lights the first row, `↑` the last.
    @Test(arguments: [(PanelKey.down, true), (.up, false)])
    func withNoRowLitUpAndDownLightTheLastAndTheFirst(_ key: PanelKey, first: Bool) throws {
        let run = Self.opened(), setting = Self.setting()
        let eyebrow = run.list.content.laidFrame(0), pointer = try Self.onStage(60, eyebrow.midY, run, setting)

        run.step(Self.at(run, pointer, setting))
        try #require(run.holdsKeys)
        Self.press(key, run, pointer)
        #expect(Self.lit(run) == (first ? Self.rows(run).first : Self.rows(run).last))
    }

    @Test func aFoldedSectionsRowsArePassedOver() throws {
        let (run, pointer) = try Self.holding(folded: true)

        #expect(!Self.rows(run).contains(Self.snoozed))
        for _ in 0 ... Self.rows(run).count {
            Self.press(.down, run, pointer)
        }
        #expect(Self.lit(run) == Self.working)
    }

    @Test func thePointerMovingTakesTheHighlightBack() throws {
        let (run, pointer) = try Self.holding(), setting = Self.setting()

        Self.press(.down, run, pointer)
        Self.press(.down, run, pointer)
        run.step(Self.at(run, pointer, setting))
        #expect(Self.lit(run) != Self.helpDesk)

        let shifts = try Self.words(Self.shifts, run, setting)

        run.step(Self.at(run, shifts, setting))
        #expect(Self.lit(run) == Self.shifts)
        Self.press(.down, run, shifts)
        #expect(Self.lit(run) == Self.rows(run)[try #require(Self.rows(run).firstIndex(of: Self.shifts)) + 1])
    }

    /// A row the keys lit with the arrow shows it, unlit, as under the pointer.
    @Test func theLitRowShowsItsArrow() throws {
        let (run, pointer) = try Self.holding(Self.shifts), setting = Self.setting()

        Self.press(.up, run, pointer)
        #expect(Self.lit(run) == Self.helpDesk)
        #expect(run.arrows(in: setting) == [Self.helpDesk: false])
    }

    /// A list longer than the panel scrolls the lit row into view, as little as shows it whole.
    @Test func theLitRowScrollsIntoView() throws {
        let ids = (1 ... 40).map { String(format: "sr-nw%04d", $0) }
        let rows = ids.map { id in
            WatchLine.Row(session: id, name: id, lines: [.init("ask:\(id)", .ask, first: "Ask \(id)")])
        }
        var last = LastBoard()

        _ = last.hear(.line(WatchLine(rows: rows).text), at: Date())

        let (run, pointer) = try Self.holding("needs:sr-nw0001", board: PanelBoard(last))
        let shown = try #require(run.frame.panel?.frame.height)
        let first = try Self.laid("needs:sr-nw0001", run), bottom = try Self.laid("needs:sr-nw0040", run)

        #expect(run.list.content.height > shown + 200)
        #expect(run.scroll == 0)
        for _ in ids.dropFirst() {
            Self.press(.down, run, pointer)
        }
        #expect(Self.lit(run) == "needs:sr-nw0040")
        #expect(abs(run.scroll - (bottom.maxY - shown)) < 0.5)

        for _ in ids.dropFirst() {
            Self.press(.up, run, pointer)
        }
        #expect(Self.lit(run) == "needs:sr-nw0001")
        #expect(abs(run.scroll - first.minY) < 0.5)
    }

    // MARK: The row keys

    @Test func returnOnARowWithTheArrowOpensItsAsksPanelAndAgainClosesIt() throws {
        let (run, pointer) = try Self.holding()

        #expect(Self.press(.enter, run, pointer) == .asks)
        #expect(run.asksShown?.row == Self.helpDesk)
        #expect(Self.press(.enter, run, pointer) == .asks)
        #expect(run.asksShown == nil)
        #expect(run.phase == .open)
    }

    @Test(arguments: [Self.ledger, Self.turn, Self.working, Self.snoozed])
    func returnOnARowWithNoArrowDoesNothing(_ key: String) throws {
        let (run, pointer) = try Self.holding(key)

        #expect(Self.press(.enter, run, pointer) == nil)
        #expect(run.asksShown == nil)
        #expect(run.phase == .open)
    }

    /// `o` jumps as a click on the row's words: the row pressed in, the jump asked for.
    @Test func oJumpsAsAClickOnTheRowsWords() throws {
        let (run, pointer) = try Self.holding(Self.shifts)

        guard case let .jump(session, to: target, click: click)? = Self.press(.open, run, pointer) else {
            Issue.record("o did not jump")
            return
        }
        #expect(session.id == AsksBoard.shifts && target == AsksBoard.shifts && click == 1)
        run.step(Self.at(run, pointer, Self.setting()))
        #expect(run.frame.panel?.pressed == Self.shifts)
    }

    /// A jump ends the hold, the row the keys lit let go, and no hold starts while it is under way, the pointer moving
    /// on the list or not: `⏎` after `o` is for the window jumped to, not the panel draining.
    @Test(arguments: [false, true])
    func aJumpEndsTheHoldAndNoneStartsWhileItIsUnderWay(byClick: Bool) throws {
        var (run, pointer) = try Self.holding(Self.shifts)
        let setting = Self.setting()

        Self.press(.down, run, pointer)
        #expect(Self.lit(run) != Self.shifts)
        let jump = byClick ? run.press(Self.at(run, pointer, setting)) : Self.press(.open, run, pointer)
        #expect(jump != nil)
        #expect(!run.holdsKeys && run.keySnapshot == .none && Self.lit(run) == Self.shifts)

        run.step(Self.at(run, pointer, setting))
        #expect(run.frame.panel?.pressed != nil)
        for _ in 0 ..< 120 where run.frame.panel?.pressed != nil {
            pointer.y += 1
            run.step(Self.at(run, pointer, setting))
            #expect(run.keySnapshot == .none)
            #expect(Self.press(.enter, run, pointer) == nil && run.asksShown == nil)
        }
    }

    /// `o` with no row lit jumps nowhere and still ends the hold, as the tap ended it as it took `o`; so does `o` with
    /// the asks panel open, where it does nothing yet.
    @Test(arguments: [false, true])
    func oEndsTheHoldThoughItJumpsNowhere(asksOpen: Bool) throws {
        let run = Self.opened(), setting = Self.setting(), eyebrow = run.list.content.laidFrame(0)
        let pointer = try asksOpen
            ? Self.words(Self.helpDesk, run, setting) : Self.onStage(60, eyebrow.midY, run, setting)

        run.step(Self.at(run, pointer, setting))
        if asksOpen {
            Self.press(.enter, run, pointer)
            try #require(run.asksShown != nil)
        }
        try #require(run.holdsKeys)
        #expect(Self.press(.open, run, pointer) == nil)
        #expect(!run.holdsKeys && run.keySnapshot == .none && run.phase == .open)
    }

    /// Once a jump has drained the panel, the panel opening again holds the keys again as the pointer moves on it.
    @Test func aHoldStartsAgainOnceAJumpHasDrainedAndThePanelReopens() throws {
        let (run, pointer) = try Self.holding(Self.shifts), setting = Self.setting()

        try #require(Self.press(.open, run, pointer) != nil)
        run.jumpAnswered(Self.at(run, pointer, setting))
        Self.frames(run, for: 3000, Self.away, setting) { run.phase == .closed }
        try #require(run.phase == .closed)

        Self.frames(run, for: 3000, Self.onTheNotch, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open && run.frame.panel?.pressed == nil)
        #expect(!run.holdsKeys)
        run.step(Self.at(run, try Self.words(Self.helpDesk, run, setting), setting))
        #expect(run.holdsKeys && run.keySnapshot == .panel(hold: 2))
    }

    /// `z` on a Needs you row, of asks or of a turn alone, offers the row's Snooze beside the row, which stands where
    /// the list draws it, on either edge.
    @Test(arguments: [(Self.helpDesk, false), (Self.turn, false), (Self.helpDesk, true)])
    func zOnANeedsYouRowOffersItsSnoozeBesideIt(_ key: String, right: Bool) throws {
        let setting = Self.setting(right: right), (run, pointer) = try Self.holding(key, setting)
        let row = try Self.laid(key, run)

        guard case let .snoozeRow(session, row: box)? = Self.press(.snooze, run, pointer, setting) else {
            Issue.record("z offered no snooze")
            return
        }

        let corner = try Self.onStage(right ? row.maxX : row.minX, row.minY, run, setting)

        #expect(Item.line(session).key == key)
        #expect(abs(box.minX - corner.x) < 0.01 && abs(box.minY - corner.y) < 0.01)
        #expect(abs(box.width - row.width) < 0.01 && abs(box.height - row.height) < 0.01)
    }

    @Test func zOnASnoozedRowWakesIt() throws {
        let (run, pointer) = try Self.holding(Self.snoozed)

        guard case let .wake(session)? = Self.press(.snooze, run, pointer) else {
            Issue.record("z did not wake")
            return
        }
        #expect(session.id == AsksBoard.helpDesk && session.isSnoozed)
    }

    @Test(arguments: [Self.ledger, Self.working])
    func zOnARowOfStopsAloneOrAWorkingOneDoesNothing(_ key: String) throws {
        let (run, pointer) = try Self.holding(key)

        #expect(Self.press(.snooze, run, pointer) == nil)
    }

    @Test func sFoldsSnoozedAndUnfoldsItAsAClickOnItsEyebrow() throws {
        let (run, pointer) = try Self.holding()

        #expect(Self.press(.fold, run, pointer) == .fold)
        #expect(run.folded.sections.contains(.snoozed))
        #expect(Self.press(.fold, run, pointer) == .fold)
        #expect(!run.folded.sections.contains(.snoozed))
    }

    /// A key of the set with no use at the moment is taken and does nothing.
    @Test(arguments: [PanelKey.left, .right, .ignore, .digit(1)])
    func aKeyWithNoUseOnTheListDoesNothing(_ key: PanelKey) throws {
        let (run, pointer) = try Self.holding()

        #expect(Self.press(key, run, pointer) == nil)
        #expect(Self.lit(run) == Self.helpDesk && run.asksShown == nil && run.phase == .open)
    }

    /// `esc` closes the panel, which stays closed with the pointer left on the notch, and opens again once it has left
    /// the notch and come back.
    @Test func escClosesThePanelWhichStaysClosedUntilThePointerLeavesTheNotchAndComesBack() throws {
        let run = Self.opened(), setting = Self.setting(), onIt = CGPoint(x: 4, y: Self.onTheNotch.y)

        run.step(Self.at(run, onIt, setting))
        try #require(run.holdsKeys)
        Self.press(.escape, run, onIt)
        Self.frames(run, for: 2000, onIt, setting)
        #expect(run.phase == .closed)

        Self.frames(run, for: 500, Self.away, setting)
        Self.frames(run, for: 2000, Self.onTheNotch, setting) { run.phase == .open }
        #expect(run.phase == .open)
    }

    // MARK: With the asks panel open

    @Test(arguments: [PanelKey.down, .up])
    func withTheAsksPanelOpenUpAndDownMoveTheLitRowAndCloseIt(_ key: PanelKey) throws {
        let (run, pointer) = try Self.holding(Self.shifts)
        let rows = Self.rows(run), at = try #require(rows.firstIndex(of: Self.shifts))

        Self.press(.enter, run, pointer)
        try #require(run.asksShown?.row == Self.shifts)
        #expect(Self.press(key, run, pointer) == .asks)
        #expect(run.asksShown == nil)
        #expect(Self.lit(run) == rows[at + (key == .down ? 1 : -1)])
    }

    @Test func withTheAsksPanelOpenEscClosesItAndThePanelStaysOpen() throws {
        let (run, pointer) = try Self.holding()

        Self.press(.enter, run, pointer)
        #expect(Self.press(.escape, run, pointer) == .asks)
        #expect(run.asksShown == nil)
        Self.frames(run, for: 500, pointer, Self.setting())
        #expect(run.phase == .open)
    }

    @Test(arguments: [PanelKey.open, .snooze, .fold, .ignore, .left, .right, .digit(1)])
    func withTheAsksPanelOpenEveryOtherKeyDoesNothing(_ key: PanelKey) throws {
        let (run, pointer) = try Self.holding()

        Self.press(.enter, run, pointer)
        #expect(Self.press(key, run, pointer) == nil)
        #expect(run.asksShown?.row == Self.helpDesk && run.asksShown?.page == 0)
        #expect(!run.folded.sections.contains(.snoozed))
        #expect(run.frame.panel?.pressed == nil)
    }

    /// Closed by a key with the pointer on it, the asks panel holds the panel as if the pointer rested there, until
    /// the pointer moves: off the list, the panel's grace starts and it closes; onto the list, it stays.
    @Test(arguments: [false, true])
    func closedByAKeyUnderThePointerTheAsksPanelHoldsThePanelUntilThePointerMoves(ontoTheList: Bool) throws {
        let (run, pointer) = try Self.holding(), setting = Self.setting()

        Self.press(.enter, run, pointer)

        let asks = try #require(run.asksShown)
        let onAsks = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.midY)

        run.step(Self.at(run, onAsks, setting))
        #expect(Self.press(.escape, run, onAsks) == .asks)
        Self.frames(run, for: 2000, onAsks, setting)
        #expect(run.phase == .open)
        #expect(run.holdsKeys)

        let next = ontoTheList ? pointer : CGPoint(x: onAsks.x - 2, y: onAsks.y)

        Self.frames(run, for: 2000, next, setting) { run.phase == .closed }
        #expect((run.phase == .open) == ontoTheList)
    }
}
