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
        StripRun(at: 1000, in: setting, settings) { _ in
            StripMeasure(row: { _ in 200 }, rows: { _ in 200 }, idle: { 200 })
        }
    }

    /// A board of windows working, longest running first, each a window holds.
    private static func working(_ ids: [String]) -> PanelBoard {
        let rows = ids.enumerated().map { i, id in
            row("work:\(id)", "working", session: "sr-\(id)", lead: "Work \(id)", second: "P · \(id)", since: 1_792_445_000_000 + i)
        }
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: 0, sessions: ids.count, new: [], rows: rows)), at: Date())
        return PanelBoard(last)
    }

    /// Frames a refresh apart, with the pointer here, for this long or until a frame is done.
    private static func frames(_ run: StripRun, for ms: Double, _ pointer: CGPoint?, until done: () -> Bool = { false }) {
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
        let run = run(settings)

        run.show(working(ids), at(run.time))
        frames(run, for: 3000, nil) { !run.frame.isMoving }
        return run
    }

    /// A mark's centre on the strip, 18 in from the edge.
    private static func on(_ id: String, in run: StripRun) -> CGPoint {
        CGPoint(x: 18, y: run.strip.yOf(.session("work:\(id)")))
    }

    // MARK: A click

    /// Eight windows working at Max's fewest, the grey count's tab open and still with the pointer on it.
    private static func countOpen() -> StripRun {
        let run = shown(["w1", "w2", "w3", "w4", "w5", "w6", "w7", "w8"], settings(.grows, max: StripMax(share: 0)))
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

    /// The spin is over when the drawing hears the strip drained, never before it began: the caption shows after it.
    @Test func aClickLatchesNoDrainUntilItsSpinIsOver() {
        let run = Self.shown(["a", "b"]), mark = Self.on("a", in: run)

        run.press(Self.at(run.time, mark))
        let clicked = run.time
        _ = run.release(EdgeSettings(), mayJump: true, Self.at(run.time, mark))

        #expect(run.takeShown().drained == nil)
        Self.frames(run, for: 600, mark)
        #expect(run.takeShown().drained.map { $0 > clicked + 400 } == true)
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
        #expect(!drop.isAcross && abs(drop.settings.along - centre / Self.stage.height) < 1e-9)
        #expect(!run.isDragging)
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

        #expect(shown.swappedEdge)
        #expect(shown.drained != nil)
        #expect(run.takeShown() == StripRun.Shown())
    }

    // MARK: The board

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
