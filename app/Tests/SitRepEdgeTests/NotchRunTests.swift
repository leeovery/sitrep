import CoreGraphics
import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
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

    private static func keys(_ run: NotchRun) -> [String] {
        run.list.content.entries.map(\.item.key)
    }

    @Test func aPressGoesToTheRowUnderItThoughARowCameInAboveItSinceTheModelsLastFrame() throws {
        let run = Self.opened(["a", "b"])
        #expect(run.phase == .open)

        _ = run.show(Self.board(["c", "a", "b"], new: ["c"]), Self.at(run.time))
        #expect(Self.keys(run) == ["ask:c", "ask:a", "ask:b"])

        let onA = try Self.point(of: "ask:a", in: run)
        let pressed = run.press(Self.at(run.time, onA), mayJump: true)

        guard case let .jump(session, to: target, click: click) = pressed else {
            Issue.record("pressed \(String(describing: pressed))")
            return
        }
        #expect(session.id == "ask:a" && target == "sr-a" && click == 1)
        run.step(Self.at(run.time + Self.frameMS, onA))
        #expect(run.frame.panel?.pressed == "ask:a")
    }

    @Test func noPressJumpsWhileAJumpRunsAndNoneIsCounted() throws {
        let run = Self.opened(["a", "b"])

        let pressed = run.press(Self.at(run.time, try Self.point(of: "ask:b", in: run)), mayJump: false)

        #expect(pressed == nil)
        #expect(run.frame.panel?.pressed == nil)
        #expect(!run.isLatest(1))
    }

    @Test func onlyTheLatestClicksAnswerIsHeard() throws {
        let run = Self.opened(["a", "b"])

        _ = run.press(Self.at(run.time, try Self.point(of: "ask:a", in: run)), mayJump: true)

        #expect(run.isLatest(1))
        #expect(!run.isLatest(0) && !run.isLatest(2))
    }

    /// Carried past the screen's middle and let go: the notch crosses to the other edge, home 420ms on.
    private static func droppedAcross() -> NotchRun {
        let run = NotchRun(at: 1000, in: setting)
        let notch = CGPoint(x: 2, y: 491)

        run.step(at(run.time + frameMS))
        #expect(run.press(at(run.time, notch), mayJump: true) == .carry)
        _ = run.drag(width: width, at(run.time + frameMS, CGPoint(x: 1000, y: 491)))
        let dropped = run.release(EdgeSettings(), height: height, at(run.time + frameMS))
        #expect(dropped?.isAcross == true)
        return run
    }

    @Test func aPressOffTheRowsCarriesTheNotchButNotWhileItCrossesToTheOtherEdge() {
        let run = Self.droppedAcross()

        Self.frames(run, for: 100, nil)

        #expect(run.press(Self.at(run.time, CGPoint(x: 2, y: 491)), mayJump: true) == nil)
    }

    @Test func aPressTakesTheNotchHomeOnTheOtherEdgeThoughNoFrameHasSeenItThereYet() {
        let run = Self.droppedAcross()

        Self.frames(run, for: 400, nil)

        #expect(run.press(Self.at(run.time + 40, CGPoint(x: 2, y: 491)), mayJump: true) == .carry)
    }

    @Test func aDragFollowsThePointerAlongTheEdgeAndLetGoAlongItStaysOnIt() {
        let run = NotchRun(at: 1000, in: Self.setting)

        run.step(Self.at(run.time + Self.frameMS))
        _ = run.press(Self.at(run.time, CGPoint(x: 2, y: 491)), mayJump: true)
        let carried = run.drag(width: Self.width, Self.at(run.time + Self.frameMS, CGPoint(x: 2, y: 291)))
        let dropped = run.release(EdgeSettings(), height: Self.height, Self.at(run.time + Self.frameMS))

        #expect(carried?.isCarrying == true && carried?.isAcross == false)
        #expect(dropped?.isAcross == false)
        #expect(dropped.map { abs($0.settings.along - run.notchY / Self.height) < 1e-9 } == true)
        #expect(run.drag == nil)
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

        #expect(run.lightTime(2030) == 2030)
        #expect(run.lightTime(1990) == 2000)
        #expect(run.time == 2000)
        run.step(Self.at(2016))
        #expect(run.time == 2016)
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
        #expect(Self.keys(run) == ["ask:a", "ask:b"])

        run.clickElsewhere(Self.at(run.time))
        Self.frames(run, for: 5000, CGPoint(x: 900, y: 491)) { run.phase == .closed }

        #expect(run.phase == .closed)
        #expect(Self.keys(run) == ["ask:b", "ask:a"])
    }

    @Test func aNewRowIsWashedOnlyWhileThePanelIsOut() {
        let closed = NotchRun(at: 1000, in: Self.setting)
        let open = Self.opened(["a"])

        #expect(closed.show(Self.board(["c", "a"], new: ["c"]), Self.at(1000)).isEmpty)
        #expect(open.show(Self.board(["c", "a"], new: ["c"]), Self.at(open.time)) == ["ask:c"])
    }

    @Test func theTimesNextChangeIsTheSoonestOfTheShownRows() {
        let run = NotchRun(at: 1000, in: Self.setting)

        #expect(run.nextAgeChange(after: 1_792_445_100_000) == nil)
        _ = run.show(Self.board(["a", "b"]), Self.at(1000))
        #expect(run.nextAgeChange(after: 1_792_445_100_000).map { $0 > 1_792_445_100_000 } == true)
    }
}
