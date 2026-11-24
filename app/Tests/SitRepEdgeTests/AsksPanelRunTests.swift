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

    private static func setting(
        right: Bool = false, style: NotchStyle = .meniscus, answers: Bool = true
    ) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: stage, mirror: right ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 800, ty: 0) : .identity,
            style: style, reducesMotion: false, isChosen: true, answers: answers
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
    private static func opened(_ setting: NotchRun.Setting = setting()) -> NotchRun {
        let folding = Folding()

        folding.set(.snoozed, folded: false)

        let run = NotchRun(at: 1000, in: setting, folding: folding)

        _ = run.show(AsksBoard.board(), at(run, nil, setting))
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

    /// A row's frame in the content's own frame.
    private static func row(_ key: String, _ run: NotchRun) throws -> CGRect {
        let index = try #require(run.list.index(of: key), "no row \(key)")

        return run.list.content.itemFrame(index)
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
        let asks = try #require(run.asksShown(in: setting))
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

    /// The run with the asks panel opened from a row's arrow.
    private static func asksOpen(_ key: String = helpDesk, _ setting: NotchRun.Setting = setting()) throws -> NotchRun {
        let run = opened(setting)

        #expect(run.press(at(run, try arrow(key, run, setting), setting)) == .asks)
        return run
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

    /// In glass, which draws no arrow yet, a row's time is the row's, as before.
    @Test func whereTheDrawingDrawsNoArrowAPressOnTheRowsTimeJumps() throws {
        let setting = Self.setting(answers: false), run = Self.opened(setting)
        let there = try Self.arrow(Self.helpDesk, run, setting)

        run.step(Self.at(run, there, setting))
        #expect(run.arrows(in: setting).isEmpty)
        guard case let .jump(session, to: _, click: _)? = run.press(Self.at(run, there, setting)) else {
            Issue.record("a press on the row's time did not jump")
            return
        }
        #expect(session.id == AsksBoard.helpDesk)
    }

    /// Lee choosing glass, which draws none yet, closes it.
    @Test func itClosesWhereTheDrawingDrawsNone() throws {
        let run = try Self.asksOpen()

        run.step(Self.at(run, Self.onTheNotch, Self.setting(answers: false)))
        #expect(run.asksShown(in: Self.setting()) == nil)
    }

    // MARK: Opening and closing

    @Test func aPressOnTheArrowOpensTheAsksPanelAndOnTheWordsJumps() throws {
        let run = try Self.asksOpen(), setting = Self.setting()
        let asks = try #require(run.asksShown(in: setting))

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
        #expect(jumping.asksShown(in: setting) == nil)
    }

    @Test func anotherRowsArrowMovesItAndTheLitArrowClosesIt() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.arrow(Self.shifts, run), setting)) == .asks)
        #expect(run.asksShown(in: setting)?.row == Self.shifts)
        #expect(run.press(Self.at(run, try Self.arrow(Self.shifts, run), setting)) == .asks)
        #expect(run.asksShown(in: setting) == nil)
        #expect(run.phase == .open)
    }

    /// Beside the list, overlapping its front by 8, its top 12 above its row's, so its top line is level with the row.
    @Test func itStandsBesideTheListLevelWithItsRow() throws {
        let run = try Self.asksOpen(), setting = Self.setting()
        let asks = try #require(run.asksShown(in: setting)), panel = try #require(run.frame.panel)
        let row = try Self.row(Self.helpDesk, run)

        #expect(asks.frame.minX == panel.frame.maxX - CGFloat(AsksLayout.overlap))
        #expect(asks.frame.width == CGFloat(AsksLayout.width))
        #expect(asks.frame.minY == panel.frame.minY + row.minY - CGFloat(run.scroll + AsksLayout.above))
        #expect(Double(asks.frame.height) == asks.layout.height)
    }

    /// Over the list's front, the asks panel is on top: a press, a right-click and the pointer there are its own.
    @Test func whereItOverlapsTheListItIsOnTop() throws {
        let run = try Self.asksOpen(), setting = Self.setting()
        let asks = try #require(run.asksShown(in: setting))
        let overlap = CGPoint(x: asks.frame.minX + 4, y: asks.frame.midY)

        #expect(run.frame.panel?.contains(overlap) == true)
        #expect(run.hits(overlap, in: setting))
        #expect(run.item(at: overlap, in: setting) == nil && run.row(at: overlap, in: setting) == nil)
        #expect(run.hits(CGPoint(x: asks.frame.maxX - 30, y: asks.frame.midY), in: setting))
    }

    @Test(arguments: [NotchStyle.meniscus, .card])
    func itHoldsThePanelOpenWhileThePointerIsOnItAndLeavingBothClosesBoth(_ style: NotchStyle) throws {
        let setting = Self.setting(style: style), run = try Self.asksOpen(Self.helpDesk, setting)
        let asks = try #require(run.asksShown(in: setting))
        let onIt = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.midY)

        Self.frames(run, for: 4000, onIt, setting)
        #expect(run.phase == .open)
        #expect(run.asksShown(in: setting) != nil)

        Self.frames(run, for: 5000, Self.away, setting) { run.phase == .closed }
        #expect(run.phase == .closed)
        #expect(run.asksShown(in: setting) == nil)
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
        let asks = try #require(words.asksShown(in: setting))

        #expect(asks.layout.open == nil && asks.layout.answers.count == 1)
        guard case let .jump(session, to: _, click: _)? = words.press(
            Self.at(words, try Self.part(.inClaude, words), setting)
        ) else {
            Issue.record("Answer in Claude did not jump")
            return
        }
        #expect(session.id == AsksBoard.shifts)
        #expect(words.asksShown(in: setting) == nil)
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
        #expect(run.asksShown(in: setting) == nil)
    }

    @Test func snoozeOffersTheRowsSessionsSnooze() throws {
        let run = try Self.asksOpen(), setting = Self.setting(), there = try Self.part(.snooze, run)

        guard case let .snooze(session, at: point)? = run.press(Self.at(run, there, setting)) else {
            Issue.record("Snooze offered nothing")
            return
        }
        #expect(session.id == AsksBoard.helpDesk && point == there)
        run.closeAsks(Self.at(run, there, setting))
        #expect(run.asksShown(in: setting) == nil)
    }

    @Test func aHeldAnswerSendsUntilUndoneAndTheAsksPanelTakesNoOther() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))

        let sending = try #require(run.asksShown(in: setting)?.sending)

        #expect(sending.row == 0 && sending.words == "Threaded" && sending.goesAt - sending.heldAt == 2000)
        #expect(run.press(Self.at(run, try Self.part(.answer(1), run), setting)) == nil)
        #expect(run.press(Self.at(run, try Self.part(.undo, run), setting)) == .undo)

        run.heard(.undone(Self.threaded), Self.at(run, nil, setting))
        #expect(run.asksShown(in: setting)?.sending == nil)
        #expect(run.asksShown(in: setting)?.ask.id == "k1")
    }

    @Test func onceAnAnswerGoesItStepsToTheNextAskAndClosesAfterTheLast() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))
        run.heard(.went(Self.threaded), Self.at(run, nil, setting))

        let next = try #require(run.asksShown(in: setting))

        #expect(next.ask.id == "k2" && next.page == 0 && next.pages == 1 && next.sending == nil)

        run.heard(.went(Self.approve), Self.at(run, nil, setting))
        #expect(run.asksShown(in: setting) == nil)
        #expect(run.phase == .open)
    }

    @Test func anAnswerTheCLIRefusesIsBackOnTheAsksPanel() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(.went(Self.threaded), Self.at(run, nil, setting))
        run.heard(.ended(Self.threaded, .refused("k1 is answered")), Self.at(run, nil, setting))

        #expect(run.asksShown(in: setting)?.pages == 2)
    }

    @Test func anAskLeavingTheBoardLeavesItAndItClosesWithNoneLeft() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        _ = run.show(AsksBoard.board(without: ["k1"]), Self.at(run, nil, setting))
        #expect(run.asksShown(in: setting)?.ask.id == "k2")
        #expect(run.asksShown(in: setting)?.pages == 1)

        _ = run.show(AsksBoard.board(without: ["k1", "k2"]), Self.at(run, nil, setting))
        #expect(run.asksShown(in: setting) == nil)
    }

    // MARK: The right edge

    /// Mirrored on the right edge, it still reads left to right: its rows where they are drawn.
    @Test func onTheRightEdgeItReadsLeftToRight() throws {
        let setting = Self.setting(right: true), run = try Self.asksOpen(Self.helpDesk, setting)
        let asks = try #require(run.asksShown(in: setting)), panel = try #require(run.frame.panel)

        #expect(asks.frame.minX == panel.frame.maxX - CGFloat(AsksLayout.overlap))
        #expect(
            run.press(Self.at(run, try Self.part(.answer(1), run, setting), setting))
                == .answer(Answering(.words("Flat"), to: "k1", of: AsksBoard.helpDesk))
        )
    }
}
