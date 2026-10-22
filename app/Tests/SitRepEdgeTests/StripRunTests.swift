import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import Testing

/// The strip as the controller runs it, with no screen: every input brings it up to its moment first, so a click
/// lands on the strip as drawn and a drag follows; a drag hidden ends where it began; inputs between the frames leave
/// it as the frames alone would; the pointer's speed is its own; the clock never goes back; and what a frame showed
/// waits for the drawing once.
struct StripRunTests {
    private static let stage = StripStage(width: 1512, height: 982, menu: 37)
    private static let setting = StripRun.Setting(stage: stage, reducesMotion: false)
    private static let frameMS = 1000.0 / 60

    private static func at(_ time: Double, _ pointer: CGPoint? = nil, isShown: Bool = true) -> StripRun.Moment {
        StripRun.Moment(time: time, pointer: pointer, isShown: isShown, setting: setting)
    }

    private static func settings(_ length: StripLength, max: StripMax = .full) -> EdgeSettings {
        var settings = EdgeSettings()

        settings.length = length
        settings.maxLength = max
        return settings
    }

    private static func run(_ settings: EdgeSettings = Self.settings(.grows)) -> StripRun {
        StripRun(at: 1000, in: setting, settings, measure: measure)
    }

    /// The words 230 wide, 330 where the board would say something longer of them: stale, "as of 12:04"; or the notch
    /// at rest's title anything but nothing running. A count's rows measured so too, though they never say it.
    private static func measure(_ note: @escaping () -> StripNote) -> StripMeasure {
        StripMeasure(
            row: { _ in note().asOf == nil ? 230 : 330 }, rows: { _ in note().asOf == nil ? 230 : 330 },
            idle: { note().idle == StripFrame.Words.Content.idleTitle ? 230 : 330 }
        )
    }

