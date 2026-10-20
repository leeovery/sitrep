import CoreGraphics
import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import Testing

/// The notch as the controller runs it, with no screen: a press goes to the row under it, the clock never goes back,
/// the rows keep their places while the panel is out, a new row is washed only then, and a click's answer is heard
/// only for the latest click.
struct NotchRunTests {
    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false
    )
    private static let frameMS = 1000.0 / 60
    private static let onTheNotch = CGPoint(x: 3, y: 491)

    /// A board of asks, each a window holds, in this order, the ones named new on it.
    private static func board(_ ids: [String], new: [String] = []) -> PanelBoard {
        let rows = ids.map { id in
            row("ask:\(id)", "ask", session: "sr-\(id)", lead: "Ask \(id)", second: "SitRep · \(id)", since: 1_792_445_000_000)
        }
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: ids.count, sessions: ids.count, new: new.map { "ask:\($0)" }, rows: rows)), at: Date())
        return PanelBoard(last)
    }

    /// A run over a board of these, its panel opened by the pointer held on the notch.
    private static func opened(_ ids: [String]) -> NotchRun {
        let run = NotchRun(at: 1000, in: setting)

        _ = run.show(board(ids), at: run.time, in: setting)
        while run.notch.phase != .open, run.time < 4000 {
            run.step(at: run.time + frameMS, pointer: onTheNotch, in: setting)
        }
        return run
    }

    /// Where a row of the list as drawn shows on the stage: its middle.
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
        #expect(run.notch.phase == .open)

        _ = run.show(Self.board(["c", "a", "b"], new: ["c"]), at: run.time, in: Self.setting)
        #expect(Self.keys(run) == ["ask:c", "ask:a", "ask:b"])

        let pressed = run.press(at: try Self.point(of: "ask:a", in: run), time: run.time, in: Self.setting, mayJump: true)

        guard case let .jump(session, to: target, click: click) = pressed else {
            Issue.record("pressed \(String(describing: pressed))")
            return
        }
        #expect(session.id == "ask:a" && target == "sr-a" && click == 1)
        run.step(at: run.time + Self.frameMS, pointer: try Self.point(of: "ask:a", in: run), in: Self.setting)
        #expect(run.frame.panel?.pressed == "ask:a")
    }

    @Test func noPressJumpsWhileAJumpRunsAndNoneIsCounted() throws {
        let run = Self.opened(["a", "b"])

        let pressed = run.press(at: try Self.point(of: "ask:b", in: run), time: run.time, in: Self.setting, mayJump: false)

        #expect(pressed == nil)
        #expect(run.frame.panel?.pressed == nil)
        #expect(!run.isLatest(1))
    }

    @Test func onlyTheLatestClicksAnswerIsHeard() throws {
        let run = Self.opened(["a", "b"])

        _ = run.press(at: try Self.point(of: "ask:a", in: run), time: run.time, in: Self.setting, mayJump: true)

        #expect(run.isLatest(1))
        #expect(!run.isLatest(0) && !run.isLatest(2))
    }

    @Test func aPressOnTheNotchOffTheRowsMayCarryItButNotWhileItCrossesToTheOtherEdge() {
        let run = NotchRun(at: 1000, in: Self.setting)
        run.step(at: 1000 + Self.frameMS, pointer: nil, in: Self.setting)

        #expect(run.press(at: CGPoint(x: 2, y: 491), time: run.time, in: Self.setting, mayJump: true) == .carry)

        run.notch.carry()
        run.notch.drop(across: true)

        #expect(run.press(at: CGPoint(x: 2, y: 491), time: run.time, in: Self.setting, mayJump: true) == nil)
    }

    @Test func theClockNeverGoesBack() {
        let run = NotchRun(at: 1000, in: Self.setting)

        run.step(at: 2000, pointer: nil, in: Self.setting)
        run.step(at: 1990, pointer: nil, in: Self.setting)
        #expect(run.time == 2000)

        run.catchUp(to: 1500, in: Self.setting)
        _ = run.show(Self.board(["a"]), at: 1200, in: Self.setting)
        #expect(run.time == 2000)
        #expect(run.clock(1999) == 2000)
        #expect(run.clock(2010) == 2010)
    }

    @Test func whileThePanelIsOutTheRowsKeepTheirPlacesAndTakeCoresOrderOnceItIsIn() {
        let run = Self.opened(["a", "b"])

        _ = run.show(Self.board(["b", "a"]), at: run.time, in: Self.setting)
        #expect(Self.keys(run) == ["ask:a", "ask:b"])

        run.notch.clickElsewhere()
        while run.notch.phase != .closed, run.time < 10_000 {
            run.step(at: run.time + Self.frameMS, pointer: CGPoint(x: 900, y: 491), in: Self.setting)
        }

        #expect(run.notch.phase == .closed)
        #expect(Self.keys(run) == ["ask:b", "ask:a"])
    }

    @Test func aNewRowIsWashedOnlyWhileThePanelIsOut() {
        let closed = NotchRun(at: 1000, in: Self.setting)
        let open = Self.opened(["a"])

        #expect(closed.show(Self.board(["c", "a"], new: ["c"]), at: 1000, in: Self.setting).isEmpty)
        #expect(open.show(Self.board(["c", "a"], new: ["c"]), at: open.time, in: Self.setting) == ["ask:c"])
    }
}
