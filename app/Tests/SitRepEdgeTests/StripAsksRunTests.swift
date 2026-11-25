import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The tab's arrow and the asks panel as the strip's run has them (DESIGN, "Answering from the panel", the strip): the
/// arrow on the tab a mark pours, for a session with an ask the panel answers, at the tab's front end on either edge,
/// lit on itself; a press on it opening the asks panel beside the tab, level with it and overlapping its front, the lit
/// arrow closing it, a click on the tab's words still jumping, and while it is open, a click on the strip or the tab
/// closing it and doing nothing else; the asks panel holding the tab out while the pointer is on it or on its way to
/// it, leaving both drawing both back, the tab gliding to another mark closing it, and it never opening by itself; its
/// answers, Open in Claude, Snooze ▾ for the ask it shows, and its dots and a swipe paging it.
@Suite(.backstop)
struct StripAsksRunTests {
    private static let stage = StripStage(width: 1512, height: 982, menu: 37)
    private static let frameMS = 1000.0 / 60
    private static let away = CGPoint(x: 1300, y: 491)
    private static let helpDesk = AsksBoard.helpDesk, shifts = AsksBoard.shifts

    private static func setting(right: Bool = false, reducesMotion: Bool = false) -> StripRun.Setting {
        StripRun.Setting(
            stage: stage, reducesMotion: reducesMotion,
            mirror: right ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: Strip.depth, ty: 0) : .identity
        )
    }

    private static func at(_ run: StripRun, _ pointer: CGPoint?, _ setting: StripRun.Setting) -> StripRun.Moment {
        StripRun.Moment(time: run.time + frameMS, pointer: pointer, setting: setting)
    }

    private static func frames(
        _ run: StripRun, for ms: Double, _ pointer: CGPoint?, _ setting: StripRun.Setting,
        until done: () -> Bool = { false }
    ) {
        let end = run.time + ms

        while run.time < end, !done() {
            run.step(at(run, pointer, setting))
        }
    }

    /// Every tab's words 230 wide.
    private static func measure(_ note: @escaping () -> StripNote) -> StripMeasure {
        StripMeasure(row: { _ in 230 }, rows: { _ in 230 }, idle: { 230 })
    }

    /// A run over the asks' board, come to rest, the pointer away.
    private static func shown(_ setting: StripRun.Setting, board: PanelBoard = AsksBoard.board()) -> StripRun {
        let run = StripRun(at: 1000, in: setting, EdgeSettings(), measure: measure)

        run.show(board, at(run, nil, setting))
        frames(run, for: 3000, nil, setting) { !run.frame.isMoving }
        return run
    }

    /// A session's mark on the strip.
    private static func mark(_ id: String, _ run: StripRun) -> CGPoint {
        CGPoint(x: 18, y: run.strip.yOf(.session(id)))
    }

    /// The run with a session's tab poured out and still under the pointer on its mark.
    private static func poured(
        _ id: String = helpDesk, _ setting: StripRun.Setting = setting(), board: PanelBoard = AsksBoard.board()
    ) -> StripRun {
        let run = shown(setting, board: board), on = mark(id, run)

        frames(run, for: 2000, on, setting) { run.strip.liveTab()?.phase == .open }
        frames(run, for: 2000, on, setting) { !run.frame.isMoving }
        return run
    }

    /// The open tab, and its newest words.
    private static func tab(_ run: StripRun) throws -> (tab: StripFrame.Tab, words: StripFrame.Words) {
        let tab = try #require(run.frame.tabs.first { $0.isLive }, "no tab out")
        let words = try #require(tab.words.last)

        return (tab, words)
    }

    /// A point in the open tab's words' own frame, read left to right, on the stage: through the edge's mirror.
    private static func onTab(_ own: CGPoint, _ run: StripRun, _ setting: StripRun.Setting) throws -> CGPoint {
        let (tab, words) = try tab(run)
        let x = setting.mirror.a < 0 ? tab.box.minX + words.frame.maxX - own.x : tab.box.minX + words.frame.minX + own.x

        return CGPoint(x: x, y: tab.box.minY + words.frame.minY + own.y)
    }

    /// The middle of the open tab's arrow, at its front end, where it has one or would.
    private static func arrow(_ run: StripRun, _ setting: StripRun.Setting = setting()) throws -> CGPoint {
        let box = RowArrow.tabBox(in: try tab(run).words.frame.size, pointsLeft: setting.mirror.a < 0)

        return try onTab(CGPoint(x: box.midX, y: box.midY), run, setting)
    }

    /// The open tab's words, past the arrow on either edge.
    private static func words(_ run: StripRun, _ setting: StripRun.Setting = setting()) throws -> CGPoint {
        try onTab(CGPoint(x: 90, y: 20), run, setting)
    }

    /// The middle of a part of the asks panel as it shows, on the stage, through the edge's mirror.
    private static func part(
        _ part: AsksPart, _ run: StripRun, _ setting: StripRun.Setting = setting()
    ) throws -> CGPoint {
        let asks = try #require(run.asksShown)
        let layout = asks.layout
        let own = switch part {
        case let .answer(row): layout.answers[row]
        case let .page(page): layout.dots(page: asks.page, of: asks.pages)[page]
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

    /// A point on the asks panel as it shows, this far in from its far side and down from its top.
    private static func onAsks(_ run: StripRun, in x: Double = 40, down y: Double = 70) throws -> CGPoint {
        let asks = try #require(run.asksShown)

        return CGPoint(x: asks.frame.maxX - x, y: asks.frame.minY + y)
    }

    /// The run with the asks panel opened from the tab's arrow, the pointer still on the arrow.
    private static func asksOpen(
        _ id: String = helpDesk, _ setting: StripRun.Setting = setting(), board: PanelBoard = AsksBoard.board()
    ) throws -> StripRun {
        let run = poured(id, setting, board: board), arrow = try arrow(run, setting)

        frames(run, for: frameMS, arrow, setting)
        #expect(run.press(at(run, arrow, setting)) == .asks)
        #expect(run.release(EdgeSettings(), at(run, arrow, setting)) == nil)
        return run
    }

    private static let threaded = Answering(.words("Threaded"), to: "k1", of: AsksBoard.helpDesk, wanting: .choice)
    private static let approve = Answering(.words("Approve"), to: "k2", of: AsksBoard.helpDesk, wanting: .yes)

    private static func held(_ answering: Answering) -> AnswerNews {
        let now = Date(timeIntervalSince1970: Double(AsksBoard.at) / 1000)

        return .held(HeldAnswer(answering: answering, heldAt: now, goesAt: now.addingTimeInterval(2)))
    }

    // MARK: The tab's arrow

    /// The tab of a session with an ask the asks panel answers takes the arrow, lit with the pointer on it; a session
    /// whose waiting line is a permission prompt alone, or Lee's turn, takes none.
    @Test(arguments: [false, true])
    func theTabOfASessionWithAnAskShowsItsArrowLitOnIt(right: Bool) throws {
        let setting = Self.setting(right: right), run = Self.poured(Self.helpDesk, setting)

        #expect(run.arrow(in: setting)?.row == Self.helpDesk && run.arrow(in: setting)?.isLit == false)
        Self.frames(run, for: 100, try Self.arrow(run, setting), setting)
        #expect(run.arrow(in: setting)?.isLit == true)

        for id in [AsksBoard.ledger, "sr-ts0004"] {
            let other = Self.poured(id, setting)

            #expect(other.arrow(in: setting) == nil, "\(id) has an arrow")
            #expect(other.press(Self.at(other, try Self.arrow(other, setting), setting)) == nil)
        }
    }

    /// On the right edge the arrow is at the tab's left end, its front, where the asks panel opens: a press at its right
    /// end, where it stands on the left edge, opens nothing.
    @Test func onTheRightEdgeTheArrowIsAtTheTabsLeftEnd() throws {
        let right = Self.setting(right: true), run = Self.poured(Self.helpDesk, right)
        let (tab, words) = try Self.tab(run)
        let arrow = try Self.arrow(run, right), leftEdges = RowArrow.tabBox(in: words.frame.size, pointsLeft: false)

        #expect(arrow.x > tab.box.minX + words.frame.maxX - 50)
        #expect(run.press(Self.at(run, try Self.onTab(CGPoint(x: leftEdges.midX, y: leftEdges.midY), run, right), right))
            == nil)
        #expect(run.asksShown == nil)
        _ = run.release(EdgeSettings(), Self.at(run, nil, right))
        #expect(run.press(Self.at(run, arrow, right)) == .asks)
        #expect(run.asksShown?.row == Self.helpDesk)
    }

    // MARK: Opening and closing

    @Test func aPressOnTheArrowOpensTheAsksPanelAndOnTheWordsJumps() throws {
        let run = try Self.asksOpen(), setting = Self.setting()
        let asks = try #require(run.asksShown)

        #expect(asks.row == Self.helpDesk && asks.ask.id == "k1" && asks.page == 0 && asks.pages == 2)
        #expect(run.arrow(in: setting)?.isLit == true)

        let jumping = Self.poured(), words = try Self.words(jumping)

        #expect(jumping.press(Self.at(jumping, words, setting)) == nil)
        guard case let .jump(session, to: _, click: _)? = jumping.release(EdgeSettings(), Self.at(jumping, words, setting))
        else {
            Issue.record("a click on the tab's words did not jump")
            return
        }
        #expect(session.id == Self.helpDesk && jumping.asksShown == nil)
    }

    @Test func theLitArrowClosesIt() throws {
        let run = try Self.asksOpen(), setting = Self.setting(), arrow = try Self.arrow(run)

        #expect(run.press(Self.at(run, arrow, setting)) == .asks)
        #expect(run.asksShown == nil)
        #expect(run.strip.liveTab()?.phase == .open)
    }

    /// Beside the tab, overlapping its front by 8, its top 12 above the tab's words, so its top line is level with the
    /// row; on the right edge drawn into the screen from the tab, its front.
    @Test(arguments: [false, true])
    func itStandsBesideTheTabLevelWithIt(right: Bool) throws {
        let setting = Self.setting(right: right), run = try Self.asksOpen(Self.helpDesk, setting)
        let asks = try #require(run.asksShown), (tab, words) = try Self.tab(run)

        #expect(asks.frame.minX == tab.clip.maxX - CGFloat(AsksLayout.overlap))
        #expect(asks.frame.minY == tab.box.minY + words.frame.minY - CGFloat(AsksLayout.above))
        #expect(Double(asks.frame.height) == asks.layout.height && asks.frame.width == CGFloat(AsksLayout.width))

        let drawn = asks.frame.applying(setting.mirror), drawnTab = tab.clip.applying(setting.mirror)

        #expect(right ? drawn.maxX == drawnTab.minX + CGFloat(AsksLayout.overlap) : drawn.minX == drawnTab.maxX - 8)
    }

    /// Over the tab's front, the asks panel is on top: a press there is its own, a right-click offers no menu, and
    /// letting go jumps nowhere.
    @Test func whereItOverlapsTheTabItIsOnTop() throws {
        let run = try Self.asksOpen(), setting = Self.setting()
        let asks = try #require(run.asksShown), overlap = CGPoint(x: asks.frame.minX + 4, y: asks.frame.minY + 20)

        #expect(run.frame.covers(overlap) && run.hits(overlap))
        #expect(run.target(Self.at(run, overlap, setting)) == nil)
        run.menuClosed()
        _ = run.press(Self.at(run, overlap, setting))
        #expect(run.release(EdgeSettings(), Self.at(run, overlap, setting)) == nil)
        #expect(run.asksShown != nil)
        #expect(run.hits(CGPoint(x: asks.frame.maxX - 30, y: asks.frame.midY)))
    }

    /// The pointer on the asks panel holds the tab out; leaving both draws the tab back and closes the asks panel.
    @Test(arguments: [false, true])
    func itHoldsTheTabOutWhileThePointerIsOnItAndLeavingBothClosesBoth(right: Bool) throws {
        let setting = Self.setting(right: right), run = try Self.asksOpen(Self.helpDesk, setting)

        Self.frames(run, for: 4000, try Self.onAsks(run), setting)
        #expect(run.strip.liveTab()?.phase == .open && run.asksShown != nil)

        Self.frames(run, for: 3000, Self.away, setting) { run.strip.liveTab() == nil }
        #expect(run.strip.liveTab() == nil && run.asksShown == nil)
    }

    /// While it is open, a click on the strip or the tab, anywhere but the arrow, on the tab's words or its own mark,
    /// closes it and does nothing else: letting go jumps nowhere and drags nothing. The next click acts. Another mark
    /// takes the tab before any click (`theTabGlidingToAnotherMarkClosesIt`).
    @Test(arguments: [Elsewhere.words, .ownMark])
    func aClickOnTheStripOrTheTabClosesItAndDoesNothingElse(_ place: Elsewhere) throws {
        let run = try Self.asksOpen(), setting = Self.setting(), point = try place.point(run)

        #expect(run.press(Self.at(run, point, setting)) == .asks)
        #expect(run.asksShown == nil)
        #expect(run.release(EdgeSettings(), Self.at(run, point, setting)) == nil)
        #expect(!run.isDragging)

        _ = run.press(Self.at(run, point, setting))
        guard case .jump? = run.release(EdgeSettings(), Self.at(run, point, setting)) else {
            Issue.record("the next click did not jump")
            return
        }
    }

    enum Elsewhere: CaseIterable {
        case words, ownMark

        func point(_ run: StripRun) throws -> CGPoint {
            switch self {
            case .words: try StripAsksRunTests.words(run)
            case .ownMark: StripAsksRunTests.mark(StripAsksRunTests.helpDesk, run)
            }
        }
    }

    /// A click in another app draws the tab back, and the asks panel closes with it.
    @Test func aClickOffTheStripClosesBoth() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.clickElsewhere(Self.at(run, Self.away, setting))
        #expect(run.asksShown == nil)
    }

    /// The pointer moving along the strip to another mark glides the tab there: the asks panel, its tab's session's,
    /// closes, and opens for the other only from its arrow.
    @Test func theTabGlidingToAnotherMarkClosesIt() throws {
        let run = try Self.asksOpen(), setting = Self.setting(), other = Self.mark(Self.shifts, run)

        Self.frames(run, for: 1000, other, setting) { run.asksShown == nil }
        #expect(run.asksShown == nil)
        Self.frames(run, for: 1000, other, setting) { !run.frame.isMoving }
        #expect(run.arrow(in: setting)?.row == Self.shifts && run.asksShown == nil)
    }

    /// Nothing opens it but its arrow: the pointer resting on the tab, and a new ask arriving for its session, leave it
    /// closed.
    @Test func itNeverOpensByItself() throws {
        let run = Self.poured(Self.helpDesk, Self.setting(), board: AsksBoard.board(without: ["k1"]))
        let setting = Self.setting(), words = try Self.words(run)

        Self.frames(run, for: 1500, words, setting)
        run.show(AsksBoard.board(), Self.at(run, words, setting))
        Self.frames(run, for: 1500, words, setting)
        #expect(run.asksShown == nil && run.strip.liveTab()?.phase == .open)
    }

    // MARK: The pointer on its way

    /// From the tab's words to the last answer of a choice of three, below the tab, the straight way off both keeps the
    /// tab out and the asks panel open, though slow enough to outlast a leave's grace, on either edge.
    @Test(arguments: [false, true])
    func theWayFromTheTabToTheAsksPanelKeepsItOpen(right: Bool) throws {
        let setting = Self.setting(right: right)
        let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
        let from = try Self.onTab(CGPoint(x: 60, y: 44), run, setting), to = try Self.part(.answer(2), run, setting)
        let off = try Self.offBoth(run, from: from, to: to)

        try #require(off.length > 30, "the way hardly leaves both")
        Self.frames(run, for: Self.frameMS, from, setting)
        for point in Self.way(from: from, to: to, at: off.length / (SafeTriangle.lasts - 60)) {
            run.step(Self.at(run, point, setting))
        }
        Self.frames(run, for: 1000, to, setting)
        #expect(run.strip.liveTab()?.phase == .open && run.asksShown?.hover == .answer(2))
    }

    /// A pointer that rests on the way is off both at once: the tab draws back, and the asks panel closes.
    @Test func aPointerRestingOnTheWayClosesIt() throws {
        let setting = Self.setting()
        let run = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
        let from = try Self.onTab(CGPoint(x: 60, y: 44), run, setting), to = try Self.part(.answer(2), run, setting)
        let off = try Self.offBoth(run, from: from, to: to)
        let way = Self.way(from: from, to: to, at: 1)
        let halfway = try #require(way.firstIndex { hypot($0.x - off.middle.x, $0.y - off.middle.y) < 20 })

        Self.frames(run, for: Self.frameMS, from, setting)
        for point in way[...halfway] {
            run.step(Self.at(run, point, setting))
        }
        Self.frames(run, for: 2000, way[halfway], setting) { run.asksShown == nil }
        #expect(run.asksShown == nil)
    }

    /// The points a pointer gives at this speed, pt/ms, a frame apart, from one point to another, the last one too.
    private static func way(from: CGPoint, to: CGPoint, at speed: Double) -> [CGPoint] {
        let length = hypot(to.x - from.x, to.y - from.y)
        let steps = max(1, Int((length / (speed * frameMS)).rounded(.up)))

        return (1 ... steps).map { step in
            let share = Double(step) / Double(steps)

            return CGPoint(x: from.x + (to.x - from.x) * share, y: from.y + (to.y - from.y) * share)
        }
    }

    /// How much of the straight way between two points is off both the strip and its tab and the asks panel, and its
    /// middle.
    private static func offBoth(
        _ run: StripRun, from: CGPoint, to: CGPoint
    ) throws -> (length: Double, middle: CGPoint) {
        let asks = try #require(run.asksShown)
        let steps = 400, length = hypot(to.x - from.x, to.y - from.y)
        let off = (0 ... steps).map { step in
            CGPoint(
                x: from.x + (to.x - from.x) * Double(step) / Double(steps),
                y: from.y + (to.y - from.y) * Double(step) / Double(steps)
            )
        }.filter { !run.frame.covers($0) && !asks.frame.contains($0) }

        return (length * Double(off.count) / Double(steps), off.isEmpty ? from : off[off.count / 2])
    }

    // MARK: Answering

    /// Its answers hold what they answer, once what it shows has stood the beat; a held answer sends until undone.
    @Test func anAnswersRowAndIgnoreHoldTheirAnswersAndUndoTakesThemBack() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        Self.frames(run, for: AsksPanel.settle, try Self.onAsks(run), setting)
        #expect(run.press(Self.at(run, try Self.part(.answer(0), run), setting)) == .answer(Self.threaded))
        #expect(
            run.press(Self.at(run, try Self.part(.ignore, run), setting))
                == .answer(Answering(.ignore, to: "k1", of: Self.helpDesk, wanting: .choice))
        )

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))
        #expect(run.asksShown?.sending?.words == "Threaded")
        #expect(run.press(Self.at(run, try Self.part(.undo, run), setting)) == .undo)
    }

    @Test func onceAnAnswerGoesItStepsToTheNextAskAndClosesAfterTheLast() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, nil, setting))
        run.heard(.went(Self.threaded), Self.at(run, nil, setting))
        #expect(run.asksShown?.ask.id == "k2" && run.asksShown?.pages == 1)

        run.heard(.went(Self.approve), Self.at(run, nil, setting))
        #expect(run.asksShown == nil && run.arrow(in: setting) == nil)
    }

    /// Open in Claude jumps as a click on the tab does, pressing it in, and closes the asks panel.
    @Test func openInClaudeJumpsAsTheTabDoesClosingIt() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        Self.frames(run, for: AsksPanel.settle, try Self.onAsks(run), setting)
        guard case let .jump(session, to: target, click: click)? = run.press(
            Self.at(run, try Self.part(.open, run), setting)
        ) else {
            Issue.record("Open in Claude did not jump")
            return
        }
        #expect(session.id == Self.helpDesk && target == Self.helpDesk && click == 1)
        #expect(run.asksShown == nil)
        run.step(Self.at(run, nil, setting))
        #expect(run.frame.isJumping)
    }

    /// Snooze ▾ offers the snooze of the ask it shows, the one paged to; while Snooze offers no time, there is none.
    @Test func snoozeOffersTheSnoozeOfTheAskItShows() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.page(1), run), setting)) == .asks)
        Self.frames(run, for: 1000, try Self.onAsks(run), setting)

        let there = try Self.part(.snooze, run)

        #expect(run.press(Self.at(run, there, setting)) == .snooze(ask: "k2", of: Self.helpDesk, at: there))
        run.menuOpened(at: there)
        Self.frames(run, for: 2000, Self.away, setting)
        #expect(run.strip.liveTab()?.phase == .open && run.asksShown != nil)
        run.menuClosed()
        run.closeAsks(Self.at(run, there, setting))
        #expect(run.asksShown == nil)

        var none = Self.setting()

        none.offersSnooze = false
        #expect(try Self.asksOpen(Self.helpDesk, none).asksShown?.layout.snooze == nil)
    }

    /// Mirrored on the right edge, it still reads left to right: its rows where they are drawn.
    @Test func onTheRightEdgeItReadsLeftToRight() throws {
        let right = Self.setting(right: true), run = try Self.asksOpen(Self.helpDesk, right)

        Self.frames(run, for: AsksPanel.settle, try Self.onAsks(run), right)
        #expect(
            run.press(Self.at(run, try Self.part(.answer(1), run, right), right))
                == .answer(Answering(.words("Flat"), to: "k1", of: Self.helpDesk, wanting: .choice))
        )
    }

    // MARK: Paging

    @Test func aClickOnADotShowsItsAsk() throws {
        let run = try Self.asksOpen(), setting = Self.setting()

        #expect(run.press(Self.at(run, try Self.part(.page(1), run), setting)) == .asks)
        #expect(run.asksShown?.ask.id == "k2")
        #expect(run.press(Self.at(run, try Self.part(.page(0), run), setting)) == .asks)
        #expect(run.asksShown?.ask.id == "k1")
    }

    /// Two fingers on the asks panel slide its ask with them, and past a third of its width the lift completes to the
    /// next; a wheel's step goes back.
    @Test func aSwipeFollowsTheFingersAndAWheelSteps() throws {
        let run = try Self.asksOpen(), setting = Self.setting(), onIt = try Self.onAsks(run)
        let scroll = { (phase: Scroll.Phase, along: Double) in
            run.scroll(Scroll(down: 0, along: along, phase: phase), Self.at(run, onIt, setting))
        }

        scroll(.began, 0)
        for _ in 0 ..< 26 {
            scroll(.changed, 5)
        }
        #expect(run.asksShown?.slid == 130 && run.asksShown?.beside?.ask.id == "k2")
        #expect(run.needsFrames)
        scroll(.ended, 0)
        #expect(run.asksShown?.ask.id == "k2")
        Self.frames(run, for: 1000, onIt, setting) { !run.needsFrames }
        #expect(run.asksShown?.slid == 0 && run.strip.liveTab()?.phase == .open)

        run.scroll(Scroll(down: 0, along: -16), Self.at(run, onIt, setting))
        #expect(run.asksShown?.ask.id == "k1")
    }
}