    /// A board of windows working, longest running first, each a window holds; gone stale, with `watch` stopped.
    private static func working(_ ids: [String], stale: Bool = false) -> PanelBoard {
        let rows = ids.enumerated().map { i, id in
            row(
                "work:\(id)", "working", session: "sr-\(id)", lead: "Work \(id)", second: "P · \(id)",
                since: 1_792_445_000_000 + i
            )
        }
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: 0, sessions: ids.count, new: [], rows: rows)), at: Date())
        if stale {
            _ = last.hear(.exited(.status(1), stderr: ""), at: Date())
        }
        return PanelBoard(last)
    }

    /// Frames a refresh apart, with the pointer here, for this long or until a frame is done.
    private static func frames(
        _ run: StripRun, for ms: Double, _ pointer: CGPoint?, until done: () -> Bool = { false }
    ) {
        let end = run.time + ms

        while run.time + frameMS <= end + 1e-9 {
            run.step(at(run.time + frameMS, pointer))
            if done() {
                return
            }
        }
    }

    /// A run at Grows over these windows working, come to rest.
    private static func shown(_ ids: [String], _ settings: EdgeSettings = Self.settings(.grows)) -> StripRun {
        shown(working(ids), settings)
    }

    /// A run over this board, come to rest.
    private static func shown(_ board: PanelBoard, _ settings: EdgeSettings) -> StripRun {
        let run = run(settings)

        run.show(board, at(run.time))
        frames(run, for: 3000, nil) { !run.frame.isMoving }
        return run
    }

    /// A mark's centre on the strip, 18 in from the edge.
    private static func on(_ id: String, in run: StripRun) -> CGPoint {
        CGPoint(x: 18, y: run.strip.yOf(.session("work:\(id)")))
    }

    // MARK: A click

    /// Eight windows working, unless given another board, at Max's fewest, the grey count's tab open and still with
    /// the pointer on it: w5 to w8 in it.
    private static func countOpen(
        _ board: PanelBoard = working(["w1", "w2", "w3", "w4", "w5", "w6", "w7", "w8"])
    ) -> StripRun {
        let run = shown(board, settings(.grows, max: StripMax(share: 0)))
        let count = CGPoint(x: 18, y: run.strip.yOf(.more))

        frames(run, for: 2000, count) { run.strip.liveTab()?.phase == .open }
        frames(run, for: 2000, count) { !run.frame.isMoving }
        return run
    }

    /// Where a row of the open count's tab shows, by its index, as last drawn.
    private static func countRow(_ index: Int, in run: StripRun) throws -> CGPoint {
        let tab = try #require(run.frame.tabs.first { $0.key == .more }), words = try #require(tab.words.last)
        let pitch = StripTuning.rowHeight + StripTuning.rowGap
        let y = tab.box.minY + words.frame.minY + StripTuning.rowsPad + Double(index) * pitch
            + StripTuning.rowHeight / 2 - words.scroll

        return CGPoint(x: tab.box.midX, y: y)
    }

    /// The count's first row swapped for a new last one since the model's last frame: a click on its first row as
    /// drawn lands on the row the strip now has there.
    @Test func aClickGoesToTheRowUnderItThoughTheBoardChangedTheCountSinceTheModelsLastFrame() throws {
        let run = Self.countOpen()
        let rows = run.strip.layout.rest
        #expect(rows.first == "work:w5")

        run.show(Self.working(["w1", "w2", "w3", "w4", "w6", "w7", "w8", "w9"]), Self.at(run.time))
        let first = try Self.countRow(0, in: run)
        run.press(Self.at(run.time, first))
        let released = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, first))

        guard case let .jump(session, to: target, click: click) = released else {
            Issue.record("released \(String(describing: released))")
            return
        }
        #expect(session.id == "work:w6" && target == "sr-w6" && click == 1)
    }

    @Test func noClickJumpsWhileAJumpRunsAndNoneIsCounted() {
        let run = Self.shown(["a", "b"]), mark = Self.on("a", in: run)

        run.press(Self.at(run.time, mark))

        #expect(run.release(EdgeSettings(), mayJump: false, Self.at(run.time, mark)) == nil)
        #expect(!run.isLatest(1))
    }

    @Test func onlyTheLatestClicksAnswerIsHeard() {
        let run = Self.shown(["a", "b"]), mark = Self.on("a", in: run)

        run.press(Self.at(run.time, mark))
        _ = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, mark))

        #expect(run.isLatest(1))
        #expect(!run.isLatest(0) && !run.isLatest(2))
    }

    /// The spin is over when the drawing hears the strip drained, never before it began, so the caption shows after
    /// it; and it hears it once, the frames after latching nothing more.
    @Test func aClicksDrainIsLatchedOnceItsSpinIsOver() {
        let run = Self.shown(["a", "b"]), mark = Self.on("a", in: run)

        run.press(Self.at(run.time, mark))
        let clicked = run.time
        _ = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, mark))

        #expect(run.takeShown().jumpDrained == nil)
        Self.frames(run, for: 600, mark)
        #expect(run.takeShown().jumpDrained.map { $0 > clicked + 400 } == true)
        Self.frames(run, for: 600, mark)
        #expect(run.takeShown().jumpDrained == nil)
    }

    /// A spin over and a new click before the drawing has heard it: that drain is the old click's, and the new one's
    /// caption waits for its own.
    @Test func aDrainBeforeAClickIsNotItsOwn() {
        let run = Self.shown(["a", "b"]), a = Self.on("a", in: run), b = Self.on("b", in: run)

        run.press(Self.at(run.time, a))
        _ = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, a))
        Self.frames(run, for: 600, a)
        run.press(Self.at(run.time, b))
        let released = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, b))

        guard case .jump(_, to: "sr-b", click: 2) = released else {
            Issue.record("released \(String(describing: released))")
            return
        }
        #expect(run.takeShown().jumpDrained == nil)
    }

    // MARK: A drag

    /// Pressed on a mark at Grows and dragged 100 up the edge.
    private static func carried() -> (run: StripRun, top: Double) {
        let run = shown(["a", "b"]), mark = on("a", in: run), top = run.strip.layout.top

        run.press(at(run.time, mark))
        run.moved(at(run.time + frameMS, CGPoint(x: mark.x, y: mark.y - 100)))
        return (run, top)
    }

    @Test func theStripFollowsTheDragAndIsLeftWhereItWasLetGo() {
        let (run, top) = Self.carried()
        let there = CGPoint(x: 18, y: Self.on("a", in: run).y)

        #expect(run.isDragging && !run.isAcross)
        Self.frames(run, for: 500, nil)
        #expect(abs(run.strip.layout.top - (top - 100)) < 0.5)

        let released = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, there))

        guard case let .dropped(drop) = released else {
            Issue.record("released \(String(describing: released))")
            return
        }
        let centre = run.strip.layout.top + run.strip.layout.length / 2
        #expect(!drop.isAcross && drop.move.along.map { abs($0 - centre / Self.stage.height) < 1e-9 } == true)
        #expect(!run.isDragging)
    }

    /// Let go across, the drop holds only where the strip went, saved onto the settings as they stand at the swap:
    /// Show changed to the notch meanwhile stays the notch.
    @Test func aDropAcrossCarriesOnlyWhereItWentOntoTheSettingsAtTheSwap() {
        let (run, _) = Self.carried()
        var settings = Self.settings(.grows)
        settings.show = .strip
        let across = CGPoint(x: 1000, y: 300)

        run.moved(Self.at(run.time + Self.frameMS, across))
        let released = run.release(settings, mayJump: true, Self.at(run.time, across))

        guard case let .dropped(drop) = released else {
            Issue.record("released \(String(describing: released))")
            return
        }
        settings.show = .notch
        settings.material = .glass
        let saved = drop.move.applied(to: settings)
        #expect(drop.isAcross && saved.edge == .right)
        #expect(saved.show == .notch && saved.material == .glass)
    }

    @Test func hiddenMidDragTheStripEndsWhereItBegan() {
        let (run, top) = Self.carried()

        Self.frames(run, for: 300, nil)
        let ended = run.endDrag(Self.at(run.time + 10, isShown: false))

        #expect(ended && !run.isDragging)
        #expect(abs(run.strip.layout.top - top) < 1e-9)
        #expect(run.release(EdgeSettings(), mayJump: true, Self.at(run.time)) == nil)
    }

    /// A drag along the pointer's path and let go across, a frame a refresh, its moves as given each refresh: the
    /// strip's top end at every frame, and the frame it swaps edges at.
    private static func dragAcross(movesPerRefresh: Int) -> (tops: [Double], swappedAt: Int?) {
        let run = shown(["a", "b"]), start = run.time, mark = on("a", in: run)
        var tops: [Double] = [], swappedAt: Int?

        run.step(at(start + frameMS, mark))
        run.press(at(run.time, mark))
        for k in 1 ... 60 {
            let read = start + Double(k) * frameMS
            for move in 1 ... movesPerRefresh {
                let t = read - frameMS + frameMS * Double(move) / Double(movesPerRefresh)
                run.moved(at(t, CGPoint(x: mark.x + (t - start) * 1.2, y: mark.y - (t - start) * 0.3)))
            }
            if k == 40 {
                _ = run.release(EdgeSettings(), mayJump: true, at(read))
            }
            run.step(at(read + frameMS, nil))
            tops.append(run.strip.yt.x)
            if swappedAt == nil, run.frame.swapsEdge {
                swappedAt = k
            }
        }
        return (tops, swappedAt)
    }

    @Test func movesBetweenTheFramesLeaveTheDragAndTheCrossingAsWithAMoveAFrame() {
        let alone = Self.dragAcross(movesPerRefresh: 1), between = Self.dragAcross(movesPerRefresh: 8)

        #expect(alone.swappedAt != nil)
        #expect(between.swappedAt == alone.swappedAt)
        #expect(zip(alone.tops, between.tops).allSatisfy { abs($0 - $1) < 1e-9 })
    }

    // MARK: Between frames

    /// Each input the run takes, made at a moment.
    enum Taken: CaseIterable {
        case board, place, press, moved, release, endDrag, clickElsewhere, jumpAnswered, scroll

        func take(_ run: StripRun, _ moment: StripRun.Moment) {
            switch self {
            case .board: run.show(PanelBoard(), moment)
            case .place: run.place(EdgeSettings(), moment)
            case .press: run.press(moment)
            case .moved: run.moved(moment)
            case .release: _ = run.release(EdgeSettings(), mayJump: true, moment)
            case .endDrag: _ = run.endDrag(moment)
            case .clickElsewhere: run.clickElsewhere(moment)
            case .jumpAnswered: run.jumpAnswered(moment)
            case .scroll: run.scroll(by: 10, moment)
            }
        }
    }

    @Test(arguments: Taken.allCases)
    func eachInputBringsTheStripUpToItsMomentFirst(_ taken: Taken) {
        let run = Self.run(), there = CGPoint(x: 600, y: 400)

        run.step(Self.at(run.time + Self.frameMS))
        taken.take(run, Self.at(run.time + 30, there))

        #expect(run.time == 1000 + Self.frameMS + 30)
        #expect(run.frame.pointer == there)
    }

    @Test func hiddenAnInputRunsTheStripsTimeOnFirst() {
        let run = Self.shown(["a", "b"]), mark = Self.on("a", in: run)
        Self.frames(run, for: 2000, mark) { run.strip.liveTab()?.phase == .open }
        #expect(run.strip.liveTab() != nil)

        run.clickElsewhere(Self.at(run.time + 10_000, isShown: false))

        #expect(run.time > 11_000)
        #expect(run.strip.tabs.isEmpty)
    }

    /// The pointer read along the edge at a steady speed, a frame a refresh, stamped a refresh ahead as the display
    /// link's are, with inputs between them stamped as they come: the speed read on each input's frame.
    private static func speeds(inputsPerRefresh: Int, from start: Int = 0) -> [Double] {
        let run = Self.run(), speed = 0.6
        let point = { (t: Double) in CGPoint(x: 600, y: 200 + (t - 1000) * speed) }
        var speeds: [Double] = []

        for k in 1 ... 20 {
            let read = 1000 + Double(k) * frameMS
            run.step(StripRun.Moment(time: read + frameMS, pointer: point(read), pointerAt: read, setting: setting))
            // the inputs come at a phase of the refresh that varies, as events do
            let phase = 0.15 + 0.7 * Double(k * 7 % 10) / 10
            for i in 1 ... inputsPerRefresh {
                let t = read + frameMS * phase * Double(i) / Double(inputsPerRefresh)
                run.scroll(by: 0, StripRun.Moment(time: t, pointer: point(t), pointerAt: t, setting: setting))
                if k > start {
                    speeds.append(run.strip.trailVelocity().y)
                }
            }
        }
        return speeds
    }

    @Test func theSpeedReadOnAnInputsFrameIsThePointersOwn() {
        let speeds = Self.speeds(inputsPerRefresh: 1, from: 4)

        #expect(!speeds.isEmpty)
        #expect(speeds.allSatisfy { abs($0 - 0.6) < 1e-6 })
    }

    @Test func twoInputsInOneRefreshReadTheSpeedToo() {
        let speeds = Self.speeds(inputsPerRefresh: 2)

        #expect(speeds.dropFirst(2).allSatisfy { abs($0 - 0.6) < 1e-6 })
    }

    @Test func theClockNeverGoesBack() {
        let run = Self.run()

        run.step(Self.at(2000))
        run.step(Self.at(1990))
        #expect(run.time == 2000)

        run.catchUp(Self.at(1500))
        run.show(Self.working(["a"]), Self.at(1200))
        run.clickElsewhere(Self.at(1100))
        #expect(run.time == 2000)
    }

    /// Dropped across, the strip swaps edges between two drawings: the next one hears it, once.
    @Test func whatAFrameShowedWaitsForTheDrawingOnce() {
        let (run, _) = Self.carried()
        let across = CGPoint(x: 1000, y: 300)

        run.moved(Self.at(run.time + Self.frameMS, across))
        _ = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, across))
        _ = run.takeShown()
        Self.frames(run, for: 300, nil)

        let shown = run.takeShown()

        #expect(shown.swappedEdge && shown.jumpDrained == nil)
        #expect(run.takeShown() == StripRun.Shown())
    }

    /// Hidden after a drop across but before its swap, and shown once the swap is past: the frames run on meanwhile
    /// showed it, and the drawing hears it, so the move is saved and the strip shows on the other edge.
    @Test func aSwapRunOnWhileHiddenStillReachesTheDrawing() {
        let (run, _) = Self.carried()
        let across = CGPoint(x: 1000, y: 300)

        run.moved(Self.at(run.time + Self.frameMS, across))
        _ = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, across))
        _ = run.takeShown()
        run.catchUp(Self.at(run.time + 600, isShown: false))
        run.step(Self.at(run.time + Self.frameMS))

        #expect(run.takeShown().swappedEdge)
    }

    // MARK: The board

    /// The tab out at this point until it is open and still: its width.
    private static func opened(_ run: StripRun, at point: CGPoint) throws -> Double {
        frames(run, for: 2000, point) { run.strip.liveTab()?.phase == .open }
        frames(run, for: 2000, point) { !run.frame.isMoving }
        return try #require(run.strip.liveTab()).w.x
    }

    /// Gone stale with a session's tab out, its time reads "as of 12:04", which the tab eases out to fit.
    @Test func aTabOutTakesItsNewMeasureAsTheBoardGoesStale() throws {
        let run = Self.shown(["a", "b"]), mark = Self.on("a", in: run)
        let width = try Self.opened(run, at: mark)

        run.show(Self.working(["a", "b"], stale: true), Self.at(run.time))
        Self.frames(run, for: 2000, mark) { !run.frame.isMoving }

        #expect(abs(try #require(run.strip.liveTab()).w.x - (width + 100)) < 0.5)
    }

    /// With `watch` down before its first line, the notch at rest's tab says SitRep can't read the board, and eases out
    /// to fit it.
    @Test func theNotchAtRestsTabTakesItsNewMeasureAsItsTitleChanges() throws {
        let run = Self.run(), rest = CGPoint(x: 6, y: run.frame.column.midY)
        let width = try Self.opened(run, at: rest)
        #expect(run.strip.liveTab()?.key == .empty)

        run.show(PanelBoard(unrun: "SitRep can't read the board"), Self.at(run.time))
        Self.frames(run, for: 2000, rest) { !run.frame.isMoving }

        #expect(abs(try #require(run.strip.liveTab()).w.x - (width + 100)) < 0.5)
    }

    /// A count's rows say no time, so gone stale its tab keeps its words and its size.
    @Test func aCountsTabKeepsItsWordsAsTheBoardGoesStale() throws {
        let run = Self.countOpen()
        let tab = try #require(run.strip.liveTab()), words = tab.words.count, width = tab.w.x
        #expect(tab.key == .more)

        run.show(Self.working(["w1", "w2", "w3", "w4", "w5", "w6", "w7", "w8"], stale: true), Self.at(run.time))
        Self.frames(run, for: 1000, CGPoint(x: 18, y: run.strip.yOf(.more)))

        #expect(run.note.asOf != nil)
        #expect(tab.words.count == words && abs(tab.w.x - width) < 0.01)
    }

    /// One board changing a tab's row and going stale at once: the tab takes its new words once, not a layer in and
    /// straight out again.
    @Test func aTabTakesItsNewWordsOnceThoughItsRowAndTheBoardBothChanged() throws {
        let run = Self.shown(["a", "b"]), mark = Self.on("a", in: run)
        _ = try Self.opened(run, at: mark)
        let tab = try #require(run.strip.liveTab()), words = tab.words.count

        var last = LastBoard()
        let rows = [
            row("work:a", "working", session: "sr-a", lead: "Still at a", second: "P · a", since: 1_792_445_000_000),
            row("work:b", "working", session: "sr-b", lead: "Work b", second: "P · b", since: 1_792_445_000_001),
        ]
        _ = last.hear(.line(line(needYou: 0, sessions: 2, new: [], rows: rows)), at: Date())
        _ = last.hear(.exited(.status(1), stderr: ""), at: Date())
        run.show(PanelBoard(last), Self.at(run.time))

        #expect(tab.words.count == words + 1)
    }

    /// A count's rows say no time, so its tab ticks only for a wake's countdown among them, a minute before the wake
    /// and as it comes due, then never.
    @Test func aCountsTabTicksOnlyForAWakesCountdownAmongItsRows() {
        let until = 1_792_445_600_000
        let rows = (1 ... 8).map { i in
            i == 8
                ? row("turn:w8", "onItsWork", session: "sr-w8", lead: "Wakes", until: until, second: "P · w8", since: 1_792_445_000_008)
                : row("work:w\(i)", "working", session: "sr-w\(i)", lead: "Work w\(i)", second: "P · w\(i)", since: 1_792_445_000_000 + i)
        }
        var last = LastBoard()
        _ = last.hear(.line(line(needYou: 0, sessions: 8, new: [], rows: rows)), at: Date())
        let waking = Self.countOpen(PanelBoard(last)), working = Self.countOpen()
        let due = Double(until)

        #expect(waking.strip.layout.rest.last == "turn:w8")
        #expect(waking.nextAgeChange(after: due - 90_000) == due - 60_000)
        #expect(waking.nextAgeChange(after: due - 30_000) == due)
        #expect(waking.nextAgeChange(after: due) == nil)
        #expect(working.nextAgeChange(after: due - 90_000) == nil)
    }

    @Test func whileTheBoardIsStaleATabsTimeNeverTicks() {
        let run = Self.shown(["a", "b"]), mark = Self.on("a", in: run)
        Self.frames(run, for: 2000, mark) { run.strip.liveTab()?.phase == .open }
        let now = 1_792_445_100_000.0

        #expect(run.nextAgeChange(after: now).map { $0 > now } == true)

        var last = LastBoard()
        _ = last.hear(.line(watchLine), at: Date())
        _ = last.hear(.exited(.status(1), stderr: ""), at: Date())
        run.show(PanelBoard(last), Self.at(run.time))

        #expect(run.note.asOf != nil)
        #expect(run.nextAgeChange(after: now) == nil)
    }
}
