import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The row's arrow and the asks panel as the notch's run has them (DESIGN, "Answering from the panel"): the arrow on a
/// Needs you row with an ask the panel answers, lit on itself; a press on it opening the asks panel beside the row,
/// moving it to another, closing it from the lit one, a press on the row's words still jumping; the asks panel level
/// with its row past the list's front, read left to right on either edge, holding the panel open while the pointer is
/// on it; its answers held, taken back and gone, stepping to the session's next ask and closing after the last; and an
/// ask leaving the board leaving it.
@Suite(.backstop)
struct AsksPanelRunTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)
    private static let frameMS = 1000.0 / 60
    private static let onTheNotch = CGPoint(x: 3, y: 491), away = CGPoint(x: 1300, y: 491)
    private static let helpDesk = "needs:\(AsksBoard.helpDesk)", shifts = "needs:\(AsksBoard.shifts)"

    private static func setting(right: Bool = false, style: NotchStyle = .meniscus) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: stage, mirror: right ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 800, ty: 0) : .identity,
            style: style, reducesMotion: false, isChosen: true
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

    /// A run over the asks' board, Snoozed unfolded, its panel opened by the pointer held on the notch, and at rest.
    private static func opened(
        _ setting: NotchRun.Setting = setting(), board: PanelBoard = AsksBoard.board()
    ) -> NotchRun {
        let folding = Folding()

        folding.set(.snoozed, folded: false)

        let run = NotchRun(at: 1000, in: setting, folding: folding)

        _ = run.show(board, at(run, nil, setting))
        frames(run, for: 3000, onTheNotch, setting) { run.phase == .open && !run.frame.isMoving }
        return run
    }

    /// A point on the content, on the stage: through the edge's mirror, the content reading left to right on either.
    private static func onStage(
        _ x: Double, _ y: Double, _ run: NotchRun, _ setting: NotchRun.Setting
    ) throws -> CGPoint {
        let panel = try #require(run.frame.panel)

        return CGPoint(
            x: setting.mirror.a < 0 ? panel.frame.maxX - x : panel.frame.minX + x,
            y: panel.frame.minY + y - run.scroll
        )
    }

    /// Where a row lays out what it draws, at its own height, in the content's own frame.
    private static func row(_ key: String, _ run: NotchRun) throws -> CGRect {
        let index = try #require(run.list.index(of: key), "no row \(key)")

        return run.list.content.laidFrame(index)
    }

    /// The middle of a row's arrow, where it has one, or where it would.
    private static func arrow(
        _ key: String, _ run: NotchRun, _ setting: NotchRun.Setting = setting()
    ) throws -> CGPoint {
        let row = try row(key, run), box = RowArrow.box(in: row.size)

        return try onStage(row.minX + box.midX, row.minY + box.midY, run, setting)
    }

    /// A row's words, near its left.
    private static func words(
        _ key: String, _ run: NotchRun, _ setting: NotchRun.Setting = setting()
    ) throws -> CGPoint {
        let row = try row(key, run)

        return try onStage(row.minX + 60, row.midY, run, setting)
    }

    /// The middle of a part of the asks panel as it shows, on the stage, through the edge's mirror.
    private static func part(
        _ part: AsksPart, _ run: NotchRun, _ setting: NotchRun.Setting = setting()
    ) throws -> CGPoint {
        let asks = try #require(run.asksShown)
        let layout = asks.layout
        let box: CGRect? = switch part {
        case let .answer(row): layout.answers[row]
        case .inClaude: layout.answers[0]
        case .ignore: layout.ignore
        case .snooze: layout.snooze
        case .open: layout.open
        case .undo: layout.undo
        }
        let own = try #require(box)

        return CGPoint(
            x: setting.mirror.a < 0 ? asks.frame.maxX - own.midX : asks.frame.minX + own.midX,
            y: asks.frame.minY + own.midY
        )
    }

    /// The run with the asks panel opened from a row's arrow, the pointer still on the arrow.
    private static func asksOpen(
        _ key: String = helpDesk, _ setting: NotchRun.Setting = setting(), board: PanelBoard = AsksBoard.board()
    ) throws -> NotchRun {
        let run = opened(setting, board: board)

        #expect(run.press(at(run, try arrow(key, run, setting), setting)) == .asks)
        return run
    }

    /// A point on the asks panel as it shows, this far in from its far side and down from its top.
    private static func onAsks(_ run: NotchRun, in x: Double = 40, down y: Double? = nil) throws -> CGPoint {
        let asks = try #require(run.asksShown)

        return CGPoint(x: asks.frame.maxX - x, y: y.map { asks.frame.minY + $0 } ?? asks.frame.midY)
    }

    /// How long, ms, the panel stays open after the pointer leaves it at this point, moving on at `speed`, pt/ms,
    /// across the screen, the pointer having come there at that speed: nil where it stays open 2 seconds.
    private static func open(
        _ run: NotchRun, leaving from: CGPoint, at speed: Double, _ setting: NotchRun.Setting
    ) -> Double? {
        var point = CGPoint(x: from.x - 40, y: from.y)

        while point.x < from.x {
            point.x += speed * frameMS
            run.step(at(run, point, setting))
        }

        let left = run.time

        while run.time - left < 2000, run.phase == .open {
            point.x += speed * frameMS
            run.step(at(run, point, setting))
        }
        return run.phase == .open ? nil : run.time - left
    }

    private static func held(_ answering: Answering) -> AnswerNews {
        let now = Date(timeIntervalSince1970: Double(AsksBoard.at) / 1000)

        return .held(HeldAnswer(answering: answering, heldAt: now, goesAt: now.addingTimeInterval(2)))
    }

    private static let threaded = Answering(.words("Threaded"), to: "k1", of: AsksBoard.helpDesk)
    private static let approve = Answering(.words("Approve"), to: "k2", of: AsksBoard.helpDesk)

    // MARK: The row's arrow

    @Test func aRowWithAnAskTheAsksPanelAnswersShowsItsArrowUnderThePointerLitOnTheArrow() throws {
        let run = Self.opened(), setting = Self.setting()

        run.step(Self.at(run, try Self.words(Self.helpDesk, run), setting))
        #expect(run.arrows(in: setting) == [Self.helpDesk: false])
        run.step(Self.at(run, try Self.arrow(Self.helpDesk, run), setting))
        #expect(run.arrows(in: setting) == [Self.helpDesk: true])
        run.step(Self.at(run, try Self.words(Self.shifts, run), setting))
        #expect(run.arrows(in: setting) == [Self.shifts: false])
    }

    /// A row of a permission prompt alone, Lee's turn's, a working one's and Snoozed's, though its session has asks the
    /// asks panel answers in Needs you: no arrow, and a press where it would be jumps, as it did.
    @Test(arguments: ["needs:sr-fb0003", "turn:sr-ts0004", "sr-wg0005", "snoozed:\(AsksBoard.helpDesk)"])
    func noOtherRowHasAnArrow(_ key: String) throws {
        let run = Self.opened(), setting = Self.setting(), there = try Self.arrow(key, run)

        run.step(Self.at(run, there, setting))
        #expect(run.arrows(in: setting).isEmpty)
        guard case .jump? = run.press(Self.at(run, there, setting)) else {
            Issue.record("a press on \(key)'s time did not jump")
            return
        }
    }

    // MARK: Opening and closing

    @Test func aPressOnTheArrowOpensTheAsksPanelAndOnTheWordsJumps() throws {
        let run = try Self.asksOpen(), setting = Self.setting()
        let asks = try #require(run.asksShown)

        #expect(asks.row == Self.helpDesk && asks.ask.id == "k1" && asks.page == 0 && asks.pages == 2)
        #expect(run.arrows(in: setting)[Self.helpDesk] == true)

        let jumping = Self.opened()

        guard case let .jump(session, to: _, click: _)? = jumping.press(
            Self.at(jumping, try Self.words(Self.helpDesk, jumping), setting)
        ) else {
            Issue.record("a press on the row's words did not jump")
            return
        }
        #expect(session.id == AsksBoard.helpDesk)
        #expect(jumping.asksShown == nil)
    }

    @Test func anotherRowsArrowMovesItAndTheLitArrowClosesIt() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.arrow(Self.shifts, run), setting)) == .asks)
        #expect(run.asksShown?.row == Self.shifts)
        #expect(run.press(Self.at(run, try Self.arrow(Self.shifts, run), setting)) == .asks)
        #expect(run.asksShown == nil)
        #expect(run.phase == .open)
    }

    /// Beside the list, overlapping its front by 8, its top 12 above its row's, so its top line is level with the row.
    @Test func itStandsBesideTheListLevelWithItsRow() throws {
        let run = try Self.asksOpen()
        let asks = try #require(run.asksShown), panel = try #require(run.frame.panel)
        let row = try Self.row(Self.helpDesk, run)

        #expect(asks.frame.minX == panel.frame.maxX - CGFloat(AsksLayout.overlap))
        #expect(asks.frame.width == CGFloat(AsksLayout.width))
        #expect(asks.frame.minY == panel.frame.minY + row.minY - CGFloat(run.scroll + AsksLayout.above))
        #expect(Double(asks.frame.height) == asks.layout.height)
    }

    /// Over the list's front, the asks panel is on top: a press, a right-click and the pointer there are its own.
    @Test func whereItOverlapsTheListItIsOnTop() throws {
        let run = try Self.asksOpen(), setting = Self.setting()
        let asks = try #require(run.asksShown)
        let overlap = CGPoint(x: asks.frame.minX + 4, y: asks.frame.midY)

        #expect(run.frame.panel?.contains(overlap) == true)
        #expect(run.hits(overlap))
        #expect(run.item(at: overlap, in: setting) == nil && run.row(at: overlap, in: setting) == nil)
        #expect(run.hits(CGPoint(x: asks.frame.maxX - 30, y: asks.frame.midY)))
    }

    @Test(arguments: [NotchStyle.meniscus, .card], [false, true])
    func itHoldsThePanelOpenWhileThePointerIsOnItAndLeavingBothClosesBoth(_ style: NotchStyle, right: Bool) throws {
        let setting = Self.setting(right: right, style: style), run = try Self.asksOpen(Self.helpDesk, setting)
        let onIt = try Self.onAsks(run)

        Self.frames(run, for: 4000, onIt, setting)
        #expect(run.phase == .open)
        #expect(run.asksShown != nil)

        Self.frames(run, for: 5000, Self.away, setting) { run.phase == .closed }
        #expect(run.phase == .closed)
        #expect(run.asksShown == nil)
    }

    // MARK: Answering

    @Test func anAnswersRowAndIgnoreHoldTheirAnswersAndAWordsAskJumpsFromItsRow() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.answer(0), run), setting)) == .answer(Self.threaded))
        #expect(
            run.press(Self.at(run, try Self.part(.ignore, run), setting))
                == .answer(Answering(.ignore, to: "k1", of: AsksBoard.helpDesk))
        )

        let words = try Self.asksOpen(Self.shifts)
        let asks = try #require(words.asksShown)

        #expect(asks.layout.open == nil && asks.layout.answers.count == 1)
        guard case let .jump(session, to: _, click: _)? = words.press(
            Self.at(words, try Self.part(.inClaude, words), setting)
        ) else {
            Issue.record("Answer in Claude did not jump")
            return
        }
        #expect(session.id == AsksBoard.shifts)
        #expect(words.asksShown == nil)
    }

    @Test func openInClaudeJumpsAsTheRowDoesPressingItIn() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        guard case let .jump(session, to: target, click: click)? = run.press(
            Self.at(run, try Self.part(.open, run), setting)
        ) else {
            Issue.record("Open in Claude did not jump")
            return
        }
        #expect(session.id == AsksBoard.helpDesk && target == AsksBoard.helpDesk && click == 1)
        run.step(Self.at(run, nil, setting))
        #expect(run.frame.panel?.pressed == Self.helpDesk)
        #expect(run.asksShown == nil)
    }

    @Test func snoozeOffersTheRowsSessionsSnooze() throws {
        let run = try Self.asksOpen(), setting = Self.setting(), there = try Self.part(.snooze, run)

        guard case let .snooze(session, at: point)? = run.press(Self.at(run, there, setting)) else {
            Issue.record("Snooze offered nothing")
            return
        }
        #expect(session.id == AsksBoard.helpDesk && point == there)
        run.closeAsks(Self.at(run, there, setting))
        #expect(run.asksShown == nil)
    }

    /// Held, the answer shows sending, its Undo taking a press at once; no other answer is taken meanwhile.
    @Test func aHeldAnswerSendsUntilUndoneAndTheAsksPanelTakesNoOther() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))

        let sending = try #require(run.asksShown?.sending)

        #expect(sending.row == 0 && sending.words == "Threaded" && sending.goesAt - sending.heldAt == 2000)
        #expect(run.press(Self.at(run, try Self.part(.answer(1), run), setting)) == nil)
        #expect(run.press(Self.at(run, try Self.part(.undo, run), setting)) == .undo)

        run.heard(.undone(Self.threaded), Self.at(run, nil, setting))
        #expect(run.asksShown?.sending == nil)
        #expect(run.asksShown?.ask.id == "k1")
    }

    @Test func onceAnAnswerGoesItStepsToTheNextAskAndClosesAfterTheLast() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))
        run.heard(.went(Self.threaded), Self.at(run, nil, setting))

        let next = try #require(run.asksShown)

        #expect(next.ask.id == "k2" && next.page == 0 && next.pages == 1 && next.sending == nil)

        run.heard(.went(Self.approve), Self.at(run, nil, setting))
        #expect(run.asksShown == nil)
        #expect(run.phase == .open)
    }

    @Test func anAnswerTheCLIRefusesIsBackOnTheAsksPanel() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(.went(Self.threaded), Self.at(run, nil, setting))
        run.heard(.ended(Self.threaded, .refused("k1 is answered")), Self.at(run, nil, setting))

        #expect(run.asksShown?.pages == 2)
    }

    @Test func anAskLeavingTheBoardLeavesItAndItClosesWithNoneLeft() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        _ = run.show(AsksBoard.board(without: ["k1"]), Self.at(run, nil, setting))
        #expect(run.asksShown?.ask.id == "k2")
        #expect(run.asksShown?.pages == 1)

        _ = run.show(AsksBoard.board(without: ["k1", "k2"]), Self.at(run, nil, setting))
        #expect(run.asksShown == nil)
    }

    /// While an answer is held, the asks panel takes no other: no answer's row nor Ignore lights under the pointer,
    /// and Undo does.
    @Test func whileAnAnswerIsHeldNoAnswerNorIgnoreLights() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.step(Self.at(run, try Self.part(.answer(1), run), setting))
        #expect(run.asksShown?.hover == .answer(1))

        run.heard(Self.held(Self.threaded), Self.at(run, try Self.part(.answer(1), run), setting))
        #expect(run.asksShown?.hover == nil)
        run.step(Self.at(run, try Self.part(.undo, run), setting))
        #expect(run.asksShown?.hover == .undo)
    }

    /// Straight after it opens, a press on an answer is taken: nothing of it sat under the pointer before.
    @Test func aPressStraightAfterItOpensIsTaken() throws {
        let run = Self.opened(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.arrow(Self.helpDesk, run), setting)) == .asks)
        #expect(run.press(Self.at(run, try Self.part(.answer(0), run), setting)) == .answer(Self.threaded))
    }

    /// For a beat after the ask it shows changes, a press on it is let go: one meant for Threaded, as that answer
    /// went, lands on Approve of the next ask, and is let go; after the beat, it is taken.
    @Test func aPressJustAfterTheAskChangesIsLetGo() throws {
        let run = try Self.asksOpen(), setting = Self.setting(), threaded = try Self.part(.answer(0), run)

        run.heard(Self.held(Self.threaded), Self.at(run, threaded, setting))
        run.heard(.went(Self.threaded), Self.at(run, threaded, setting))
        #expect(run.asksShown?.ask.id == "k2")
        #expect(run.asksShown?.hover == .answer(0))
        #expect(run.press(Self.at(run, threaded, setting)) == nil)

        Self.frames(run, for: AsksPanel.settle, threaded, setting)
        #expect(run.press(Self.at(run, threaded, setting)) == .answer(Self.approve))
    }

    /// For a beat after an Undo, a press where Undo was is let go: Open in Claude has come back there.
    @Test func aPressJustAfterAnUndoIsLetGo() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))

        let undo = try Self.part(.undo, run)

        #expect(run.press(Self.at(run, undo, setting)) == .undo)
        run.heard(.undone(Self.threaded), Self.at(run, undo, setting))
        #expect(run.asksShown?.hover == .open)
        #expect(run.press(Self.at(run, undo, setting)) == nil)

        Self.frames(run, for: AsksPanel.settle, undo, setting)
        guard case .jump? = run.press(Self.at(run, undo, setting)) else {
            Issue.record("Open in Claude did not jump after the beat")
            return
        }
    }

    /// A press on another row's words jumps to it, and the asks panel closes with the panel.
    @Test func aJumpFromAnotherRowClosesIt() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        guard case let .jump(session, to: _, click: _)? = run.press(
            Self.at(run, try Self.words(Self.shifts, run), setting)
        ) else {
            Issue.record("a press on another row's words did not jump")
            return
        }
        #expect(session.id == AsksBoard.shifts)
        #expect(run.asksShown == nil)
    }

    /// The arrow takes a press where it draws: as its row arrives on the board and unfolds, laid out at its own height
    /// and clipped to its growing box, on the arrow's top, and not just above it, where an arrow centred in the
    /// shortened box would be.
    @Test(arguments: [true, false])
    func theArrowTakesAPressWhereItDrawsAsItsRowUnfolds(onIt: Bool) throws {
        let setting = Self.setting(), run = Self.opened(setting, board: AsksBoard.board(without: ["k1", "k2"]))
        let shortened = {
            run.list.index(of: Self.helpDesk).map { index in
                let entry = run.list.content.entries[index]

                return (8 ... entry.item.height - 6).contains(entry.height)
            } ?? false
        }

        #expect(run.list.index(of: Self.helpDesk) == nil)
        _ = run.show(AsksBoard.board(), Self.at(run, Self.onTheNotch, setting))
        for _ in 0 ..< 30 where !shortened() {
            run.step(Self.at(run, Self.onTheNotch, setting))
        }
        try #require(shortened())

        let row = try Self.row(Self.helpDesk, run), box = RowArrow.box(in: row.size)
        let point = try Self.onStage(row.minX + box.midX, row.minY + box.minY + (onIt ? 1 : -1), run, setting)
        let press = run.press(Self.at(run, point, setting))

        #expect(onIt ? press == .asks : press != .asks)
    }

    // MARK: The pointer on it

    /// The pointer moving about on the asks panel, off the list, moves nothing of the panel: the edge doesn't reach for
    /// it.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func theOutlineStaysStillWhileThePointerMovesOnIt(_ style: NotchStyle) throws {
        let setting = Self.setting(style: style), run = try Self.asksOpen(Self.helpDesk, setting)
        let start = try Self.onAsks(run, in: 300, down: 20)

        Self.frames(run, for: 1500, start, setting)

        let still = run.frame.outline.boundingBoxOfPath
        var moved: [CGRect] = []

        for step in 1 ... 60 {
            run.step(Self.at(run, CGPoint(x: start.x + Double(step) * 4, y: start.y + Double(step)), setting))
            moved.append(run.frame.outline.boundingBoxOfPath)
        }
        #expect(run.phase == .open && run.asksShown != nil)
        #expect(moved.allSatisfy { abs($0.maxX - still.maxX) < 0.01 && abs($0.height - still.height) < 0.01 })
    }

    /// The asks panel closing from under a pointer that stays still, just past the list's front, as its last answer
    /// goes, is no leave: the panel stays open, and the edge doesn't reach for the pointer, until it moves; once it has
    /// moved off, the panel closes. Card would close on it; Meniscus would bow toward it.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func aStillPointerItClosesFromUnderKeepsThePanelOpenAndStill(_ style: NotchStyle) throws {
        let setting = Self.setting(style: style), run = try Self.asksOpen(Self.helpDesk, setting)
        let asks = try #require(run.asksShown), onIt = CGPoint(x: asks.frame.minX + 14, y: asks.frame.midY)

        Self.frames(run, for: 1000, onIt, setting)

        let still = run.frame.outline.boundingBoxOfPath

        run.heard(.went(Self.threaded), Self.at(run, onIt, setting))
        run.heard(.went(Self.approve), Self.at(run, onIt, setting))
        #expect(run.asksShown == nil)

        Self.frames(run, for: 3000, onIt, setting)
        #expect(run.phase == .open)
        #expect(abs(run.frame.outline.boundingBoxOfPath.maxX - still.maxX) < 0.01)

        Self.frames(run, for: 2000, CGPoint(x: onIt.x + 60, y: onIt.y), setting) { run.phase != .open }
        #expect(run.phase != .open)
    }

    /// Stepping to a shorter ask, its foot rising from under a still pointer just past the list's front, keeps the
    /// panel open and the edge still.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func steppingToAShorterAskKeepsThePanelOpenAndStill(_ style: NotchStyle) throws {
        let setting = Self.setting(style: style), run = try Self.asksOpen(Self.helpDesk, setting)
        let asks = try #require(run.asksShown)
        let foot = CGPoint(x: asks.frame.minX + 14, y: asks.frame.maxY - 4)

        Self.frames(run, for: 1000, foot, setting)

        let still = run.frame.outline.boundingBoxOfPath

        run.heard(.went(Self.threaded), Self.at(run, foot, setting))

        let next = try #require(run.asksShown)

        #expect(next.ask.id == "k2" && !next.frame.contains(foot))
        Self.frames(run, for: 3000, foot, setting)
        #expect(run.phase == .open && run.asksShown != nil)
        #expect(abs(run.frame.outline.boundingBoxOfPath.maxX - still.maxX) < 0.01)
    }

    /// Leaving the asks panel is leaving the panel at the pointer's own speed, as from the list: slowly, the slow
    /// leave's grace, 300ms; fast, a fast one's, 60; on either notch.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func aLeaveOfItIsALeaveOfThePanelAtThePointersSpeed(_ style: NotchStyle) throws {
        let setting = Self.setting(style: style)
        let open = try [0.05, 3].map { speed in
            let run = try Self.asksOpen(Self.helpDesk, setting), asks = try #require(run.asksShown)

            return try #require(
                Self.open(run, leaving: CGPoint(x: asks.frame.maxX, y: asks.frame.midY), at: speed, setting)
            )
        }

        #expect(open[0] > 250)
        #expect(open[1] < 120)
    }

    /// On a list of one row the asks panel runs on below it: the way from the arrow down to its foot, past the list's
    /// bottom corner, keeps the panel open, as a Mac submenu's safe triangle does, the pointer resting off both a while
    /// on the way, on either edge and either notch. On the right edge the arrow stands at the row's other end, and the
    /// way starts along the row, on the list, from where it stands on the left.
    @Test(arguments: [NotchStyle.meniscus, .card], [false, true])
    func theWayFromTheArrowPastTheListsCornerKeepsItOpen(_ style: NotchStyle, right: Bool) throws {
        let setting = Self.setting(right: right, style: style)
        let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
        let asks = try #require(run.asksShown), panel = try #require(run.frame.panel)
        let row = try Self.row(Self.helpDesk, run), box = RowArrow.box(in: row.size)
        let from = CGPoint(x: panel.frame.minX + row.minX + box.midX, y: try Self.arrow(Self.helpDesk, run, setting).y)
        let corner = try #require(stride(from: from.y, to: asks.frame.maxY, by: 1).lazy.map {
            CGPoint(x: asks.frame.minX - 6, y: $0)
        }.first { !panel.contains($0) && !asks.frame.contains($0) })
        let off = CGPoint(x: corner.x, y: corner.y + 6)
        let to = CGPoint(x: asks.frame.minX + 40, y: asks.frame.maxY - 20)

        for point in Self.way(from: from, to: off) + [off] {
            run.step(Self.at(run, point, setting))
        }
        Self.frames(run, for: 1000, off, setting)
        #expect(run.phase == .open)
        for point in Self.way(from: off, to: to) {
            run.step(Self.at(run, point, setting))
        }
        Self.frames(run, for: 2000, to, setting)
        #expect(run.phase == .open && run.asksShown != nil)
    }

    /// On the right edge the room between the arrow and the asks panel is the left edge's: no wider, as the arrow
    /// standing at the row's other end leaves the way there to the list.
    @Test func theRoomToItIsNoWiderOnTheRightEdge() throws {
        let rooms = try [false, true].map { right in
            let setting = Self.setting(right: right)
            let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
            let ground = AsksGround(
                list: run.list, board: run.board, panel: run.frame.panel, scroll: run.scroll, stage: setting.stage,
                mirror: setting.mirror
            )

            return AsksPanel.room(of: try #require(run.asksShown), on: ground).boundingBoxOfPath
        }

        #expect(rooms[0].width > CGFloat(AsksLayout.width))
        #expect(rooms[1].width <= rooms[0].width + 0.5)
    }

    /// The points a pointer passes going from one point to another in 15 frames, the last not.
    private static func way(from: CGPoint, to: CGPoint) -> [CGPoint] {
        (0 ..< 15).map { step in
            let share = Double(step) / 15

            return CGPoint(x: from.x + (to.x - from.x) * share, y: from.y + (to.y - from.y) * share)
        }
    }

    // MARK: The right edge

    /// Mirrored on the right edge, it still reads left to right: its rows where they are drawn.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func onTheRightEdgeItReadsLeftToRight(_ style: NotchStyle) throws {
        let setting = Self.setting(right: true, style: style), run = try Self.asksOpen(Self.helpDesk, setting)
        let asks = try #require(run.asksShown), panel = try #require(run.frame.panel)

        #expect(asks.frame.minX == panel.frame.maxX - CGFloat(AsksLayout.overlap))
        #expect(
            run.press(Self.at(run, try Self.part(.answer(1), run, setting), setting))
                == .answer(Answering(.words("Flat"), to: "k1", of: AsksBoard.helpDesk))
        )
    }
}
