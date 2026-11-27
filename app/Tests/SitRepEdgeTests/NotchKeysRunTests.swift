import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The notch's panel's keys as its run has them (DESIGN, "Keys"): the panel holds them as the hover's panel comes open
/// with the pointer on its black, by the screen's edge as much as on the rows, or its asks panel, and once the pointer
/// moves on either, until the pointer moves off, a key it doesn't take lets go, or it closes; `↑` `↓` move a lit row
/// over the rows, past eyebrows and folded sections, scrolled into view, the pointer moving taking it back; and each
/// row key does what its click does: the arrow pointing away from the notch the row's arrow, the arrow back nothing,
/// `⏎` and `o` the words, `z` the row's Snooze or Wake now, `s` Snoozed's eyebrow, `esc` a click elsewhere. With the
/// asks panel open, `↑` `↓` move and close it, `esc` closes it, and closed by a key under the pointer, it holds the
/// panel until the pointer moves; its other keys are `AsksPanelKeysRunTests`'.
@Suite(.backstop)
struct NotchKeysRunTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)
    private static let frameMS = 1000.0 / 60
    private static let onTheNotch = CGPoint(x: 3, y: 491), away = CGPoint(x: 1300, y: 491)
    private static let helpDesk = "needs:\(AsksBoard.helpDesk)", shifts = "needs:\(AsksBoard.shifts)"
    private static let ledger = "needs:\(AsksBoard.ledger)", turn = "turn:sr-ts0004", working = "sr-wg0005"
    private static let snoozed = "snoozed:\(AsksBoard.helpDesk)"

    private static func setting(
        _ style: NotchStyle = .meniscus, right: Bool = false, takesKeys: Bool = true
    ) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: stage, mirror: right ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 800, ty: 0) : .identity,
            style: style, reducesMotion: false, takesKeys: takesKeys
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

    /// The arrow pointing away from the notch, `→` on the left edge and `←` on the right, and the one pointing back.
    private static func outward(_ setting: NotchRun.Setting) -> PanelKey {
        setting.mirror.a < 0 ? .left : .right
    }

    private static func back(_ setting: NotchRun.Setting) -> PanelKey {
        setting.mirror.a < 0 ? .right : .left
    }

    /// A key pressed, the pointer where it was, the hold the tap ended with it `ending`, as it ends one with `o`.
    @discardableResult
    private static func press(
        _ key: PanelKey, _ run: NotchRun, _ pointer: CGPoint, _ setting: NotchRun.Setting = setting(),
        ending: Int? = nil
    ) -> NotchRun.Press? {
        run.key(key, ending: ending, at(run, pointer, setting))
    }

    // MARK: The hold

    /// The hover that opened the panel holds the keys as it comes open, with no further move, the pointer resting on
    /// it: no row lit, and `↓` lights the first (Lee's decision, 27 November 2026).
    @Test func aPanelTheHoverOpenedHoldsTheKeysAsItComesOpen() throws {
        let run = Self.opened(), setting = Self.setting()

        #expect(run.phase == .open)
        Self.frames(run, for: 500, Self.onTheNotch, setting)
        #expect(run.holdsKeys && run.keySnapshot == .panel(hold: 1) && Self.lit(run) == nil)
        Self.press(.down, run, Self.onTheNotch)
        #expect(Self.lit(run) == Self.rows(run).first)

        run.step(Self.at(run, try Self.words(Self.helpDesk, run, setting), setting))
        #expect(run.keySnapshot == .panel(hold: 1))
    }

    /// A panel of one row the hover opened with the pointer on the notch's strip past the black's end, off the black,
    /// holds nothing as it comes open, in either style, until the pointer moves onto it.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func aPanelComingOpenWithThePointerOffItsBlackHoldsNothing(style: NotchStyle) throws {
        let setting = Self.setting(style), board = AsksBoard.board(alone: true)
        let off = try PanelBlack.end(top: true, of: Self.opened(setting, board: board).frame, inset: -2)
        let run = NotchRun(at: 1000, in: setting, folding: Folding())

        _ = run.show(board, Self.at(run, nil, setting))
        Self.frames(run, for: 3000, off, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open && !run.frame.shape.contains(off))
        #expect(!run.holdsKeys && Self.press(.down, run, off, setting) == nil)

        run.step(Self.at(run, CGPoint(x: off.x, y: off.y + 5), setting))
        #expect(run.holdsKeys)
    }

    /// A move on the black by the screen's edge, at either end, holds the keys as one on the rows does, on either edge
    /// and in either style, the Meniscus's flares as much as the rows' clip: it lights no row, and `↓` lights the
    /// first.
    @Test(arguments: [NotchStyle.meniscus, .card], [false, true])
    func aMoveOnTheBlackByTheScreensEdgeHoldsTheKeys(style: NotchStyle, right: Bool) throws {
        let setting = Self.setting(style, right: right)

        for top in [true, false] {
            let run = Self.opened(setting), margin = try PanelBlack.end(top: top, of: run.frame, inset: 3)

            if style == .meniscus {
                try #require(run.frame.panel?.contains(margin) == false, "not past the rows' clip")
            }
            run.step(Self.at(run, margin, setting))
            #expect(run.holdsKeys && Self.lit(run, setting) == nil)
            Self.press(.down, run, margin, setting)
            #expect(Self.lit(run, setting) == Self.rows(run).first)
        }
    }

    /// A move just off the black's end by the screen's edge holds nothing, in either style.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func aMoveJustOffTheBlackHoldsNothing(style: NotchStyle) throws {
        let setting = Self.setting(style)

        for top in [true, false] {
            let run = Self.opened(setting), off = try PanelBlack.end(top: top, of: run.frame, inset: -3)

            run.step(Self.at(run, off, setting))
            #expect(!run.holdsKeys && run.keySnapshot == .none)
            #expect(Self.press(.down, run, off, setting) == nil)
        }
    }

    /// A panel of one row the hover opened under a pointer resting where the black's end by the screen's edge comes to
    /// lie, the Meniscus's flare past the rows' clip, holds the keys as it comes open, in either style.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func aPanelComingOpenUnderAPointerRestingOnTheBlacksEndHoldsTheKeys(style: NotchStyle) throws {
        let setting = Self.setting(style), board = AsksBoard.board(alone: true)
        let margin = try PanelBlack.end(top: true, of: Self.opened(setting, board: board).frame, inset: 3)
        let run = NotchRun(at: 1000, in: setting, folding: Folding())

        _ = run.show(board, Self.at(run, nil, setting))
        Self.frames(run, for: 3000, margin, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open && run.frame.shape.contains(margin))
        if style == .meniscus {
            try #require(run.frame.panel?.contains(margin) == false, "not past the rows' clip")
        }
        #expect(run.holdsKeys)
        Self.press(.down, run, margin, setting)
        #expect(Self.lit(run, setting) == Self.rows(run).first)
    }

    /// A run over the asks' board, its panel opened by the pointer held against the screen's edge on the notch, at x =
    /// 0 as AppKit gives it there, and at rest under it, with no event since.
    private static func openedAgainstTheEdge(_ setting: NotchRun.Setting) -> (run: NotchRun, pinned: CGPoint) {
        let run = NotchRun(at: 1000, in: setting, folding: Folding())
        let pinned = CGPoint(x: 0, y: setting.stage.notchY)

        _ = run.show(AsksBoard.board(), at(run, nil, setting))
        frames(run, for: 3000, pinned, setting) { run.phase == .open && !run.frame.isMoving }
        return (run, pinned)
    }

    /// Lee's path, 27 November 2026: the hover onto the notch against the screen's edge opens the panel, the pointer
    /// resting there through the pour with no event since, and `↓` lights the first row. On either edge, in either
    /// style, with motion or without.
    @Test(arguments: [
        (NotchStyle.meniscus, false, false), (.meniscus, true, false), (.meniscus, false, true), (.meniscus, true, true),
        (.card, false, false), (.card, true, false), (.card, false, true), (.card, true, true),
    ])
    func theHoverAgainstTheScreensEdgeHoldsTheKeys(style: NotchStyle, right: Bool, reducesMotion: Bool) throws {
        var setting = Self.setting(style, right: right)

        setting.reducesMotion = reducesMotion

        let (run, pinned) = Self.openedAgainstTheEdge(setting)

        try #require(run.phase == .open)
        #expect(run.holdsKeys && Self.lit(run, setting) == nil)
        Self.press(.down, run, pinned, setting)
        #expect(Self.lit(run, setting) == Self.rows(run).first)
    }

    /// The pointer leaves, and comes back onto the notch against the screen's edge as the panel goes in, stopping
    /// there: the hover reopening it holds the keys as it comes open, in either style, with motion or without.
    @Test(arguments: [NotchStyle.meniscus, .card], [false, true])
    func aHoverReopeningThePanelAsItGoesInHoldsTheKeys(style: NotchStyle, reducesMotion: Bool) throws {
        var setting = Self.setting(style)

        setting.reducesMotion = reducesMotion

        let (run, pinned) = Self.openedAgainstTheEdge(setting)

        Self.frames(run, for: 3000, Self.away, setting) { run.phase == .closing }
        Self.frames(run, for: 50, Self.away, setting)
        try #require(run.phase == .closing)
        Self.frames(run, for: 3000, pinned, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open)
        #expect(run.holdsKeys)
        Self.press(.down, run, pinned, setting)
        #expect(Self.lit(run, setting) == Self.rows(run).first)
    }

    /// The keys let go as the hover's panel pours, as the screens sleep or a window takes secure input: it comes open
    /// holding nothing, the pointer resting, until the pointer moves.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func aLetGoAsThePanelPoursForgetsTheHover(style: NotchStyle) throws {
        let setting = Self.setting(style), run = NotchRun(at: 1000, in: setting, folding: Folding())
        let pinned = CGPoint(x: 0, y: setting.stage.notchY)

        _ = run.show(AsksBoard.board(), Self.at(run, nil, setting))
        Self.frames(run, for: 3000, pinned, setting) { run.phase == .opening }
        try #require(run.phase == .opening)
        run.letGoOfKeys(Self.at(run, pinned, setting))
        Self.frames(run, for: 3000, pinned, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open)
        #expect(!run.holdsKeys)

        run.pointerMoved()
        run.step(Self.at(run, pinned, setting))
        #expect(run.holdsKeys)
    }

    /// A new ask's swell growing the notch over a pointer parked beside it for longer than `NotchRun.hoverWindow`
    /// opens the panel, as the notch does, but no hover opened it: it holds nothing until the pointer moves, and a move
    /// then holds. The Card, with motion or without, and the Meniscus without, whose tongue would reach the pointer
    /// first.
    @Test(arguments: [(NotchStyle.card, false), (.card, true), (.meniscus, true)])
    func aSwellOpeningThePanelUnderAParkedPointerHoldsNothingUntilItMoves(look: (NotchStyle, Bool)) throws {
        var setting = Self.setting(look.0)

        setting.reducesMotion = look.1

        let parked = CGPoint(x: 3, y: setting.stage.notchY + 55), run = NotchRun(at: 1000, in: setting)
        var last = LastBoard()

        _ = last.hear(.line(allClearLine), at: Date())
        _ = run.show(PanelBoard(last), Self.at(run, Self.away, setting))
        Self.frames(run, for: 500, Self.away, setting)
        Self.frames(run, for: 2000, parked, setting)
        try #require(run.phase == .closed)

        _ = run.show(AsksBoard.board(), Self.at(run, parked, setting))
        Self.frames(run, for: 3000, parked, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open && run.frame.shape.contains(parked), "the swell opened the panel")
        #expect(!run.holdsKeys)

        run.step(Self.at(run, CGPoint(x: parked.x, y: parked.y + 1), setting))
        #expect(run.holdsKeys)
    }

    /// A key the panel doesn't take lets the hover's hold go with the pointer resting against the screen's edge, and
    /// the pointer pushed on against the edge, a move the Mac hears that leaves it where it was felt, holds the keys
    /// again.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func aPushAgainstTheScreensEdgeHoldsTheKeysAgainAfterALetGo(style: NotchStyle) throws {
        let setting = Self.setting(style), (run, pinned) = Self.openedAgainstTheEdge(setting)

        try #require(run.holdsKeys)
        run.letGoOfKeys(in: 1, Self.at(run, pinned, setting))
        Self.frames(run, for: 500, pinned, setting)
        #expect(!run.holdsKeys)

        run.pointerMoved()
        run.step(Self.at(run, pinned, setting))
        #expect(run.keySnapshot == .panel(hold: 2) && Self.lit(run, setting) == nil)
    }

    /// Small moves along the screen's edge, x from 0 to 4, at the notch's height and at a row's, each hold the keys,
    /// and `↓` lights the first row, on either edge, in either style.
    @Test(arguments: [NotchStyle.meniscus, .card], [false, true])
    func smallMovesAlongTheScreensEdgeHoldTheKeys(style: NotchStyle, right: Bool) throws {
        let setting = Self.setting(style, right: right)
        let rowY = try Self.words(Self.shifts, Self.opened(setting), setting).y

        for y in [setting.stage.notchY, rowY] {
            for x in [0.0, 1, 2, 4] {
                let (run, pinned) = Self.openedAgainstTheEdge(setting), along = CGPoint(x: x, y: y + 2)

                try #require(run.phase == .open && along != pinned)
                run.step(Self.at(run, along, setting))
                #expect(run.holdsKeys, "x \(x), y \(y)")
                Self.press(.down, run, along, setting)
                #expect(Self.lit(run, setting) == Self.rows(run).first, "x \(x), y \(y)")
            }
        }
    }

    @Test func movingOnTheAsksPanelHoldsTheKeysToo() throws {
        let run = Self.opened(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.arrow(Self.helpDesk, run, setting), setting)) == .asks)
        run.letGoOfKeys(in: 1, Self.at(run, try Self.arrow(Self.helpDesk, run, setting), setting))

        let asks = try #require(run.asksShown)

        run.step(Self.at(run, CGPoint(x: asks.frame.maxX - 40, y: asks.frame.midY), setting))
        #expect(run.holdsKeys)
    }

    /// The hold ends as the pointer moves off the black and the asks panel, before the panel's grace closes it, so a
    /// key typed meanwhile goes to the window in front: the tongue the open edge stretches after the pointer is no
    /// part of the black.
    @Test func aMoveOffThePanelEndsTheHoldAtOnce() throws {
        var (run, pointer) = try Self.holding()
        let setting = Self.setting(), onBlack = { run.frame.shape.contains(pointer) }

        while onBlack() {
            pointer.x += 2
            run.step(Self.at(run, pointer, setting))
            #expect(run.holdsKeys == onBlack())
        }
        #expect(run.frame.outline.contains(pointer), "no tongue under the pointer")
        #expect(run.phase == .open)
        #expect(run.keySnapshot == .none)
    }

    /// Leaving back over a flare into the bezel starts the grace, and coming back into the flare before it ends is
    /// coming back onto the panel: it stays open, and the keys are held again.
    @Test func comingBackIntoAFlareBeforeTheGraceEndsKeepsThePanelOpen() throws {
        let run = Self.opened(), setting = Self.setting()
        let margin = try PanelBlack.end(top: true, of: run.frame, inset: 3)
        let off = try PanelBlack.end(top: true, of: run.frame, inset: -3)

        run.step(Self.at(run, margin, setting))
        Self.frames(run, for: 50, off, setting)
        Self.frames(run, for: 2000, margin, setting)
        #expect(run.phase == .open && run.holdsKeys)
    }

    /// It lets the row the keys lit go too, the pointer's row lit again.
    @Test func aKeyThePanelDoesntTakeLetsGoUntilThePointerMovesAgain() throws {
        let (run, pointer) = try Self.holding(), setting = Self.setting()

        Self.press(.down, run, pointer)
        try #require(Self.lit(run) != Self.helpDesk)
        run.letGoOfKeys(in: 1, Self.at(run, pointer, setting))
        #expect(run.keySnapshot == .none && Self.lit(run) == Self.helpDesk)
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

    /// The arrow pointing away from the notch, `→` on the left edge and `←` on the right, opens the lit row's asks
    /// panel at its first ask, as a click on the row's arrow does, though it was paged on and closed before.
    @Test(arguments: [false, true])
    func theOutwardArrowOpensTheRowsAsksPanelAtItsFirstAskAsAClickOnItsArrowDoes(right: Bool) throws {
        let setting = Self.setting(right: right), (run, pointer) = try Self.holding(Self.helpDesk, setting)
        let clicked = Self.opened(setting), arrow = try Self.arrow(Self.helpDesk, clicked, setting)

        #expect(Self.press(Self.outward(setting), run, pointer, setting) == .asks)
        #expect(run.asksShown?.row == Self.helpDesk && run.asksShown?.page == 0)
        #expect(Self.press(Self.outward(setting), run, pointer, setting) == .asks)
        try #require(run.asksShown?.page == 1)
        #expect(Self.press(.escape, run, pointer, setting) == .asks && run.asksShown == nil)
        #expect(Self.press(Self.outward(setting), run, pointer, setting) == .asks)
        #expect(run.asksShown?.row == Self.helpDesk && run.asksShown?.page == 0)

        #expect(clicked.press(Self.at(clicked, arrow, setting)) == .asks)
        #expect(clicked.asksShown?.row == Self.helpDesk && clicked.asksShown?.page == 0)
    }

    /// The arrow pointing back toward the notch has no use on the list: taken, it does nothing, on either edge.
    @Test(arguments: [false, true])
    func theArrowBackDoesNothingOnTheList(right: Bool) throws {
        let setting = Self.setting(right: right), (run, pointer) = try Self.holding(Self.helpDesk, setting)

        #expect(Self.press(Self.back(setting), run, pointer, setting) == nil)
        #expect(run.asksShown == nil && Self.lit(run, setting) == Self.helpDesk && run.phase == .open)
    }

    @Test(arguments: [Self.ledger, Self.turn, Self.working, Self.snoozed], [false, true])
    func theOutwardArrowOnARowWithNoArrowDoesNothing(_ key: String, right: Bool) throws {
        let setting = Self.setting(right: right), (run, pointer) = try Self.holding(key, setting)

        #expect(Self.press(Self.outward(setting), run, pointer, setting) == nil)
        #expect(run.asksShown == nil)
        #expect(run.phase == .open)
    }

    /// `⏎` and `o` jump as a click on the row's words: the row pressed in, the jump asked for.
    @Test(arguments: [PanelKey.open, .enter], [false, true])
    func returnAndOJumpAsAClickOnTheRowsWords(_ key: PanelKey, right: Bool) throws {
        let setting = Self.setting(right: right), (run, pointer) = try Self.holding(Self.shifts, setting)

        guard case let .jump(session, to: target, click: click)? = Self.press(key, run, pointer, setting, ending: 1)
        else {
            Issue.record("\(key) did not jump")
            return
        }
        #expect(session.id == AsksBoard.shifts && target == AsksBoard.shifts && click == 1)
        run.step(Self.at(run, pointer, setting))
        #expect(run.frame.panel?.pressed == Self.shifts)
    }

    /// A jump ends the hold, the row the keys lit let go, and no hold starts while it is under way, the pointer moving
    /// on the list or not: `→` after `⏎` is for the window jumped to, not the panel draining.
    @Test(arguments: [nil, PanelKey.open, .enter])
    func aJumpEndsTheHoldAndNoneStartsWhileItIsUnderWay(byKey: PanelKey?) throws {
        var (run, pointer) = try Self.holding(Self.shifts)
        let setting = Self.setting()

        Self.press(.down, run, pointer)
        #expect(Self.lit(run) != Self.shifts)
        let jump = byKey.map { Self.press($0, run, pointer, ending: 1) } ?? run.press(Self.at(run, pointer, setting))
        #expect(jump != nil)
        #expect(!run.holdsKeys && run.keySnapshot == .none && Self.lit(run) == Self.shifts)

        run.step(Self.at(run, pointer, setting))
        #expect(run.frame.panel?.pressed != nil)
        for _ in 0 ..< 120 where run.frame.panel?.pressed != nil {
            pointer.y += 1
            run.step(Self.at(run, pointer, setting))
            #expect(run.keySnapshot == .none)
            #expect(Self.press(.right, run, pointer) == nil && run.asksShown == nil)
        }
    }

    /// `⏎` or `o` with no row lit jumps nowhere and still ends the hold, as the tap ended it as it took the key.
    @Test(arguments: [PanelKey.open, .enter])
    func returnOrOEndsTheHoldThoughItJumpsNowhere(_ key: PanelKey) throws {
        let run = Self.opened(), setting = Self.setting(), eyebrow = run.list.content.laidFrame(0)
        let pointer = try Self.onStage(60, eyebrow.midY, run, setting)

        run.step(Self.at(run, pointer, setting))
        try #require(run.holdsKeys)
        #expect(Self.press(key, run, pointer, ending: 1) == nil)
        #expect(!run.holdsKeys && run.keySnapshot == .none && run.phase == .open)
    }

    /// The tap alone decides whether a key ends the hold: one it ended goes as the panel hears it, the key acting or
    /// not, as while a menu holds the card; one it didn't end stays, `o` and `⏎` among them.
    @Test(arguments: [PanelKey.open, .enter])
    func theHoldEndsAsTheTapEndedIt(_ key: PanelKey) throws {
        let (run, pointer) = try Self.holding()

        run.menuOpened(at: pointer)
        #expect(Self.press(key, run, pointer, ending: 1) == nil)
        #expect(!run.holdsKeys && run.keySnapshot == .none)
        run.menuClosed()

        let kept = Self.opened(), setting = Self.setting(), eyebrow = kept.list.content.laidFrame(0)
        let onEyebrow = try Self.onStage(60, eyebrow.midY, kept, setting)

        kept.step(Self.at(kept, onEyebrow, setting))
        #expect(Self.press(key, kept, onEyebrow) == nil)
        #expect(kept.holdsKeys && kept.keySnapshot == .panel(hold: 1))
    }

    /// Once a jump has drained the panel, the hover opening it again holds the keys again as it comes open.
    @Test func aHoldStartsAgainOnceAJumpHasDrainedAndThePanelReopens() throws {
        let (run, pointer) = try Self.holding(Self.shifts), setting = Self.setting()

        try #require(Self.press(.open, run, pointer, ending: 1) != nil)
        run.jumpAnswered(Self.at(run, pointer, setting))
        Self.frames(run, for: 3000, Self.away, setting) { run.phase == .closed }
        try #require(run.phase == .closed)

        Self.frames(run, for: 3000, Self.onTheNotch, setting) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open && run.frame.panel?.pressed == nil)
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
    @Test(arguments: [PanelKey.ignore, .digit(1)])
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

        Self.press(.right, run, pointer)
        try #require(run.asksShown?.row == Self.shifts)
        #expect(Self.press(key, run, pointer) == .asks)
        #expect(run.asksShown == nil)
        #expect(Self.lit(run) == rows[at + (key == .down ? 1 : -1)])
    }

    @Test func withTheAsksPanelOpenEscClosesItAndThePanelStaysOpen() throws {
        let (run, pointer) = try Self.holding()

        Self.press(.right, run, pointer)
        #expect(Self.press(.escape, run, pointer) == .asks)
        #expect(run.asksShown == nil)
        Self.frames(run, for: 500, pointer, Self.setting())
        #expect(run.phase == .open)
    }

    /// The arrow pointing back, on the asks panel's first ask, closes it as a menu's `←` closes its submenu, its row
    /// left lit though the pointer is on the asks panel, on either edge; the outward arrow opens it again.
    @Test(arguments: [false, true])
    func theArrowBackFromTheFirstAskClosesTheAsksPanelItsRowLeftLit(right: Bool) throws {
        let setting = Self.setting(right: right), (run, pointer) = try Self.holding(Self.helpDesk, setting)

        Self.press(Self.outward(setting), run, pointer, setting)

        let asks = try #require(run.asksShown), onAsks = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.midY)

        run.step(Self.at(run, onAsks, setting))
        try #require(run.holdsKeys && run.asksShown?.page == 0)
        #expect(Self.press(Self.back(setting), run, onAsks, setting) == .asks)
        #expect(run.asksShown == nil && run.phase == .open && run.holdsKeys)
        #expect(Self.lit(run, setting) == Self.helpDesk)
        #expect(Self.press(Self.outward(setting), run, onAsks, setting) == .asks)
        #expect(run.asksShown?.row == Self.helpDesk)
    }

    /// Closed by a key with the pointer on it, `esc` or the arrow back from the first ask, the asks panel holds the
    /// panel as if the pointer rested there, until the pointer moves: off the list, the panel's grace starts and it
    /// closes; onto the list, it stays.
    @Test(arguments: [PanelKey.escape, .left], [false, true])
    func closedByAKeyUnderThePointerTheAsksPanelHoldsThePanelUntilThePointerMoves(
        _ key: PanelKey, ontoTheList: Bool
    ) throws {
        let (run, pointer) = try Self.holding(), setting = Self.setting()

        Self.press(.right, run, pointer)

        let asks = try #require(run.asksShown)
        let onAsks = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.midY)

        run.step(Self.at(run, onAsks, setting))
        #expect(Self.press(key, run, onAsks) == .asks)
        Self.frames(run, for: 2000, onAsks, setting)
        #expect(run.phase == .open)
        #expect(run.holdsKeys)

        let next = ontoTheList ? pointer : CGPoint(x: onAsks.x - 2, y: onAsks.y)

        Self.frames(run, for: 2000, next, setting) { run.phase == .closed }
        #expect((run.phase == .open) == ontoTheList)
    }
}
