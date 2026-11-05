import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import Testing

/// The notch as the controller runs it, with no screen: a press goes to the row under it and reads the notch as it is
/// then, the clock never goes back and the light's own refresh never moves it, the rows keep their places while the
/// panel is out, a new row is washed only then, and a click's answer is heard only for the latest click.
struct NotchRunTests {
    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false
    )
    private static let frameMS = 1000.0 / 60
    private static let onTheNotch = CGPoint(x: 3, y: 491)
    private static let width = 1512.0, height = 982.0

    private static func at(_ time: Double, _ pointer: CGPoint? = nil) -> NotchRun.Moment {
        NotchRun.Moment(time: time, pointer: pointer, setting: setting)
    }

    /// A board of asks, each a window holds, in this order, the ones named new on it.
    private static func board(_ ids: [String], new: [String] = []) -> PanelBoard {
        let rows = ids.map { id in
            row("ask:\(id)", "ask", session: "sr-\(id)", lead: "Ask \(id)", second: "SitRep · \(id)", since: 1_792_445_000_000)
        }
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: ids.count, sessions: ids.count, new: new.map { "ask:\($0)" }, rows: rows)), at: Date())
        return PanelBoard(last)
    }

    /// Frames a refresh apart, with the pointer here, for this long or until done.
    private static func frames(_ run: NotchRun, for ms: Double, _ pointer: CGPoint?, until done: () -> Bool = { false }) {
        let end = run.time + ms

        while run.time + frameMS <= end + 1e-9, !done() {
            run.step(at(run.time + frameMS, pointer))
        }
    }

    /// A run over a board of these, its panel opened by the pointer held on the notch.
    private static func opened(_ ids: [String]) -> NotchRun {
        let run = NotchRun(at: 1000, in: setting)

        _ = run.show(board(ids), at(run.time))
        frames(run, for: 3000, onTheNotch) { run.phase == .open }
        return run
    }

    /// Where a row of the list as drawn shows on the stage: near its top, in its middle.
    private static func point(of key: String, in run: NotchRun) throws -> CGPoint {
        let panel = try #require(run.frame.panel)
        let content = run.list.content
        let index = try #require(content.entries.firstIndex { $0.item.key == key })
        let row = content.itemFrame(index)

        return CGPoint(x: panel.frame.minX + row.midX, y: panel.frame.minY + row.minY + 10 - run.scroll)
    }

    /// The rows' keys, in the list's order.
    private static func keys(_ run: NotchRun) -> [String] {
        run.list.content.entries.filter { $0.item.session != nil }.map(\.item.key)
    }

    @Test func aPressGoesToTheRowUnderItThoughARowCameInAboveItSinceTheModelsLastFrame() throws {
        let run = Self.opened(["a", "b"])
        #expect(run.phase == .open)

        _ = run.show(Self.board(["c", "a", "b"], new: ["c"]), Self.at(run.time))
        #expect(Self.keys(run) == ["needs:sr-c", "needs:sr-a", "needs:sr-b"])

        let onA = try Self.point(of: "needs:sr-a", in: run)
        let pressed = run.press(Self.at(run.time, onA))

        guard case let .jump(session, to: target, click: click) = pressed else {
            Issue.record("pressed \(String(describing: pressed))")
            return
        }
        #expect(session.id == "sr-a" && target == "sr-a" && click == 1)
        run.step(Self.at(run.time + Self.frameMS, onA))
        #expect(run.frame.panel?.pressed == "needs:sr-a")
    }

    /// A run over Kit's away ask and SitRep's held one, its panel opened.
    private static func openedWithAway() -> NotchRun {
        let rows = [
            row("ask:a", "ask", session: "sr-a", lead: "Ask a", second: "SitRep · a", since: 1_792_445_000_000),
            row("ask:k", "ask", away: true, session: "sr-k", lead: "Ask k", second: "Kit · k", since: 1_792_445_000_000),
        ]
        var last = LastBoard()
        let run = NotchRun(at: 1000, in: setting)

        _ = last.hear(.line(line(needYou: 2, sessions: 2, new: [], rows: rows)), at: Date())
        _ = run.show(PanelBoard(last), at(run.time))
        frames(run, for: 3000, onTheNotch) { run.phase == .open }
        return run
    }

    /// The middle of a row's time on the stage, 22 in from the row's right.
    private static func time(of key: String, in run: NotchRun) throws -> CGPoint {
        let panel = try #require(run.frame.panel)
        let content = run.list.content
        let index = try #require(content.entries.firstIndex { $0.item.key == key })
        let row = content.itemFrame(index), box = content.entries[index].item.box(width: row.width)

        return CGPoint(
            x: panel.frame.minX + row.minX + box.maxX - 22, y: panel.frame.minY + row.minY + box.midY - run.scroll
        )
    }

    /// A press on a row's time is a press on the row, which holds no button there: it jumps, pressing the row in, and
    /// on an away row does nothing.
    @Test func aPressOnARowsTimeIsAPressOnTheRow() throws {
        let run = Self.openedWithAway()

        #expect(run.press(Self.at(run.time, try Self.time(of: "needs:sr-k", in: run))) == nil)
        guard case let .jump(session, to: target, click: click)? = run.press(
            Self.at(run.time, try Self.time(of: "needs:sr-a", in: run))
        )
        else {
            Issue.record("a press on the row's time did not jump")
            return
        }
        #expect(session.id == "sr-a" && target == "sr-a" && click == 1)
        run.step(Self.at(run.time + Self.frameMS))
        #expect(run.frame.panel?.pressed == "needs:sr-a")
    }

    /// A right-click finds the row under it, away or not; its menu's jump presses that row in as a click does, and on
    /// an away row, which no window holds, jumps nowhere.
    @Test func theMenusJumpIsAClickOnTheRow() throws {
        let run = Self.openedWithAway()

        #expect(run.row(at: try Self.point(of: "needs:sr-k", in: run), in: Self.setting)?.session?.id == "sr-k")
        #expect(run.row(at: try Self.point(of: "needs:sr-a", in: run), in: Self.setting)?.key == "needs:sr-a")
        #expect(run.jump(to: "needs:sr-k", Self.at(run.time)) == nil)

        guard case let .jump(session, to: target, click: click)? = run.jump(
            to: "needs:sr-a", Self.at(run.time)
        )
        else {
            Issue.record("the menu's jump did not jump")
            return
        }
        #expect(session.id == "sr-a" && target == "sr-a" && click == 1)
        run.step(Self.at(run.time + Self.frameMS))
        #expect(run.frame.panel?.pressed == "needs:sr-a")
    }

    /// A row's menu open holds the card open however long the pointer is away on it, its row still there for the
    /// menu's jump; once the menu closes, the pointer away lets it close.
    @Test func aRowsMenuHoldsTheCardOpenUntilItCloses() throws {
        let run = Self.openedWithAway()
        let away = CGPoint(x: 900, y: 200)

        run.menuOpened(at: try Self.point(of: "needs:sr-a", in: run))
        Self.frames(run, for: 10_000, away)
        #expect(run.phase == .open)
        guard case .jump? = run.jump(to: "needs:sr-a", Self.at(run.time, away)) else {
            Issue.record("the menu's jump found no row")
            return
        }

        let held = Self.openedWithAway()

        held.menuOpened(at: try Self.point(of: "needs:sr-a", in: held))
        Self.frames(held, for: 1000, away)
        held.menuClosed()
        Self.frames(held, for: 5000, away) { held.phase == .closed }
        #expect(held.phase == .closed)
    }

    @Test func onlyTheLatestClicksAnswerIsHeard() throws {
        let run = Self.opened(["a", "b"])

        _ = run.press(Self.at(run.time, try Self.point(of: "needs:sr-a", in: run)))

        #expect(run.isLatest(1))
        #expect(!run.isLatest(0) && !run.isLatest(2))
    }

    /// Carried past the screen's middle and let go: the notch crosses to the other edge, home 420ms on.
    private static func droppedAcross() -> NotchRun {
        let run = NotchRun(at: 1000, in: setting)
        let notch = CGPoint(x: 2, y: 491)

        run.step(at(run.time + frameMS))
        #expect(run.press(at(run.time, notch)) == .carry)
        _ = run.moved(width: width, at(run.time + frameMS, CGPoint(x: 1000, y: 491)))
        let dropped = run.release(EdgeSettings(), height: height, at(run.time + frameMS))
        #expect(dropped?.isAcross == true)
        return run
    }

    @Test func aPressOffTheRowsCarriesTheNotchButNotWhileItCrossesToTheOtherEdge() {
        let run = Self.droppedAcross()

        Self.frames(run, for: 100, nil)

        #expect(run.press(Self.at(run.time, CGPoint(x: 2, y: 491))) == nil)
    }

    @Test func aPressTakesTheNotchHomeOnTheOtherEdgeThoughNoFrameHasSeenItThereYet() {
        let run = Self.droppedAcross()

        Self.frames(run, for: 400, nil)

        #expect(run.press(Self.at(run.time + 40, CGPoint(x: 2, y: 491))) == .carry)
    }

    /// Pressed on the notch and dragged 200 up the edge, the notch carried there.
    private static func carried() -> NotchRun {
        let run = NotchRun(at: 1000, in: setting)

        run.step(at(run.time + frameMS))
        _ = run.press(at(run.time, CGPoint(x: 2, y: 491)))
        _ = run.moved(width: width, at(run.time + frameMS, CGPoint(x: 2, y: 291)))
        return run
    }

    @Test func theNotchFollowsTheDragOnItsSpringLiftedOverItsLift() {
        let run = Self.carried()

        #expect(run.drag?.isCarrying == true && run.drag?.isAcross == false)
        Self.frames(run, for: 140, CGPoint(x: 2, y: 291))
        #expect(run.frame.lift > 0.9)
        #expect(run.frame.light.centre.y < 300)
        Self.frames(run, for: 500, CGPoint(x: 2, y: 291))
        #expect(abs(run.frame.light.centre.y - 291) < 0.5)

        let dropped = run.release(EdgeSettings(), height: Self.height, Self.at(run.time + Self.frameMS))

        #expect(dropped?.isAcross == false)
        #expect(dropped?.move.along.map { abs($0 - 291 / Self.height) < 1e-9 } == true)
        #expect(run.drag == nil)
    }

    @Test func hiddenMidDragTheNotchEndsWhereItBegan() {
        let run = Self.carried()

        Self.frames(run, for: 300, CGPoint(x: 2, y: 291))
        let ended = run.endDrag(NotchRun.Moment(time: run.time + 10, pointer: nil, isShown: false, setting: Self.setting))
        Self.frames(run, for: 1000, nil)

        #expect(ended && run.drag == nil)
        #expect(abs(run.frame.light.centre.y - 491) < 0.5)
        #expect(run.frame.lift < 1e-3)
    }

    /// Each input the run takes, made at a moment.
    enum Taken: CaseIterable {
        case board, press, moved, release, endDrag, clickElsewhere, jumpAnswered, scroll

        func take(_ run: NotchRun, _ moment: NotchRun.Moment) {
            switch self {
            case .board: _ = run.show(PanelBoard(), moment)
            case .press: _ = run.press(moment)
            case .moved: _ = run.moved(width: NotchRunTests.width, moment)
            case .release: _ = run.release(EdgeSettings(), height: NotchRunTests.height, moment)
            case .endDrag: _ = run.endDrag(moment)
            case .clickElsewhere: run.clickElsewhere(moment)
            case .jumpAnswered: run.jumpAnswered(moment)
            case .scroll: run.scroll(by: 10, moment)
            }
        }
    }

    @Test(arguments: Taken.allCases)
    func eachInputBringsTheNotchUpToItsMomentFirst(_ taken: Taken) {
        let run = Self.carried(), there = CGPoint(x: 2, y: 400)

        taken.take(run, Self.at(run.time + 30, there))

        #expect(run.time == 1000 + 2 * Self.frameMS + 30)
        #expect(run.seen == there)
    }

    /// A drag along the pointer's path and let go across, a frame a refresh, its moves as given each refresh: the light's
    /// place at every frame, and the frame it swaps edges at.
    private static func dragAcross(movesPerRefresh: Int) -> (places: [Double], swappedAt: Int?) {
        let run = NotchRun(at: 1000, in: setting)
        var places: [Double] = [], swappedAt: Int?

        run.step(at(run.time + frameMS))
        _ = run.press(at(run.time, CGPoint(x: 2, y: 491)))
        for k in 1 ... 60 {
            let read = 1000 + Double(k) * frameMS
            for move in 1 ... movesPerRefresh {
                let t = read - frameMS + frameMS * Double(move) / Double(movesPerRefresh)
                _ = run.moved(width: width, at(t, CGPoint(x: 2 + (t - 1000) * 1.2, y: 491 - (t - 1000) * 0.3)))
            }
            if k == 40 {
                _ = run.release(EdgeSettings(), height: height, at(read))
            }
            run.step(at(read + frameMS, nil))
            places.append(run.frame.light.centre.y)
            if swappedAt == nil, run.frame.swapsEdge {
                swappedAt = k
            }
        }
        return (places, swappedAt)
    }

    @Test func movesBetweenTheFramesLeaveTheDragAndTheCrossingAsWithAMoveAFrame() {
        let alone = Self.dragAcross(movesPerRefresh: 1), between = Self.dragAcross(movesPerRefresh: 8)

        #expect(alone.swappedAt != nil)
        #expect(between.swappedAt == alone.swappedAt)
        #expect(zip(alone.places, between.places).allSatisfy { abs($0 - $1) < 1e-9 })
    }

    /// The pointer read along the edge at a steady speed, a frame a refresh, stamped a refresh ahead as the display
    /// link's are, with inputs between them stamped as they come: the speed read on each input's frame.
    private static func speeds(inputsPerRefresh: Int, from start: Int = 0) -> [Double] {
        let run = NotchRun(at: 1000, in: setting), speed = 0.6
        let point = { (t: Double) in CGPoint(x: 600, y: 200 + (t - 1000) * speed) }
        var speeds: [Double] = []

        for k in 1 ... 20 {
            let read = 1000 + Double(k) * frameMS
            run.step(NotchRun.Moment(time: read + frameMS, pointer: point(read), pointerAt: read, setting: setting))
            // the inputs come at a phase of the refresh that varies, as events do
            let phase = 0.15 + 0.7 * Double(k * 7 % 10) / 10
            for i in 1 ... inputsPerRefresh {
                let t = read + frameMS * phase * Double(i) / Double(inputsPerRefresh)
                run.scroll(by: 0, NotchRun.Moment(time: t, pointer: point(t), pointerAt: t, setting: setting))
                if k > start, let meniscus = run.notch as? Meniscus {
                    speeds.append(meniscus.trailVelocity().y)
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
        let run = NotchRun(at: 1000, in: Self.setting)

        run.step(Self.at(2000))
        run.step(Self.at(1990))
        #expect(run.time == 2000)

        run.catchUp(Self.at(1500))
        _ = run.show(Self.board(["a"]), Self.at(1200))
        run.clickElsewhere(Self.at(1100))
        #expect(run.time == 2000)
    }

    @Test func theLightsOwnRefreshDrawsAheadButNeverMovesTheClock() {
        let run = NotchRun(at: 1000, in: Self.setting)

        run.step(Self.at(2000))

        #expect(run.lightTime(1990) == 2000)
        #expect(run.lightTime(2030) == 2030)
        #expect(run.time == 2000)
        run.step(Self.at(2016))
        #expect(run.time == 2016)
    }

    @Test func theLightNeverStepsBackThoughAFrameIsDrawnBehindItsOwnRefresh() {
        let run = NotchRun(at: 1000, in: Self.setting)

        run.step(Self.at(2000))
        #expect(run.lightTime(2033) == 2033)

        run.step(Self.at(2016))
        #expect(run.lightTime(run.time) == 2033)
        run.step(Self.at(2050))
        #expect(run.lightTime(run.time) == 2050)
    }

    @Test func whatAFrameShowedWaitsForTheDrawingOnce() {
        let run = Self.droppedAcross()

        _ = run.takeShown()
        Self.frames(run, for: 300, nil)

        let shown = run.takeShown()

        #expect(shown.swappedEdge)
        #expect(run.takeShown() == NotchRun.Shown())
    }

    /// Hidden after a drop across but before its swap, and shown once the swap is past: the frames run on meanwhile
    /// showed it, and the drawing hears it.
    @Test func aSwapRunOnWhileHiddenStillReachesTheDrawing() {
        let run = Self.droppedAcross()

        _ = run.takeShown()
        run.catchUp(NotchRun.Moment(time: run.time + 600, pointer: nil, isShown: false, setting: Self.setting))
        run.step(Self.at(run.time + Self.frameMS))

        #expect(run.takeShown().swappedEdge)
    }

    /// The panel going in with no click waiting on it, as the pointer leaves or a click elsewhere closes it, is no
    /// jump's drain: the caption waits on nothing.
    @Test func aPanelGoingInWithNoClickIsNoJumpsDrain() {
        let run = Self.opened(["a", "b"])

        _ = run.takeShown()
        run.clickElsewhere(Self.at(run.time + Self.frameMS))
        Self.frames(run, for: 1000, CGPoint(x: 900, y: 491))

        #expect(run.phase == .closed)
        #expect(run.takeShown().jumpDrained == nil)
    }

    /// A row's click drains the panel once its jump answers: the drawing hears it once, at the frame it began, and the
    /// frames after, with the panel in, latch nothing more.
    @Test func aClicksDrainIsLatchedOnceAsThePanelGoesIn() throws {
        let run = Self.opened(["a", "b"])

        _ = run.press(Self.at(run.time, try Self.point(of: "needs:sr-a", in: run)))
        _ = run.takeShown()
        run.jumpAnswered(Self.at(run.time + Self.frameMS))
        run.step(Self.at(run.time + Self.frameMS))
        let drained = run.time

        #expect(run.phase == .closing)
        #expect(run.takeShown().jumpDrained == drained)
        Self.frames(run, for: 1000, CGPoint(x: 900, y: 491))
        #expect(run.phase == .closed)
        #expect(run.takeShown().jumpDrained == nil)
    }

    @Test func hiddenAnInputRunsTheNotchsTimeOnFirst() {
        let run = Self.opened(["a"])

        run.clickElsewhere(NotchRun.Moment(time: run.time + 10_000, pointer: nil, isShown: false, setting: Self.setting))

        #expect(run.time > 10_000)
        #expect(run.phase == .closing || run.phase == .closed)
    }

    @Test func whileThePanelIsOutTheRowsKeepTheirPlacesAndTakeCoresOrderOnceItIsIn() {
        let run = Self.opened(["a", "b"])

        _ = run.show(Self.board(["b", "a"]), Self.at(run.time))
        #expect(Self.keys(run) == ["needs:sr-a", "needs:sr-b"])

        run.clickElsewhere(Self.at(run.time))
        Self.frames(run, for: 5000, CGPoint(x: 900, y: 491)) { run.phase == .closed }

        #expect(run.phase == .closed)
        #expect(Self.keys(run) == ["needs:sr-b", "needs:sr-a"])
    }

    @Test func aNewRowIsWashedOnlyWhileThePanelIsOut() {
        let closed = NotchRun(at: 1000, in: Self.setting)
        let open = Self.opened(["a"])

        #expect(closed.show(Self.board(["c", "a"], new: ["c"]), Self.at(1000)).isEmpty)
        #expect(open.show(Self.board(["c", "a"], new: ["c"]), Self.at(open.time)) == ["needs:sr-c"])
    }

    @Test func theTimesNextChangeIsTheSoonestOfTheShownRows() {
        let run = NotchRun(at: 1000, in: Self.setting)

        #expect(run.nextAgeChange(after: 1_792_445_100_000) == nil)
        _ = run.show(Self.board(["a", "b"]), Self.at(1000))
        #expect(run.nextAgeChange(after: 1_792_445_100_000).map { $0 > 1_792_445_100_000 } == true)
    }
}
