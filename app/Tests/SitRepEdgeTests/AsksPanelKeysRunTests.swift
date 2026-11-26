import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The asks panel's keys as the notch's run has them (DESIGN, "Keys", "On the asks panel"): while it is open and the
/// panel holds the keys, wherever the pointer is on the panel, `1`–`9` press that answer's row, `x` Ignore, `z`
/// Snooze ▾ and `o` Open in Claude, each as its click does; `←` `→` page as the dots lie, sliding as a dot's click
/// does; `s` does nothing. While an answer is sending, digits and `x` do nothing and `⌘Z` is the sending line's Undo,
/// every other key acting and the answer still going. The 300ms beat holds a key after a change the keys didn't make,
/// and none after their own paging. The answers show their keycaps while the panel holds the keys and no answer is
/// held.
@Suite(.backstop)
struct AsksPanelKeysRunTests {
    private static let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)
    private static let frameMS = 1000.0 / 60
    private static let helpDesk = "needs:\(AsksBoard.helpDesk)", shifts = "needs:\(AsksBoard.shifts)"
    private static let dataImport = "needs:\(AsksBoard.dataImport)"

    private static func setting(
        right: Bool = false, reducesMotion: Bool = false, offersSnooze: Bool = true, takesKeys: Bool = true
    ) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: stage, mirror: right ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 800, ty: 0) : .identity,
            style: .meniscus, reducesMotion: reducesMotion, offersSnooze: offersSnooze, takesKeys: takesKeys
        )
    }

    private static func at(_ run: NotchRun, _ pointer: CGPoint?, _ setting: NotchRun.Setting) -> NotchRun.Moment {
        NotchRun.Moment(time: run.time + frameMS, pointer: pointer, setting: setting)
    }

    private static func frames(_ run: NotchRun, for ms: Double, _ pointer: CGPoint?, _ setting: NotchRun.Setting) {
        let end = run.time + ms

        while run.time < end {
            run.step(at(run, pointer, setting))
        }
    }

    /// A run over the asks' board, Snoozed unfolded, its panel opened by the pointer held on the notch, and at rest.
    private static func opened(_ setting: NotchRun.Setting, board: PanelBoard) -> NotchRun {
        let folding = Folding()

        folding.set(.snoozed, folded: false)

        let run = NotchRun(at: 1000, in: setting, folding: folding)
        let notch = CGPoint(x: 3, y: run.notchY)

        _ = run.show(board, at(run, nil, setting))
        while run.time < 4000, run.phase != .open || run.frame.isMoving {
            run.step(at(run, notch, setting))
        }
        return run
    }

    /// A row's words, near its left, on the stage through the edge's mirror.
    private static func words(_ key: String, _ run: NotchRun, _ setting: NotchRun.Setting) throws -> CGPoint {
        let panel = try #require(run.frame.panel), index = try #require(run.list.index(of: key), "no row \(key)")
        let row = run.list.content.laidFrame(index)

        return CGPoint(
            x: setting.mirror.a < 0 ? panel.frame.maxX - row.minX - 60 : panel.frame.minX + row.minX + 60,
            y: panel.frame.minY + row.midY - run.scroll
        )
    }

    /// The middle of a part of the asks panel as it shows, on the stage, through the edge's mirror: where its click
    /// lands.
    private static func part(
        _ part: AsksPart, _ run: NotchRun, _ setting: NotchRun.Setting = setting()
    ) throws -> CGPoint {
        let asks = try #require(run.asksShown)
        let own = try #require(asks.layout.box(of: part, progress: asks.progress, of: asks.pages))

        return CGPoint(
            x: setting.mirror.a < 0 ? asks.frame.maxX - own.midX : asks.frame.minX + own.midX,
            y: asks.frame.minY + own.midY
        )
    }

    /// The run holding the keys, the pointer moved onto the row `key`'s words, its asks panel opened by `⏎`; the
    /// pointer still on the row.
    private static func asksOpen(
        _ key: String = helpDesk, _ setting: NotchRun.Setting = setting(), board: PanelBoard = AsksBoard.board()
    ) throws -> (run: NotchRun, pointer: CGPoint) {
        let run = opened(setting, board: board), pointer = try words(key, run, setting)

        run.step(at(run, pointer, setting))
        try #require(run.holdsKeys)
        try #require(run.key(.enter, at(run, pointer, setting)) == .asks)
        try #require(run.asksShown?.row == key)
        return (run, pointer)
    }

    /// A key pressed, the pointer where it was, the hold the tap ended with it `ending`, as it ends one with `o`.
    @discardableResult
    private static func press(
        _ key: PanelKey, _ run: NotchRun, _ pointer: CGPoint, _ setting: NotchRun.Setting = setting(),
        ending: Int? = nil
    ) -> NotchRun.Press? {
        run.key(key, ending: ending, at(run, pointer, setting))
    }

    private static func held(_ answering: Answering) -> AnswerNews {
        let now = Date(timeIntervalSince1970: Double(AsksBoard.at) / 1000)

        return .held(HeldAnswer(answering: answering, heldAt: now, goesAt: now.addingTimeInterval(2)))
    }

    private static func answer(
        _ words: String, to ask: String = "k1", wanting: Board.Ask.Wants = .choice
    ) -> Answering {
        Answering(.words(words), to: ask, of: AsksBoard.helpDesk, wanting: wanting)
    }

    private static let threaded = answer("Threaded"), approve = answer("Approve", to: "k2", wanting: .yes)

    /// A trackpad's fingers on the asks panel, travelling `travel` along, 5 a frame, still on the trackpad.
    private static func drag(_ run: NotchRun, _ travel: Double, _ setting: NotchRun.Setting = setting()) throws {
        let asks = try #require(run.asksShown), onIt = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.minY + 70)
        let step = Scroll(down: 0, along: travel < 0 ? -5 : 5, phase: .changed)
        let scrolls = [Scroll(down: 0, phase: .began)] + Array(repeating: step, count: Int(abs(travel) / 5))

        for scroll in scrolls {
            run.scroll(scroll, at(run, onIt, setting))
        }
    }

    private static func lift(_ run: NotchRun, _ setting: NotchRun.Setting = setting()) throws {
        let asks = try #require(run.asksShown), onIt = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.minY + 70)

        run.scroll(Scroll(down: 0, phase: .ended), at(run, onIt, setting))
    }

    // MARK: Each key as its click

    /// `1` is the first row, Claude's pick, and each digit answers with its row as a click on the row does.
    @Test func eachDigitAnswersWithItsRowAsAClickOnItDoes() throws {
        let setting = Self.setting(), board = AsksBoard.board(alone: true)
        let (run, pointer) = try Self.asksOpen(Self.helpDesk, setting, board: board)
        let (clicked, _) = try Self.asksOpen(Self.helpDesk, setting, board: board)
        let ask = try #require(run.asksShown?.ask)

        #expect(ask.answers.first == ask.recommended)
        for (row, words) in ask.answers.enumerated() {
            let click = clicked.press(Self.at(clicked, try Self.part(.answer(row), clicked), setting))

            #expect(Self.press(.digit(row + 1), run, pointer) == .answer(Self.answer(words)))
            #expect(click == .answer(Self.answer(words)))
        }
    }

    @Test(arguments: [(Self.helpDesk, 3), (Self.shifts, 1)])
    func aDigitPastItsAnswersDoesNothing(_ key: String, digit: Int) throws {
        let (run, pointer) = try Self.asksOpen(key)

        #expect(Self.press(.digit(digit), run, pointer) == nil)
        #expect(run.asksShown?.row == key && run.asksShown?.sending == nil)
    }

    @Test func xIgnoresTheAskShown() throws {
        let (run, pointer) = try Self.asksOpen()

        #expect(
            Self.press(.ignore, run, pointer)
                == .answer(Answering(.ignore, to: "k1", of: AsksBoard.helpDesk, wanting: .choice))
        )
    }

    /// `z` offers the snooze of the ask shown from Snooze ▾, as a click on its middle does, on either edge.
    @Test(arguments: [false, true])
    func zOffersSnoozeOfTheAskShownAsAClickOnSnoozeDoes(right: Bool) throws {
        let setting = Self.setting(right: right), (run, pointer) = try Self.asksOpen(Self.helpDesk, setting)
        let button = try Self.part(.snooze, run, setting)

        guard case let .snooze(ask, of: session, at: point)? = Self.press(.snooze, run, pointer, setting) else {
            Issue.record("z offered no snooze")
            return
        }
        #expect(ask == "k1" && session == AsksBoard.helpDesk)
        #expect(abs(point.x - button.x) < 1e-9 && abs(point.y - button.y) < 1e-9)
        #expect(run.press(Self.at(run, button, setting)) == .snooze(ask: "k1", of: AsksBoard.helpDesk, at: button))
    }

    @Test func withNoSnoozeZDoesNothing() throws {
        let setting = Self.setting(offersSnooze: false), (run, pointer) = try Self.asksOpen(Self.helpDesk, setting)

        #expect(run.asksShown?.layout.snooze == nil)
        #expect(Self.press(.snooze, run, pointer, setting) == nil)
        #expect(run.asksShown?.row == Self.helpDesk)
    }

    /// `o` is Open in Claude: the row pressed in, the jump asked for, the asks panel closed and the hold ended.
    @Test func oIsOpenInClaude() throws {
        let (run, pointer) = try Self.asksOpen()

        guard case let .jump(session, to: target, click: _)? = Self.press(.open, run, pointer, ending: 1) else {
            Issue.record("o did not jump")
            return
        }
        #expect(session.id == AsksBoard.helpDesk && target == AsksBoard.helpDesk)
        #expect(run.asksShown == nil && !run.holdsKeys)
        run.step(Self.at(run, pointer, Self.setting()))
        #expect(run.frame.panel?.pressed == Self.helpDesk)
    }

    /// `o` that lands on nothing, as within the beat, still ends the hold, as the tap ended it as it took `o`.
    @Test func oThatJumpsNowhereStillEndsTheHold() throws {
        let (run, pointer) = try Self.asksOpen()

        _ = run.show(AsksBoard.board(without: ["k1"]), Self.at(run, pointer, Self.setting()))
        #expect(Self.press(.open, run, pointer, ending: 1) == nil)
        #expect(!run.holdsKeys && run.keySnapshot == .none && run.phase == .open)
    }

    @Test func sDoesNothingThere() throws {
        let (run, pointer) = try Self.asksOpen(), folded = run.folded

        #expect(Self.press(.fold, run, pointer) == nil)
        #expect(run.folded == folded && run.asksShown?.row == Self.helpDesk && run.asksShown?.page == 0)
    }

    // MARK: While an answer is sending

    /// As the answer rows and Ignore take no click then, digits and `x` do nothing; `⌘Z` is the sending line's Undo,
    /// the tap told it is the panel's while the line shows, and through the beat after it goes.
    @Test func whileSendingDigitsAndXDoNothingAndCommandZUndoes() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        #expect(run.keySnapshot == .panel(hold: 1, undoes: false))
        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        #expect(run.keySnapshot == .panel(hold: 1, undoes: true))
        #expect(Self.press(.digit(2), run, pointer) == nil)
        #expect(Self.press(.ignore, run, pointer) == nil)
        #expect(Self.press(.undo, run, pointer) == .undo)

        run.heard(.undone(Self.threaded), Self.at(run, pointer, setting))
        Self.frames(run, for: AsksPanel.settle, pointer, setting)
        #expect(run.keySnapshot == .panel(hold: 1, undoes: false))
    }

    /// Every other key acts as its click would, the answer still held to go: `→` pages to the next ask, whose foot
    /// takes `z`, though it shows no sending line for `⌘Z`; `←` back, and `esc` closes the asks panel.
    @Test func whileSendingEveryOtherKeyActsAndTheAnswerStillGoes() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        #expect(Self.press(.right, run, pointer) == .asks)
        #expect(run.asksShown?.ask.id == "k2" && run.asking.isHolding)
        #expect(run.keySnapshot == .panel(hold: 1, undoes: false))
        #expect(Self.press(.undo, run, pointer) == nil)
        #expect(Self.press(.digit(1), run, pointer) == nil)
        guard case .snooze(ask: "k2", of: AsksBoard.helpDesk, at: _)? = Self.press(.snooze, run, pointer) else {
            Issue.record("z on the next ask offered no snooze")
            return
        }

        #expect(Self.press(.left, run, pointer) == .asks)
        #expect(run.asksShown?.sending?.words == "Threaded")
        #expect(Self.press(.escape, run, pointer) == .asks)
        #expect(run.asksShown == nil && run.asking.isHolding)
    }

    @Test func withNoSendingLineCommandZDoesNothing() throws {
        let (run, pointer) = try Self.asksOpen()

        #expect(run.keySnapshot == .panel(hold: 1, undoes: false))
        #expect(Self.press(.undo, run, pointer) == nil)
    }

    // MARK: Paging

    /// `→` shows the next ask and `←` the one before, sliding as a dot's click does.
    @Test func theArrowsPageAsTheDotsLieSlidingAsADotDoes() throws {
        let (run, pointer) = try Self.asksOpen()

        #expect(Self.press(.right, run, pointer) == .asks)

        let next = try #require(run.asksShown)

        #expect(next.ask.id == "k2" && next.page == 1 && next.slid == -AsksLayout.width && next.beside?.page == 0)
        #expect(run.needsFrames(at: run.time))
        #expect(Self.press(.left, run, pointer) == .asks)
        #expect(run.asksShown?.ask.id == "k1" && run.asksShown?.page == 0)
    }

    /// Nothing wraps: `←` on the first ask and `→` on the last do nothing; a session of one ask has nothing to page.
    @Test func pastTheFirstOrTheLastAskTheArrowsDoNothing() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        #expect(Self.press(.left, run, pointer) == nil)
        #expect(run.asksShown?.page == 0 && !run.asking.isSliding)
        Self.press(.right, run, pointer)
        Self.frames(run, for: 600, pointer, setting)
        #expect(Self.press(.right, run, pointer) == nil)
        #expect(run.asksShown?.page == 1 && !run.asking.isSliding)

        let (alone, onIt) = try Self.asksOpen(Self.dataImport)

        #expect(Self.press(.right, alone, onIt) == nil && Self.press(.left, alone, onIt) == nil)
    }

    @Test func underReduceMotionTheArrowsPageAtOnce() throws {
        let setting = Self.setting(reducesMotion: true), (run, pointer) = try Self.asksOpen(Self.helpDesk, setting)

        #expect(Self.press(.right, run, pointer, setting) == .asks)
        #expect(run.asksShown?.ask.id == "k2" && run.asksShown?.slid == 0 && !run.asking.isSliding)
    }

    // MARK: The beat

    enum Change: CaseIterable {
        case board, send, dot, swipe
    }

    /// The ask shown changed by something other than the keys: the board leaving its ask out, its answer going, a
    /// click on a dot, or a swipe's lift, the board's third ask kept where it has one. Where the pointer is after it,
    /// still on the panel.
    private static func change(
        _ change: Change, _ run: NotchRun, _ pointer: CGPoint, withNotes: Bool = false
    ) throws -> CGPoint {
        let setting = Self.setting()

        switch change {
        case .board:
            _ = run.show(AsksBoard.board(without: ["k1"], withNotes: withNotes), Self.at(run, pointer, setting))
            return pointer
        case .send:
            run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
            run.heard(.went(Self.threaded), Self.at(run, pointer, setting))
            return pointer
        case .dot:
            let dot = try Self.part(.page(1), run)

            #expect(run.press(Self.at(run, dot, setting)) == .asks)
            return dot
        case .swipe:
            try Self.drag(run, 200)
            try Self.lift(run)
            return try #require(run.asksShown.map { CGPoint(x: $0.frame.maxX - 40, y: $0.frame.minY + 70) })
        }
    }

    /// Within the beat after a change the keys didn't make, a key on the ask does nothing, as a press there doesn't
    /// land; once the beat has passed it acts, though the ask may still slide.
    @Test(arguments: Change.allCases)
    func afterAChangeTheKeysDidntMakeAKeyWaitsOutTheBeat(_ change: Change) throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()
        let onPanel = try Self.change(change, run, pointer)

        #expect(run.asksShown?.ask.id == "k2")
        #expect(Self.press(.digit(1), run, onPanel) == nil)
        #expect(Self.press(.ignore, run, onPanel) == nil)
        Self.frames(run, for: AsksPanel.settle, onPanel, setting)
        try #require(run.holdsKeys)
        #expect(Self.press(.digit(1), run, onPanel) == .answer(Self.approve))
    }

    /// The arrows page beat or none, as a dot does: `←` straight after a dot's click goes back.
    @Test func theArrowsPageWithinTheBeatAsADotDoes() throws {
        let (run, pointer) = try Self.asksOpen()
        let onPanel = try Self.change(.dot, run, pointer)

        #expect(Self.press(.left, run, onPanel) == .asks)
        #expect(run.asksShown?.ask.id == "k1")
    }

    /// After a change the keys made, paging among the asks, a key acts at once, the ask still sliding in; a click
    /// still waits out the beat.
    @Test func afterTheKeysPageAKeyActsAtOnce() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        Self.press(.right, run, pointer)
        #expect(run.asking.isSliding)
        #expect(run.press(Self.at(run, try Self.part(.answer(0), run), setting)) == nil)
        #expect(Self.press(.digit(1), run, pointer) == .answer(Self.approve))
    }

    /// The arrows paging within the beat after a change they didn't make leave it holding: after a dot's click, `←`
    /// and `→`, a key still waits; after the board's change, `→` lands on the ask after, and `1` waits there too. Once
    /// the beat has passed, it answers.
    @Test(arguments: [Change.dot, .board])
    func anArrowWithinTheBeatLeavesItHolding(_ change: Change) throws {
        let setting = Self.setting(), board = AsksBoard.board(withNotes: true)
        let (run, pointer) = try Self.asksOpen(Self.helpDesk, board: board)
        let onPanel = try Self.change(change, run, pointer, withNotes: true)
        let notes = Self.answer("Ship", to: "k4", wanting: .yes)

        if change == .dot {
            #expect(Self.press(.left, run, onPanel) == .asks)
        }
        #expect(Self.press(.right, run, onPanel) == .asks)

        let answer = change == .dot ? Self.approve : notes

        #expect(run.asksShown?.ask.id == (change == .dot ? "k2" : "k4"))
        #expect(Self.press(.digit(1), run, onPanel) == nil)
        Self.frames(run, for: AsksPanel.settle, onPanel, setting)
        #expect(Self.press(.digit(1), run, onPanel) == .answer(answer))
    }

    /// A key presses no point, so the asks panel moving under a resting pointer holds no key: kept at the screen's
    /// foot, it moves as its height follows `→`'s slide to a shorter ask, which holds a click, but `1` acts at once.
    @Test func itMovingUnderARestingPointerHoldsNoKey() throws {
        let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: Self.lowNotch)
        var setting = Self.setting()

        setting.stage = stage

        let (run, _) = try Self.asksOpen(Self.helpDesk, setting, board: AsksBoard.board(alone: true))
        let asks = try #require(run.asksShown), resting = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.minY + 70)

        try #require(abs(asks.frame.maxY - (stage.visibleBottom - AsksLayout.spare)) < 1e-9)
        Self.frames(run, for: AsksPanel.settle, resting, setting)
        try #require(run.holdsKeys)
        Self.press(.right, run, resting, setting)

        let stood = try #require(run.asksShown?.frame.minY)

        Self.frames(run, for: 100, resting, setting)
        try #require(run.asking.isSliding && run.asksShown.map { $0.frame.minY > stood + 1 } == true)
        #expect(!run.asking.isSettled(at: run.time))
        #expect(Self.press(.digit(1), run, resting, setting) == .answer(Self.approve))
    }

    /// The notch's home low on the screen, so the asks panel beside Help desk redesign, alone on the board, is kept
    /// above the screen's foot.
    private static let lowNotch = 940.0

    /// `z` as the asks slide in after `→`: they come to rest first, so Snooze ▾'s menu stands under it as drawn, the
    /// card held at its middle, on the asks panel.
    @Test func zMidSlideOpensFromTheAsksAtRest() throws {
        let (run, pointer) = try Self.asksOpen()

        Self.press(.right, run, pointer)
        try #require(run.asking.isSliding)
        guard case let .snooze(ask, of: _, at: point)? = Self.press(.snooze, run, pointer) else {
            Issue.record("z offered no snooze")
            return
        }

        let asks = try #require(run.asksShown), button = try Self.part(.snooze, run)

        #expect(ask == "k2" && !run.asking.isSliding && asks.slid == 0 && asks.beside == nil)
        #expect(abs(asks.frame.height - asks.layout.height) < 1e-9)
        #expect(abs(point.x - button.x) < 1e-9 && abs(point.y - button.y) < 1e-9)
        #expect(asks.contains(point))
    }

    /// While fingers carry the asks, a key lands on nothing, as a press then does, not even a page.
    @Test func whileFingersCarryTheAsksNoKeyActs() throws {
        let (run, pointer) = try Self.asksOpen()

        try Self.drag(run, 60)
        #expect(run.asking.isFollowing)
        for key in [PanelKey.digit(1), .ignore, .snooze, .right, .left] {
            #expect(Self.press(key, run, pointer) == nil)
        }
        #expect(run.asksShown?.ask.id == "k1")
    }

    /// `o` while the ask's own answer is sending can't jump, and leaves the hold its `⌘Z`.
    @Test func oWhileSendingKeepsTheHoldForCommandZ() throws {
        let (run, pointer) = try Self.asksOpen()

        run.heard(Self.held(Self.threaded), Self.at(run, pointer, Self.setting()))
        #expect(Self.press(.open, run, pointer) == nil)
        #expect(run.holdsKeys && run.keySnapshot == .panel(hold: 1, undoes: true))
        #expect(Self.press(.undo, run, pointer) == .undo)
    }

    /// The tap alone decides whether `o` ends the hold, and the panel follows it whatever it reads by the time it
    /// hears `o`: `1` then `o`, the tap ending the hold at `o` before the answer showed, lets the hold go though the
    /// sending line shows by then; `o` the tap read with the line showing keeps it though the answer went since.
    @Test func whetherOEndsTheHoldIsTheTapsDecision() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        #expect(Self.press(.digit(1), run, pointer) == .answer(Self.threaded))
        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        try #require(run.asksShown?.sending != nil)
        #expect(Self.press(.open, run, pointer, ending: 1) == nil)
        #expect(!run.holdsKeys && run.keySnapshot == .none)

        let (kept, onIt) = try Self.asksOpen()

        kept.heard(Self.held(Self.threaded), Self.at(kept, onIt, setting))
        kept.heard(.went(Self.threaded), Self.at(kept, onIt, setting))
        try #require(kept.asksShown?.sending == nil)
        #expect(Self.press(.open, kept, onIt) == nil)
        #expect(kept.holdsKeys)
    }

    // MARK: ⌘Z through the beat

    /// `⌘Z` stays the panel's through the beat after the sending line goes, as its answer goes or is taken back, so
    /// one pressed a moment late does nothing, as a digit on nothing does, and never reaches the window in front; the
    /// frames run through the beat, so the tap is told as it ends, and then `⌘Z` is a chord again.
    @Test(arguments: [true, false])
    func commandZStaysThePanelsThroughTheBeatAfterTheSendingLineGoes(went: Bool) throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        run.heard(went ? .went(Self.threaded) : .undone(Self.threaded), Self.at(run, pointer, setting))
        try #require(run.asksShown?.sending == nil && run.asksShown?.ask.id == (went ? "k2" : "k1"))
        #expect(run.keySnapshot == .panel(hold: 1, undoes: true))
        #expect(run.needsFrames(at: run.time))
        #expect(Self.press(.undo, run, pointer) == nil)
        #expect(Self.press(.open, run, pointer) == nil && run.holdsKeys)

        Self.frames(run, for: AsksPanel.settle, pointer, setting)
        #expect(run.keySnapshot == .panel(hold: 1, undoes: false))
    }

    /// `o` the tap took ending no hold, as `⌘Z` was the panel's then, acts on nothing, though the main thread hears it
    /// only once the beat has passed, when Open in Claude would jump; `o` ending the hold there jumps.
    @Test func oTheTapKeptTheHoldWithActsOnNothingThoughTheBeatPassed() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        run.heard(.went(Self.threaded), Self.at(run, pointer, setting))
        Self.frames(run, for: AsksPanel.settle, pointer, setting)
        #expect(Self.press(.open, run, pointer) == nil)
        #expect(run.holdsKeys && run.asksShown != nil)
        guard case .jump? = Self.press(.open, run, pointer, ending: 1) else {
            Issue.record("o ending the hold did not jump")
            return
        }
    }

    /// The asks panel closed and opened again within the beat takes no `⌘Z`: closing ends the beat.
    @Test func closingTheAsksPanelEndsTheBeat() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        run.heard(.went(Self.threaded), Self.at(run, pointer, setting))
        try #require(run.keySnapshot == .panel(hold: 1, undoes: true))
        #expect(Self.press(.escape, run, pointer) == .asks)
        #expect(Self.press(.enter, run, pointer) == .asks)
        #expect(run.asksShown != nil && run.keySnapshot == .panel(hold: 1, undoes: false))
    }

    /// The keys paging away from the sending line start no beat, though they page within one a click's paging began:
    /// a dot's click to the next ask, `←` back to the sending line within its beat, and `→` away again once the
    /// dot's own beat is over, leave `⌘Z` a chord.
    @Test func theKeysPagingAwayWithinABeatStartNone() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))

        let onPanel = try Self.change(.dot, run, pointer)

        Self.frames(run, for: 250, onPanel, setting)
        #expect(Self.press(.left, run, onPanel) == .asks)
        try #require(run.asksShown?.sending != nil)
        Self.frames(run, for: 150, onPanel, setting)
        #expect(Self.press(.right, run, onPanel) == .asks)
        #expect(run.asksShown?.ask.id == "k2" && run.keySnapshot == .panel(hold: 1, undoes: false))
    }

    /// Only the sending line going starts it: paging away from the line with `→` leaves `⌘Z` a chord at once, and
    /// with the asks panel closed, as its last ask's answer went, `⌘Z` is a chord too.
    @Test func noOtherChangeKeepsCommandZThePanels() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        #expect(Self.press(.right, run, pointer) == .asks)
        #expect(run.keySnapshot == .panel(hold: 1, undoes: false))

        let (alone, onIt) = try Self.asksOpen(Self.dataImport)
        let answering = Answering(.words("Map"), to: "k1", of: AsksBoard.dataImport, wanting: .yes)

        alone.heard(Self.held(answering), Self.at(alone, onIt, setting))
        alone.heard(.went(answering), Self.at(alone, onIt, setting))
        #expect(alone.asksShown == nil && alone.keySnapshot == .panel(hold: 1, undoes: false))
    }

    // MARK: Keycaps

    /// A menu holding the card, Snooze ▾'s or a row's, has the keys: the keycaps go while it shows, beside its own
    /// digits, and come back as it closes.
    @Test func whileAMenuHoldsTheCardNoKeycaps() throws {
        let (run, pointer) = try Self.asksOpen()

        run.menuOpened(at: try Self.part(.snooze, run))
        #expect(run.asksShown?.keycaps == false)
        run.menuClosed()
        #expect(run.asksShown?.keycaps == true)
        #expect(run.holdsKeys && Self.press(.digit(1), run, pointer) != nil)
    }

    /// The answers show their keycaps while the panel holds the keys and no answer is held: gone as one is held, back
    /// as it is undone, gone as a key the panel doesn't take lets go, back as the pointer moves on the panel.
    @Test func keycapsShowWhileThePanelHoldsTheKeysAndNoAnswerIsHeld() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        #expect(run.asksShown?.keycaps == true)
        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        #expect(run.asksShown?.keycaps == false)
        run.heard(.undone(Self.threaded), Self.at(run, pointer, setting))
        #expect(run.asksShown?.keycaps == true)

        run.letGoOfKeys(in: 1, Self.at(run, pointer, setting))
        #expect(run.asksShown?.keycaps == false)
        run.step(Self.at(run, try Self.part(.answer(1), run), setting))
        #expect(run.asksShown?.keycaps == true)
    }

    /// Without the leave, or under secure input, the panel holds nothing: no keycaps, the asks panel opened by a click.
    @Test func whileTheMacLetsThePanelTakeNoKeysNoKeycaps() throws {
        let setting = Self.setting(takesKeys: false), run = Self.opened(setting, board: AsksBoard.board())
        let index = try #require(run.list.index(of: Self.helpDesk)), panel = try #require(run.frame.panel)
        let row = run.list.content.laidFrame(index), box = RowArrow.box(in: row.size)
        let arrow = CGPoint(x: panel.frame.minX + row.minX + box.midX, y: panel.frame.minY + row.minY + box.midY)

        run.step(Self.at(run, arrow, setting))
        #expect(run.press(Self.at(run, arrow, setting)) == .asks)
        #expect(run.asksShown != nil && run.asksShown?.keycaps == false)
    }

    /// An answer held for another session's ask leaves the digits nothing to answer: no keycaps there either.
    @Test func whileAnotherSessionsAnswerIsHeldNoKeycaps() throws {
        let (run, pointer) = try Self.asksOpen(), setting = Self.setting()

        run.heard(Self.held(Self.threaded), Self.at(run, pointer, setting))
        Self.press(.escape, run, pointer)

        let other = try Self.words(Self.dataImport, run, setting)

        run.step(Self.at(run, other, setting))
        #expect(Self.press(.enter, run, other) == .asks)
        #expect(run.asksShown?.row == Self.dataImport && run.asksShown?.keycaps == false)
        #expect(Self.press(.digit(1), run, other) == nil)
    }

    /// The ask sliding in beside shows its keycaps as the ask shown does, so none come or go as it slides.
    @Test func theAskBesideShowsItsKeycapsToo() throws {
        let (run, pointer) = try Self.asksOpen()

        Self.press(.right, run, pointer)
        #expect(run.asksShown?.keycaps == true && run.asksShown?.shownBeside?.keycaps == true)
    }
}
