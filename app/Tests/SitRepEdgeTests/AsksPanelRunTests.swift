import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The row's arrow and the asks panel as the notch's run has them (DESIGN, "Answering from the panel"): the arrow on a
/// Needs you row with an ask the panel answers, lit on itself; a press on it opening the asks panel beside the row,
/// moving it to another, closing it from the lit one, a press on the row's words still jumping, and while it is open, a
/// click elsewhere on the list closing it and doing nothing else; the asks panel level with its row past the list's
/// front, read left to right on either edge, holding the panel open while the pointer is on it; its answers held,
/// taken back and gone, stepping to the session's next ask and closing after the last; its dots and a horizontal swipe
/// paging it, its asks sliding with the fingers and the spring; its Snooze ▾ snoozing the ask it shows; and an ask
/// leaving the board leaving it.
@Suite(.backstop)
struct AsksPanelRunTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)
    private static let frameMS = 1000.0 / 60
    private static let onTheNotch = CGPoint(x: 3, y: 491), away = CGPoint(x: 1300, y: 491)
    private static let helpDesk = "needs:\(AsksBoard.helpDesk)", shifts = "needs:\(AsksBoard.shifts)"
    private static let dataImport = "needs:\(AsksBoard.dataImport)"

    private static func setting(
        right: Bool = false, style: NotchStyle = .meniscus, stage: Stage = stage, reducesMotion: Bool = false
    ) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: stage, mirror: right ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 800, ty: 0) : .identity,
            style: style, reducesMotion: reducesMotion, isChosen: true
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
        frames(run, for: 3000, CGPoint(x: 3, y: setting.stage.notchY), setting) {
            run.phase == .open && !run.frame.isMoving
        }
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
        let row = try row(key, run), box = RowArrow.box(in: row.size, pointsLeft: setting.mirror.a < 0)

        return try onStage(row.minX + box.midX, row.minY + box.midY, run, setting)
    }

    /// A row's end away from the asks panel, 23 in from it: its left on the left edge, its right on the right, where
    /// the right edge's arrow stood until 25 November 2026. The longest way from the list to the asks panel starts
    /// there.
    private static func farEnd(
        _ key: String, _ run: NotchRun, _ setting: NotchRun.Setting = setting()
    ) throws -> CGPoint {
        let row = try row(key, run)

        return try onStage(setting.mirror.a < 0 ? row.maxX - 23 : row.minX + 23, row.midY, run, setting)
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
        let own = switch part {
        case let .answer(row): layout.answers[row]
        case let .page(page): layout.dots(at: asks.progress, of: asks.pages)[page]
        case .ignore: layout.ignore
        case .snooze: try #require(layout.snooze)
        case .open: layout.open
        case .undo: layout.undo
        }

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

    private static let threaded = Answering(.words("Threaded"), to: "k1", of: AsksBoard.helpDesk, wanting: .choice)
    private static let approve = Answering(.words("Approve"), to: "k2", of: AsksBoard.helpDesk, wanting: .yes)

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

    @Test func anAnswersRowAndIgnoreHoldTheirAnswers() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.answer(0), run), setting)) == .answer(Self.threaded))
        #expect(
            run.press(Self.at(run, try Self.part(.ignore, run), setting))
                == .answer(Answering(.ignore, to: "k1", of: AsksBoard.helpDesk, wanting: .choice))
        )
    }

    /// A words ask has no row answering in Claude, which only did what Open in Claude does: its foot's Open in Claude
    /// jumps.
    @Test func aWordsAskHasNoRowsAndJumpsFromOpenInClaude() throws {
        let words = try Self.asksOpen(Self.shifts), setting = Self.setting()
        let asks = try #require(words.asksShown)

        #expect(asks.ask.wants == .words && asks.layout.answers.isEmpty)
        guard case let .jump(session, to: _, click: _)? = words.press(
            Self.at(words, try Self.part(.open, words), setting)
        ) else {
            Issue.record("Open in Claude did not jump")
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

    /// Snooze ▾ offers the snooze of the ask it shows, the one paged to, not its session's.
    @Test func snoozeOffersTheSnoozeOfTheAskItShows() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.page(1), run), setting)) == .asks)
        Self.frames(run, for: AsksPanel.settle, try Self.onAsks(run, down: 70), setting)
        _ = try Self.settling(run)

        let there = try Self.part(.snooze, run)

        #expect(run.press(Self.at(run, there, setting)) == .snooze(ask: "k2", of: AsksBoard.helpDesk, at: there))
        run.closeAsks(Self.at(run, there, setting))
        #expect(run.asksShown == nil)
    }

    /// While Snooze offers no time, its foot shows no Snooze ▾, and a press where it stood snoozes nothing; as Snooze
    /// offers one again, the next moment lays it out again with Snooze ▾ back.
    @Test func withNoSnoozeTimeOfferedTheAsksPanelHasNoSnooze() throws {
        var none = Self.setting()

        none.offersSnooze = false
        let offered = try #require(try Self.asksOpen().asksShown?.layout.snooze)
        let run = try Self.asksOpen(Self.helpDesk, none), asks = try #require(run.asksShown)
        let stood = CGPoint(x: asks.frame.minX + offered.midX, y: asks.frame.minY + offered.midY)

        #expect(asks.layout.snooze == nil)
        Self.frames(run, for: AsksPanel.settle, stood, none)
        #expect(run.press(Self.at(run, stood, none)) == nil)
        #expect(run.asksShown?.row == Self.helpDesk)

        run.step(Self.at(run, stood, Self.setting()))
        #expect(run.asksShown?.layout.snooze == offered)
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

    /// While it is open, a click on the list anywhere but an arrow, on a row's words, its own row's or another's, an
    /// eyebrow or the black between, closes it and does nothing else: no jump, no fold, no drag, the panel still open.
    /// The next click acts.
    @Test(arguments: [Elsewhere.ownRow, .anotherRow, .eyebrow, .between])
    func aClickElsewhereOnTheListClosesItAndDoesNothingElse(_ place: Elsewhere) throws {
        let run = try Self.asksOpen(), setting = Self.setting(), folded = run.folded
        let point = try place.point(run, setting)

        #expect(run.press(Self.at(run, point, setting)) == .asks)
        #expect(run.asksShown == nil && run.drag == nil && run.folded == folded)
        run.step(Self.at(run, point, setting))
        #expect(run.phase == .open && run.frame.panel?.pressed == nil)

        if place == .anotherRow {
            guard case let .jump(session, to: _, click: _)? = run.press(Self.at(run, point, setting)) else {
                Issue.record("the next click on the row's words did not jump")
                return
            }
            #expect(session.id == AsksBoard.shifts)
        }
    }

    /// Where on the list, off every arrow, a click closes the asks panel.
    enum Elsewhere: CaseIterable {
        case ownRow, anotherRow, eyebrow, between

        func point(_ run: NotchRun, _ setting: NotchRun.Setting) throws -> CGPoint {
            typealias Run = AsksPanelRunTests

            switch self {
            case .ownRow:
                return try Run.words(Run.helpDesk, run, setting)
            case .anotherRow:
                return try Run.words(Run.shifts, run, setting)
            case .eyebrow:
                let index = try #require(run.list.content.entries.firstIndex { entry in
                    guard case .eyebrow = entry.item else {
                        return false
                    }
                    return true
                })
                let box = run.list.content.laidFrame(index)

                return try Run.onStage(box.minX + 40, box.midY, run, setting)
            case .between:
                return try Run.onStage(2, try Run.row(Run.shifts, run).minY - 1, run, setting)
            }
        }
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

    /// How the pointer's samples come on the way: a new one each frame at 60Hz; at 120Hz, one every other frame, as a
    /// slower mouse or trackpad gives on a fast display; or a fast mouse's 500 a second, each a point and a half back
    /// or on along the way in turn, further from the asks panel than the one before every other time.
    enum Feed: CaseIterable {
        case fresh, repeats, jitter

        /// How far apart, ms, the steps come.
        var every: Double {
            switch self {
            case .fresh: frameMS
            case .repeats: frameMS / 2
            case .jitter: 2
            }
        }
    }

    /// On a list of one row the asks panel runs on below it: the straight way from the row, its arrow or its far end,
    /// to the last answer of a choice of three, past the list's bottom corner, keeps the panel open, as a Mac submenu's
    /// safe triangle does, on either notch, however the pointer's samples come. The pointer goes slowly enough that its
    /// way off both panels takes longer than a leave's grace, and within the triangle's time. On the right edge the
    /// way from the arrow, at the row's end by the asks panel, never leaves the list and the asks panel.
    @Test(arguments: [NotchStyle.meniscus, .card], [Start.leftArrow, .leftFarEnd, .rightFarEnd])
    func theWayFromTheRowToTheLastAnswerKeepsItOpen(_ style: NotchStyle, start: Start) throws {
        for feed in Feed.allCases {
            let setting = Self.setting(right: start == .rightFarEnd, style: style)
            let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
            let from = try start == .leftArrow
                ? Self.arrow(Self.helpDesk, run, setting) : Self.farEnd(Self.helpDesk, run, setting)
            let to = try Self.part(.answer(2), run, setting)
            let off = try Self.offBoth(run, from: from, to: to)

            try #require(off.length > 0, "the way never leaves both panels")
            for point in Self.way(from: from, to: to, at: off.length / (SafeTriangle.lasts - 60), feed: feed) {
                run.step(NotchRun.Moment(time: run.time + feed.every, pointer: point, setting: setting))
            }
            Self.frames(run, for: 2000, to, setting)
            #expect(run.phase == .open && run.asksShown?.hover == .answer(2), "fed \(feed)")
        }
    }

    /// Where the way to the asks panel starts: the row's arrow on the left edge, or its far end on either.
    enum Start: CaseIterable {
        case leftArrow, leftFarEnd, rightFarEnd
    }

    /// A pointer resting on the list, near its bottom edge, longer than the way's time, with no frames meanwhile,
    /// then going slowly on its way to the last answer: the way's time counts from the move off the list, not from
    /// the rest, so it keeps the panel open, on either notch and edge.
    @Test(arguments: [NotchStyle.meniscus, .card], [false, true])
    func aRestOnTheListBeforeTheWayLeavesItAllItsTime(_ style: NotchStyle, right: Bool) throws {
        let setting = Self.setting(right: right, style: style)
        let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
        let from = try Self.farEnd(Self.helpDesk, run, setting), to = try Self.part(.answer(2), run, setting)
        let off = try Self.offBoth(run, from: from, to: to), panel = try #require(run.frame.panel)
        let way = Self.way(from: from, to: to, at: off.length / (SafeTriangle.lasts - 60))
        let edge = try #require(way.lastIndex { panel.contains($0) })

        for point in way[...edge] {
            run.step(Self.at(run, point, setting))
        }
        Self.asTheAppSteps(run, until: run.time + 2000, pointer: way[edge], setting)
        #expect(!run.needsFrames(at: run.time))
        run.step(NotchRun.Moment(time: run.time + 2 * SafeTriangle.lasts, pointer: way[edge + 1], setting: setting))
        for point in way[(edge + 2)...] {
            run.step(Self.at(run, point, setting))
        }
        Self.frames(run, for: 2000, to, setting)
        #expect(run.phase == .open && run.asksShown?.hover == .answer(2))
    }

    /// A pointer on the way that rests there, turns back the way it came, still in the triangle, or creeps on past
    /// the triangle's time is off the panel, and the panel closes as a leave closes it: a rest or a turn within the
    /// window it is judged over and a slow leave's grace, a creep within the triangle's time and that grace of leaving
    /// the list, on either notch.
    @Test(arguments: [NotchStyle.meniscus, .card], ["rests", "turns", "creeps"])
    func onTheWayAPointerThatDawdlesClosesIt(_ style: NotchStyle, dawdle: String) throws {
        let setting = Self.setting(right: true, style: style)
        let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
        let from = try Self.farEnd(Self.helpDesk, run, setting), to = try Self.part(.answer(2), run, setting)
        let off = try Self.offBoth(run, from: from, to: to), panel = try #require(run.frame.panel)
        let speed = dawdle == "creeps" ? off.length / (SafeTriangle.lasts + 600) : 1.0
        var way = Self.way(from: from, to: to, at: speed), halfway = way.count

        if dawdle != "creeps" {
            halfway = try #require(way.firstIndex { hypot($0.x - off.middle.x, $0.y - off.middle.y) < speed * 20 })

            let there = way[halfway]
            let back = Self.way(from: there, to: from, at: speed / 8).filter { !panel.contains($0) }

            way = Array(way[...halfway]) + (dawdle == "turns" ? back : Array(repeating: there, count: 90))
        }

        var onList = run.time, dawdled = run.time

        for (step, point) in way.enumerated() where run.phase == .open {
            run.step(Self.at(run, point, setting))
            if panel.contains(point) {
                onList = run.time
            }
            if step == halfway {
                dawdled = run.time
            }
        }
        #expect(run.phase != .open)
        if dawdle == "creeps" {
            #expect(run.time - onList <= SafeTriangle.lasts + Self.slowGrace + 2 * Self.frameMS)
        } else {
            #expect(run.time - dawdled <= SafeTriangle.window + Self.slowGrace + 2 * Self.frameMS)
        }
    }

    /// A slow leave's grace, ms: the longest a leave keeps the panel open.
    private static let slowGrace = 300.0

    /// The pointer resting on the way, with steps only as the app takes them: at each of the pointer's samples, and at
    /// frames while the run asks for them (`needsFrames`). The rest ends the way on time, and the panel closes within
    /// the window the way is judged over and a slow leave's grace of the rest, on either notch.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func aPointerRestingOnTheWayClosesItWithNoOtherInput(_ style: NotchStyle) throws {
        let setting = Self.setting(right: true, style: style)
        let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
        let from = try Self.farEnd(Self.helpDesk, run, setting), to = try Self.part(.answer(2), run, setting)
        let off = try Self.offBoth(run, from: from, to: to), panel = try #require(run.frame.panel)
        let way = Self.way(from: from, to: to, at: 1)
        let halfway = try #require(way.firstIndex { hypot($0.x - off.middle.x, $0.y - off.middle.y) < 20 })
        var time = run.time, last = from

        for point in way[...halfway] {
            time += 8
            Self.asTheAppSteps(run, until: time, pointer: last, setting)
            run.step(NotchRun.Moment(time: time, pointer: point, setting: setting))
            last = point
        }
        #expect(!panel.contains(last) && run.phase == .open)
        Self.asTheAppSteps(run, until: time + 2000, pointer: last, setting) { run.phase != .open }
        #expect(run.phase != .open)
        #expect(run.time - time <= SafeTriangle.window + Self.slowGrace + 2 * Self.frameMS)
    }

    /// Frames as the app takes them, the pointer still, up to a time or until `done`: one a display refresh while the
    /// run asks for them, else none.
    private static func asTheAppSteps(
        _ run: NotchRun, until end: Double, pointer: CGPoint, _ setting: NotchRun.Setting,
        done: () -> Bool = { false }
    ) {
        while run.time + frameMS < end, run.needsFrames(at: run.time), !done() {
            run.step(at(run, pointer, setting))
        }
    }

    /// The points a pointer gives at this speed, pt/ms, a step of `feed` apart, from one point to another, the last
    /// one too, fed as `feed` has them.
    private static func way(from: CGPoint, to: CGPoint, at speed: Double, feed: Feed = .fresh) -> [CGPoint] {
        let length = hypot(to.x - from.x, to.y - from.y)
        let steps = max(1, Int((length / (speed * feed.every)).rounded(.up)))

        return (1 ... steps).map { step in
            let sample = feed == .repeats && step % 2 == 1 && step < steps ? step - 1 : step
            let jitter = feed == .jitter && step < steps ? (step % 2 == 0 ? 1.5 : -1.5) : 0
            let share = (Double(sample) + jitter / (speed * feed.every)) / Double(steps)

            return CGPoint(x: from.x + (to.x - from.x) * share, y: from.y + (to.y - from.y) * share)
        }
    }

    /// How much of the straight way between two points is off both the list and the asks panel, and its middle.
    private static func offBoth(
        _ run: NotchRun, from: CGPoint, to: CGPoint
    ) throws -> (length: Double, middle: CGPoint) {
        let asks = try #require(run.asksShown), panel = try #require(run.frame.panel)
        let steps = 400, length = hypot(to.x - from.x, to.y - from.y)
        let off = (0 ... steps).map { step in
            CGPoint(
                x: from.x + (to.x - from.x) * Double(step) / Double(steps),
                y: from.y + (to.y - from.y) * Double(step) / Double(steps)
            )
        }.filter { !panel.contains($0) && !asks.frame.contains($0) }

        return (length * Double(off.count) / Double(steps), off.isEmpty ? from : off[off.count / 2])
    }

    /// Rows folding away above its row while it is open, the list's top moving down past a pointer resting on the
    /// list: the asks panel moving with its row is no leave of the list, as Meniscus gives a still pointer no enter or
    /// leave as the shape pours under it. Under reduced motion, where the edge never clings to the pointer, so that
    /// nothing else holds it. Card reads the pointer against the shape every frame, so this is Meniscus's rule alone.
    @Test func theListsTopMovingPastAStillPointerIsNoLeaveWithItOpen() throws {
        let setting = Self.setting(reducesMotion: true)
        let run = try Self.asksOpen(Self.shifts, setting), was = try #require(run.asksShown)
        let panel = try #require(run.frame.panel)
        let resting = CGPoint(x: panel.frame.minX + 200, y: panel.frame.minY + 5)

        Self.frames(run, for: 500, resting, setting)
        _ = run.show(AsksBoard.board(without: ["k1", "k2"]), Self.at(run, resting, setting))
        Self.frames(run, for: 1000, resting, setting)

        #expect(run.frame.panel?.contains(resting) == false, "the list never left the pointer")
        #expect(try #require(run.asksShown).frame.minY != was.frame.minY)
        Self.frames(run, for: 2000, resting, setting)
        #expect(run.phase == .open)
    }

    // MARK: What moves it

    /// A row landing above its own slides it down under a resting pointer: for a beat after, a press there is let go,
    /// as what sits under the pointer moved; then it is taken. With frames at a display's 60Hz, and with steps a
    /// millisecond apart, as frames and inputs can come: a slide is told by its speed, not how far one step moves it.
    @Test(arguments: [60.0, 1000.0])
    func itSlidingUnderARestingPointerLetsAPressGoForABeat(hz: Double) throws {
        let setting = Self.setting()
        let run = try Self.asksOpen(Self.dataImport, setting, board: AsksBoard.board(without: ["k1", "k2"]))
        let was = try #require(run.asksShown), resting = try Self.part(.answer(0), run)
        let next = { NotchRun.Moment(time: run.time + 1000 / hz, pointer: resting, setting: setting) }

        Self.frames(run, for: AsksPanel.settle, resting, setting)
        _ = run.show(AsksBoard.board(), Self.at(run, resting, setting))
        for _ in 0 ..< Int(hz / 20) {
            run.step(next())
        }

        #expect(try #require(run.asksShown).frame.minY > was.frame.minY)
        #expect(run.asksShown?.hover != nil)
        #expect(run.press(next()) == nil)

        Self.frames(run, for: 600, resting, setting)
        #expect(run.press(Self.at(run, resting, setting)) != nil)
    }

    /// The panel's spring snapping to rest, by a thousandth of a point, as a second placing at a frame's own time
    /// steps it, is no move: a press then, at that time, is taken once the slide has long since settled.
    @Test func aSpringsRestSnapIsNoMoveThoughTwoPlacingsShareATime() throws {
        let setting = Self.setting()
        let run = try Self.asksOpen(Self.dataImport, setting, board: AsksBoard.board(without: ["k1", "k2"]))
        let resting = try Self.part(.answer(0), run)
        let now = { NotchRun.Moment(time: run.time, pointer: resting, setting: setting) }

        Self.frames(run, for: AsksPanel.settle, resting, setting)
        _ = run.show(AsksBoard.board(), Self.at(run, resting, setting))
        for _ in 0 ..< 120 {
            run.step(Self.at(run, resting, setting))

            let was = try #require(run.asksShown).frame.minY

            run.step(now())

            let snap = abs(try #require(run.asksShown).frame.minY - was)

            if snap > 0 {
                #expect(snap < 0.01)
                #expect(run.press(now()) != nil)
                return
            }
        }
        Issue.record("no spring snapped to rest at a frame's own time")
    }

    /// Scrolls that move the list more than a few points from where it was as it opened close it, as a Mac menu's
    /// scroll closes its submenu, however many it takes; a few points, as a sideways swipe's drift, leave it open, as
    /// does a scroll over it, which moves nothing.
    @Test func aScrollOfTheListClosesIt() throws {
        let setting = Self.setting(stage: Self.short)
        let run = try Self.asksOpen(Self.helpDesk, setting)
        let onIt = try Self.onAsks(run), onTheList = try Self.words(Self.helpDesk, run, setting)

        run.scroll(by: 40, Self.at(run, onIt, setting))
        #expect(run.scroll == 0 && run.asksShown != nil)

        run.scroll(by: 6, Self.at(run, onTheList, setting))
        #expect(run.scroll == 6 && run.asksShown != nil)

        run.scroll(by: 6, Self.at(run, onTheList, setting))
        #expect(run.scroll == 12)
        #expect(run.asksShown == nil)
    }

    /// The list shrinking under it, scrolled to its foot, moves the list with no scroll: a brush of a point after
    /// leaves it open, as the list has moved only that point by a scroll since it opened.
    @Test func theListKeptInViewAsItShrinksIsNoScrollOfIt() throws {
        let setting = Self.setting(stage: Self.short), dataImport = Self.dataImport
        let run = Self.opened(setting)

        run.scroll(by: 1000, Self.at(run, try Self.words(Self.helpDesk, run, setting), setting))
        Self.frames(run, for: 300, try Self.words(dataImport, run, setting), setting)
        #expect(run.press(Self.at(run, try Self.arrow(dataImport, run, setting), setting)) == .asks)

        let scrolled = run.scroll, onIt = try Self.onAsks(run)

        _ = run.show(AsksBoard.board(without: ["k1", "k2"]), Self.at(run, onIt, setting))
        Self.frames(run, for: 1000, onIt, setting)
        #expect(run.scroll < scrolled - AsksPanel.scrollMost, "the list was never kept in view")
        try #require(run.asksShown != nil)

        let kept = run.scroll

        run.scroll(by: -1, Self.at(run, try Self.words(dataImport, run, setting), setting))
        #expect(run.scroll == kept - 1)
        #expect(run.asksShown != nil)
    }

    /// A stage short enough that the list scrolls.
    private static let short = Stage(height: 360, visibleTop: 24, visibleBottom: 360, notchY: 180)

    /// While one session's answer is held, another session's asks panel takes none and lights none: the answers
    /// take one at a time.
    @Test func whileOneSessionsAnswerIsHeldAnothersTakesNone() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))
        #expect(run.press(Self.at(run, try Self.arrow(Self.dataImport, run), setting)) == .asks)
        #expect(run.asksShown?.session.id == AsksBoard.dataImport && run.asksShown?.sending == nil)

        let map = try Self.part(.answer(0), run)

        run.step(Self.at(run, map, setting))
        #expect(run.asksShown?.hover == nil)
        #expect(run.press(Self.at(run, map, setting)) == nil)
    }

    // MARK: Paging

    /// A click on a dot shows its ask at once, sliding there, during the slide as after it: a dot pages the same
    /// whatever ask shows, so clicks from dot to dot in quick succession each land. An answer pressed as it slides is
    /// let go.
    @Test func aClickOnADotShowsItsAskAtOnce() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.page(1), run), setting)) == .asks)
        #expect(run.asksShown?.ask.id == "k2" && run.asksShown?.page == 1)
        #expect(run.press(Self.at(run, try Self.part(.page(0), run), setting)) == .asks)
        #expect(run.asksShown?.ask.id == "k1" && run.asksShown?.page == 0)
        #expect(run.press(Self.at(run, try Self.part(.answer(0), run), setting)) == nil)
        #expect(run.asksShown?.sending == nil)
    }

    /// Where a swipe's scrolls come: on the asks panel, over its title, whatever ask it shows, or at `pointer`.
    private static func swipe(
        _ run: NotchRun, _ phase: Scroll.Phase, along: Double, down: Double = 0, after ms: Double = frameMS,
        _ setting: NotchRun.Setting = setting(), at pointer: CGPoint? = nil
    ) throws {
        let onIt = try pointer ?? onAsks(run, down: 70)

        run.scroll(
            Scroll(down: down, along: along, phase: phase),
            NotchRun.Moment(time: run.time + ms, pointer: onIt, setting: setting)
        )
    }

    /// A trackpad's fingers touching the asks panel, then travelling `travel` along, `each` a frame: at 5, 0.3 points a
    /// millisecond, slower than a flick. Still on the trackpad.
    private static func drag(
        _ run: NotchRun, _ travel: Double, each: Double = 5, _ setting: NotchRun.Setting = setting()
    ) throws {
        try swipe(run, .began, along: 0, setting)
        for _ in 0 ..< Int((abs(travel) / each).rounded()) {
            try swipe(run, .changed, along: travel < 0 ? -each : each, setting)
        }
    }

    /// How far the asks panel's ask has slid, frame by frame, the pointer on it, until its asks stop sliding.
    private static func settling(_ run: NotchRun, _ setting: NotchRun.Setting = setting()) throws -> [Double] {
        let onIt = try onAsks(run, down: 70)
        var slid: [Double] = []

        while run.asking.isSliding, slid.count < 120 {
            run.step(at(run, onIt, setting))
            slid.append(try #require(run.asksShown).slid)
        }
        return slid
    }

    /// The ask slides with the fingers, a point for a point, once the gesture has gone 6 points more across than
    /// down, the ask beside it on that side sliding in and the dots following; it stays the ask shown, the frame where
    /// it stood, until the fingers lift. Frames run meanwhile.
    @Test func theAskFollowsTheFingers() throws {
        let run = try Self.asksOpen(), stood = try #require(run.asksShown?.frame.origin)

        try Self.drag(run, 60)

        let asks = try #require(run.asksShown)

        #expect(asks.slid == 60 && asks.ask.id == "k1" && asks.frame.origin == stood)
        #expect(asks.beside?.ask.id == "k2" && asks.beside?.page == 1)
        #expect(asks.progress == 60 / AsksLayout.width)
        #expect(run.needsFrames(at: run.time))
        try Self.swipe(run, .changed, along: -20)
        #expect(run.asksShown?.slid == 40)

        try Self.swipe(run, .cancelled, along: 0)
        _ = try Self.settling(run)
        #expect(run.press(Self.at(run, try Self.part(.page(1), run), Self.setting())) == .asks)
        _ = try Self.settling(run)
        try Self.drag(run, -60)
        #expect(run.asksShown?.slid == -60 && run.asksShown?.beside?.ask.id == "k1")
    }

    /// Lifted past a third of the asks panel's width, the ask beside completes its slide, the ask it leaves sliding
    /// out on the other side, and settles without passing its place in under half a second; short of the third, it
    /// springs back as fast.
    @Test func pastAThirdTheLiftCompletesAndShortOfItSpringsBack() throws {
        let run = try Self.asksOpen()

        try Self.drag(run, 120)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k1")

        let back = try Self.settling(run)

        #expect(back.allSatisfy { $0 >= 0 } && Double(back.count) * Self.frameMS < 500)
        #expect(run.asksShown?.slid == 0 && run.asksShown?.beside == nil && !run.needsFrames(at: run.time))

        try Self.drag(run, 130)
        try Self.swipe(run, .ended, along: 0)

        let asks = try #require(run.asksShown)

        #expect(asks.ask.id == "k2" && asks.slid == 130 - AsksLayout.width && asks.beside?.page == 0)

        let on = try Self.settling(run)

        #expect(on.allSatisfy { $0 <= 0 } && zip(on, on.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(Double(on.count) * Self.frameMS < 500 && run.asksShown?.slid == 0)
    }

    /// A flick toward the ask beside completes its slide however short; a flick back springs back however far the
    /// slide went.
    @Test func aFlickCompletesAndAFlickBackSpringsBack() throws {
        let run = try Self.asksOpen()

        try Self.drag(run, 60, each: 20)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k2")
        _ = try Self.settling(run)

        try Self.drag(run, -250, each: 10)
        for _ in 0 ..< 4 {
            try Self.swipe(run, .changed, along: 25)
        }
        #expect(run.asksShown?.slid == -150)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k2")
    }

    /// The momentum that runs on after the fingers lift is no gesture: a flick takes no second step, and momentum
    /// coming while a gesture is under way, as after a lift that went to another window, moves nothing.
    @Test func itsMomentumAfterTheLiftIsNoGesture() throws {
        let run = try Self.asksOpen(Self.helpDesk, board: AsksBoard.board(withNotes: true))

        try Self.drag(run, 200)
        try Self.swipe(run, .momentum, along: 100)
        #expect(run.asksShown?.slid == 200)
        try Self.swipe(run, .ended, along: 0)
        try Self.swipe(run, .momentum, along: 300)
        try Self.swipe(run, .momentum, along: 300)
        _ = try Self.settling(run)
        #expect(run.asksShown?.page == 1 && run.asksShown?.slid == 0)
    }

    /// Past the first ask or the last it moves a share of the fingers' travel, the share shrinking as they go, nothing
    /// beside it, and springs back on the lift: nothing wraps.
    @Test func pastTheFirstOrTheLastAskItRubberBandsAndSpringsBack() throws {
        let run = try Self.asksOpen()

        try Self.drag(run, -100)

        let near = try #require(run.asksShown?.slid)

        for _ in 0 ..< 20 {
            try Self.swipe(run, .changed, along: -5)
        }

        let far = try #require(run.asksShown?.slid)

        #expect(near < 0 && near > -100 && run.asksShown?.beside == nil)
        #expect(far < near && abs(far - near) < abs(near))
        try Self.swipe(run, .ended, along: 0)
        _ = try Self.settling(run)
        #expect(run.asksShown?.ask.id == "k1" && run.asksShown?.slid == 0)

        #expect(run.press(Self.at(run, try Self.part(.page(1), run), Self.setting())) == .asks)
        _ = try Self.settling(run)
        try Self.drag(run, 300, each: 20)
        #expect((0 ..< 300).contains(try #require(run.asksShown?.slid)) && run.asksShown?.beside == nil)
        try Self.swipe(run, .ended, along: 0)
        _ = try Self.settling(run)
        #expect(run.asksShown?.ask.id == "k2" && run.asksShown?.slid == 0)
    }

    /// A gesture the Mac cancels springs back however far it went.
    @Test func aCancelledGestureSpringsBack() throws {
        let run = try Self.asksOpen()

        try Self.drag(run, 250)
        try Self.swipe(run, .cancelled, along: 0)
        #expect(run.asksShown?.ask.id == "k1" && run.asking.isSliding)
        _ = try Self.settling(run)
        #expect(run.asksShown?.slid == 0)
    }

    /// A dot's click and a wheel's step slide as a completed swipe does: the ask it leaves out on one side, its own in
    /// from the other, settling with the spring, the dots following.
    @Test func aDotsClickAndAWheelsStepSlide() throws {
        let run = try Self.asksOpen()

        #expect(run.press(Self.at(run, try Self.part(.page(1), run), Self.setting())) == .asks)

        let asks = try #require(run.asksShown)

        #expect(asks.ask.id == "k2" && asks.slid == -AsksLayout.width && asks.beside?.page == 0)
        #expect(asks.progress == 0 && run.needsFrames(at: run.time))
        #expect(Double(try Self.settling(run).count) * Self.frameMS < 500)
        #expect(run.asksShown?.progress == 1)

        try Self.swipe(run, .wheel, along: -16, after: AsksSwipe.wheelGap + 1)
        #expect(run.asksShown?.ask.id == "k1" && run.asksShown?.slid == AsksLayout.width)
        #expect(run.asksShown?.beside?.page == 1)
    }

    /// The asks panel is as tall as the slide has come between its ask's height and the one beside it's, and settles
    /// at the other's.
    @Test func itsHeightFollowsTheSlide() throws {
        let run = try Self.asksOpen(), tall = try #require(run.asksShown?.layout.height)

        try Self.drag(run, AsksLayout.width / 2, each: 6)

        let asks = try #require(run.asksShown), short = try #require(asks.beside?.layout.height)

        #expect(short < tall)
        #expect(abs(asks.frame.height - (tall + short) / 2) < 1e-9)
        try Self.swipe(run, .ended, along: 0)
        _ = try Self.settling(run)
        #expect(run.asksShown.map { Double($0.frame.height) } == short)
    }

    /// Under Reduce motion nothing slides: the ask stays still under the fingers, and a completed swipe or a dot shows
    /// the other ask at once, its height with it; the beat starts as the page completes.
    @Test func underReduceMotionNothingSlides() throws {
        let setting = Self.setting(reducesMotion: true), run = try Self.asksOpen(Self.helpDesk, setting)

        try Self.drag(run, 200, setting)
        #expect(run.asksShown?.slid == 0 && run.asksShown?.beside == nil && run.asksShown?.ask.id == "k1")
        try Self.swipe(run, .ended, along: 0, setting)

        let asks = try #require(run.asksShown)

        #expect(asks.ask.id == "k2" && asks.slid == 0 && asks.frame.height == asks.layout.height)
        #expect(!run.asking.isSliding)

        let approve = try Self.part(.answer(0), run, setting)

        #expect(run.press(Self.at(run, approve, setting)) == nil)
        Self.frames(run, for: AsksPanel.settle, approve, setting)
        #expect(run.press(Self.at(run, approve, setting)) == .answer(Self.approve))

        #expect(run.press(Self.at(run, try Self.part(.page(0), run, setting), setting)) == .asks)
        #expect(run.asksShown?.ask.id == "k1" && run.asksShown?.slid == 0 && !run.asking.isSliding)
    }

    /// Nothing on it lights while it slides, and a press then lands on nothing, but for a dot in the settle; once it
    /// stops, a press lands.
    @Test func aPressDuringADragOrTheSettleLandsOnNothingButADotInTheSettle() throws {
        let run = try Self.asksOpen(), setting = Self.setting(), threaded = try Self.part(.answer(0), run)

        try Self.drag(run, 60)
        #expect(run.press(Self.at(run, threaded, setting)) == nil)
        #expect(run.press(Self.at(run, try Self.part(.page(1), run), setting)) == nil)
        #expect(run.asksShown?.ask.id == "k1" && run.asksShown?.hover == nil)

        try Self.swipe(run, .ended, along: 0)
        #expect(run.press(Self.at(run, threaded, setting)) == nil)
        _ = try Self.settling(run)
        #expect(run.press(Self.at(run, threaded, setting)) == .answer(Self.threaded))

        try Self.drag(run, 200)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k2")
        #expect(run.press(Self.at(run, try Self.part(.page(0), run), setting)) == .asks)
        #expect(run.asksShown?.ask.id == "k1")
    }

    /// Paging is no answer: an answer held stays held as the asks slide away and back, the ask beside sending as it
    /// slides in, its Undo with its ask; the other ask takes none meanwhile.
    @Test func anAnswerHeldKeepsItsHoldThroughASlide() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))
        try Self.drag(run, 200)
        #expect(run.asksShown?.sending?.words == "Threaded" && run.asksShown?.beside?.sending == nil)
        try Self.swipe(run, .ended, along: 0)
        _ = try Self.settling(run)
        Self.frames(run, for: AsksPanel.settle, try Self.onAsks(run, down: 70), setting)
        #expect(run.asksShown?.ask.id == "k2" && run.asksShown?.sending == nil && run.asking.isHolding)
        #expect(run.press(Self.at(run, try Self.part(.answer(0), run), setting)) == nil)

        try Self.drag(run, -100)
        #expect(run.asksShown?.beside?.ask.id == "k1" && run.asksShown?.beside?.sending?.words == "Threaded")
        for _ in 0 ..< 10 {
            try Self.swipe(run, .changed, along: -5)
        }
        try Self.swipe(run, .ended, along: 0)
        _ = try Self.settling(run)
        Self.frames(run, for: AsksPanel.settle, try Self.onAsks(run, down: 70), setting)
        #expect(run.asksShown?.sending?.words == "Threaded")
        #expect(run.press(Self.at(run, try Self.part(.undo, run), setting)) == .undo)
    }

    /// A scroll more down than along, once it has gone 6 points, is no swipe for the rest of its gesture, whatever it
    /// comes to along: nothing slides or pages.
    @Test func aVerticalScrollOnItNeverPages() throws {
        let run = try Self.asksOpen()

        try Self.swipe(run, .began, along: 0)
        try Self.swipe(run, .changed, along: 4, down: 20)
        try Self.swipe(run, .changed, along: 140)
        #expect(run.asksShown?.slid == 0 && !run.asking.isSliding)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k1" && !run.asking.isSliding)
    }

    /// A swipe across under way keeps every scroll of its gesture, the pointer drifting off the asks panel onto the
    /// list: the list never scrolls under it, though the drift goes down too, and its lift still completes. The next
    /// gesture there is the list's.
    @Test func aSwipeUnderWayKeepsItsScrollsOffTheAsksPanel() throws {
        let setting = Self.setting(stage: Self.short), run = try Self.asksOpen(Self.helpDesk, setting)
        let list = try Self.words(Self.dataImport, run, setting)

        try Self.drag(run, 100, setting)
        try Self.swipe(run, .changed, along: 60, down: 30, setting, at: list)
        try Self.swipe(run, .ended, along: 0, setting, at: list)
        #expect(run.asksShown?.ask.id == "k2" && run.scroll == 0)

        try Self.swipe(run, .began, along: 0, setting, at: list)
        try Self.swipe(run, .changed, along: 0, down: 30, setting, at: list)
        #expect(run.scroll > 0)
    }

    /// A mouse's wheel, with no phases, scrolls one gesture until 300ms pass with none: a scroll back straight after a
    /// step takes none; one after a pause does.
    @Test func aWheelsScrollsAreOneGestureUntilAPause() throws {
        let run = try Self.asksOpen()

        try Self.swipe(run, .wheel, along: 16)
        #expect(run.asksShown?.ask.id == "k2")
        try Self.swipe(run, .wheel, along: -16, after: 100)
        #expect(run.asksShown?.ask.id == "k2")
        try Self.swipe(run, .wheel, along: -16, after: AsksSwipe.wheelGap + 1)
        #expect(run.asksShown?.ask.id == "k1")
    }

    /// A lift at the end of a long, fast swipe, the ask beside slid all the way in, settles without passing its place:
    /// the fingers' speed takes it no further, and the ask it left never peeks back in.
    @Test func aLiftAtTheEndOfALongFastSwipeNeverPassesItsPlace() throws {
        let run = try Self.asksOpen()

        try Self.drag(run, 400, each: 20)
        #expect(run.asksShown?.slid == AsksLayout.width)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k2")
        #expect(try Self.settling(run).allSatisfy { $0 <= 0 })
        #expect(run.asksShown?.slid == 0 && run.asksShown?.beside == nil)
    }

    /// A swipe whose lift never came, the rest of its gesture gone to another window, ends at the next gesture's first
    /// scroll, a vertical one too: its ask springs back and the frames stop; a new swipe then follows the fingers from
    /// its place.
    @Test func aSwipeWhoseLiftNeverCameEndsAtTheNextGesture() throws {
        let run = try Self.asksOpen()

        try Self.drag(run, 100)
        try Self.swipe(run, .began, along: 0)
        try Self.swipe(run, .changed, along: 0, down: 20)
        #expect(!run.asking.isFollowing && !run.isSwiping)
        _ = try Self.settling(run)
        #expect(run.asksShown?.slid == 0 && run.asksShown?.ask.id == "k1" && !run.needsFrames(at: run.time))

        try Self.swipe(run, .ended, along: 0)
        try Self.drag(run, 60)
        #expect(run.asksShown?.slid == 60)
    }

    /// The asks panel closing mid-drag ends its swipe: no frames run for it, and the gesture's next scroll is the
    /// list's.
    @Test func theAsksPanelClosingMidDragEndsItsSwipe() throws {
        let run = try Self.asksOpen(), setting = Self.setting(), arrow = try Self.arrow(Self.helpDesk, run)

        try Self.drag(run, 100)
        #expect(run.isSwiping)
        #expect(run.press(Self.at(run, arrow, setting)) == .asks)
        #expect(run.asksShown == nil && !run.isSwiping && !run.asking.isSliding)
        Self.frames(run, for: 1000, arrow, setting) { !run.needsFrames(at: run.time) }
        #expect(!run.needsFrames(at: run.time))
    }

    /// The ask shown leaving mid-drag, its answer gone, stands the ask that took its place still under the fingers
    /// until they lift, and their lift completes nothing: no ask is skipped. The next swipe follows the fingers.
    @Test func theAskShownLeavingMidDragStandsStillUntilTheLift() throws {
        let run = try Self.asksOpen(Self.helpDesk, board: AsksBoard.board(withNotes: true)), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))
        try Self.drag(run, 150)
        run.heard(.went(Self.threaded), Self.at(run, nil, setting))
        #expect(run.asksShown?.ask.id == "k2" && run.asksShown?.slid == 0 && run.asksShown?.beside == nil)
        for _ in 0 ..< 20 {
            try Self.swipe(run, .changed, along: 5)
        }
        #expect(run.asksShown?.slid == 0)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k2" && !run.asking.isSliding)

        try Self.drag(run, 60)
        #expect(run.asksShown?.slid == 60 && run.asksShown?.beside?.ask.id == "k4")
    }

    /// An ask before the one shown leaving mid-drag, its answer gone or the board leaving it out, moves the ask shown
    /// a page along under the fingers: it slides on as it was, with the same ask beside, and its lift completes to that
    /// ask.
    @Test(arguments: [false, true])
    func anAskBeforeTheOneShownLeavingMidDragLeavesTheSlideAsItWas(onTheBoard: Bool) throws {
        let board = AsksBoard.board(withNotes: true), run = try Self.asksOpen(Self.helpDesk, board: board)
        let setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))
        #expect(run.press(Self.at(run, try Self.part(.page(1), run), setting)) == .asks)
        _ = try Self.settling(run)
        try Self.drag(run, 150)
        if onTheBoard {
            _ = run.show(AsksBoard.board(without: ["k1"], withNotes: true), Self.at(run, nil, setting))
        } else {
            run.heard(.went(Self.threaded), Self.at(run, nil, setting))
        }

        let asks = try #require(run.asksShown)

        #expect(asks.ask.id == "k2" && asks.page == 0 && asks.slid == 150)
        #expect(asks.beside?.ask.id == "k4" && asks.beside?.page == 1)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k4")
    }

    /// A second flick during the first's settle goes on to the ask after, as the Mac's swipe between Spaces does, never
    /// sliding more than one ask away.
    @Test func aSecondFlickDuringTheSettleGoesOnToTheAskAfter() throws {
        let run = try Self.asksOpen(Self.helpDesk, board: AsksBoard.board(withNotes: true)), setting = Self.setting()

        try Self.drag(run, 60, each: 20)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k2")
        Self.frames(run, for: 3 * Self.frameMS, try Self.onAsks(run, down: 70), setting)
        #expect(run.asking.isSliding)

        try Self.drag(run, 60, each: 20)
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k4")

        let on = try Self.settling(run)

        #expect(on.allSatisfy { abs($0) <= AsksLayout.width } && run.asksShown?.slid == 0)
    }

    /// A dot's click during another's settle slides from where the asks stand, never from more than one ask away,
    /// which would leave the black between them.
    @Test func aDotsClickDuringASettleSlidesFromNoMoreThanOneAskAway() throws {
        let run = try Self.asksOpen(Self.helpDesk, board: AsksBoard.board(withNotes: true)), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.page(1), run), setting)) == .asks)
        Self.frames(run, for: 2 * Self.frameMS, try Self.onAsks(run, down: 70), setting)
        #expect(run.press(Self.at(run, try Self.part(.page(2), run), setting)) == .asks)
        #expect(run.asksShown?.ask.id == "k4" && run.asksShown?.slid == -AsksLayout.width)
        #expect(try Self.settling(run).allSatisfy { abs($0) <= AsksLayout.width })
    }

    /// Fingers taking hold of a dot's settle across asks carry the same two asks, the ask beside staying the one the
    /// dot left, and a lift past a third of the way to it completes to it.
    @Test func aSwipeDuringADotsSettleCarriesTheSameTwoAsks() throws {
        let run = try Self.asksOpen(Self.helpDesk, board: AsksBoard.board(withNotes: true)), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.page(2), run), setting)) == .asks)
        #expect(run.asksShown?.beside?.page == 0)
        try Self.drag(run, 20)
        #expect(run.asksShown?.ask.id == "k4" && run.asksShown?.beside?.ask.id == "k1")
        try Self.swipe(run, .ended, along: 0)
        #expect(run.asksShown?.ask.id == "k1")
    }

    /// A dot takes the clicks where it is drawn as the asks slide, the wide one passing between them, not where it
    /// stands at rest.
    @Test func aDotTakesTheClicksWhereItIsDrawnAsTheAsksSlide() throws {
        let run = try Self.asksOpen(Self.helpDesk, board: AsksBoard.board(withNotes: true)), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.page(2), run), setting)) == .asks)
        run.step(Self.at(run, try Self.onAsks(run, down: 70), setting))

        let asks = try #require(run.asksShown), drawn = asks.layout.dots(at: asks.progress, of: 3)[1]
        let rest = asks.layout.dots(page: 2, of: 3)

        #expect(asks.progress < 0.5 && rest[2].minX < drawn.midX)
        #expect(run.press(Self.at(run, try Self.part(.page(1), run), setting)) == .asks)
        #expect(run.asksShown?.ask.id == "k2")
    }

    /// Under Reduce motion, fingers on the asks panel move nothing, so they run no frames.
    @Test func underReduceMotionADragRunsNoFrames() throws {
        let setting = Self.setting(reducesMotion: true), run = try Self.asksOpen(Self.helpDesk, setting)

        Self.frames(run, for: 1000, try Self.onAsks(run, down: 70), setting) { !run.needsFrames(at: run.time) }
        try Self.drag(run, 100, setting)
        #expect(run.asking.isFollowing && !run.needsFrames(at: run.time))
    }

    // MARK: The right edge

    /// On the right edge the arrow is at the row's left end, in its dot's place, the end by the asks panel: lit there,
    /// a press there opens the asks panel; at the row's right end, where the time stays, the pointer lights no arrow,
    /// and a press jumps.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func onTheRightEdgeTheArrowIsAtTheRowsLeftEnd(_ style: NotchStyle) throws {
        let setting = Self.setting(right: true, style: style), run = Self.opened(setting)
        let row = try Self.row(Self.helpDesk, run)
        let atLeft = RowArrow.box(in: row.size, pointsLeft: true), atRight = RowArrow.box(in: row.size)
        let arrow = try Self.onStage(row.minX + atLeft.midX, row.minY + atLeft.midY, run, setting)
        let time = try Self.onStage(row.minX + atRight.midX, row.minY + atRight.midY, run, setting)

        run.step(Self.at(run, arrow, setting))
        #expect(run.arrows(in: setting) == [Self.helpDesk: true])
        run.step(Self.at(run, time, setting))
        #expect(run.arrows(in: setting) == [Self.helpDesk: false])
        guard case .jump? = run.press(Self.at(run, time, setting)) else {
            Issue.record("a press at the row's right end did not jump")
            return
        }

        let opening = Self.opened(setting)

        #expect(opening.press(Self.at(opening, arrow, setting)) == .asks)
        #expect(opening.asksShown?.row == Self.helpDesk)
    }

    /// On the right edge the way from the arrow, where it now stands, to the last answer keeps the panel open, the
    /// pointer on the list or the asks panel all the way.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func onTheRightEdgeTheWayFromTheArrowKeepsItOpen(_ style: NotchStyle) throws {
        let setting = Self.setting(right: true, style: style)
        let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
        let from = try Self.arrow(Self.helpDesk, run, setting), to = try Self.part(.answer(2), run, setting)

        for point in Self.way(from: from, to: to, at: 0.3) {
            run.step(Self.at(run, point, setting))
        }
        Self.frames(run, for: 2000, to, setting)
        #expect(run.phase == .open && run.asksShown?.hover == .answer(2))
    }

    /// Mirrored on the right edge, it still reads left to right: its rows where they are drawn.
    @Test(arguments: [NotchStyle.meniscus, .card])
    func onTheRightEdgeItReadsLeftToRight(_ style: NotchStyle) throws {
        let setting = Self.setting(right: true, style: style), run = try Self.asksOpen(Self.helpDesk, setting)
        let asks = try #require(run.asksShown), panel = try #require(run.frame.panel)

        #expect(asks.frame.minX == panel.frame.maxX - CGFloat(AsksLayout.overlap))
        #expect(
            run.press(Self.at(run, try Self.part(.answer(1), run, setting), setting))
                == .answer(Answering(.words("Flat"), to: "k1", of: AsksBoard.helpDesk, wanting: .choice))
        )
    }
}
