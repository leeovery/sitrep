import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import Testing

/// The controller's frame while the open panel is idle: armed for when it next draws differently, a row's time or a
/// your-turn row folding into "N earlier", whichever comes first.
@MainActor
struct NotchControllerTests {
    private static let midnight = 1_792_710_000_000.0 // 23 October 2026, 00:00 BST

    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// A run over one your turn, its turn ended at 23:59:30 in London, at this time on the wall clock.
    private static func run(period: FoldPeriod, at now: Double) -> NotchRun {
        let setting = NotchRun.Setting(
            stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
            style: .meniscus, reducesMotion: false, period: period
        )
        let since = Int(midnight) - 30_000
        let line = """
            {"v":2,"at":\(since),"version":"0.2.0","head":{"needYou":0,"sessions":1},"rows":[{"session":"sr-a",\
            "section":"yourTurn","isAway":false,"project":"sitrep","letters":"SR","lines":[{"key":"turn:sr-a",\
            "is":"yourTurn","ask":null,"writer":null,"first":{"lead":"Your turn","mono":null,"more":null},\
            "since":\(since)}],"second":"SitRep · The Mac app","since":\(since)}],"projects":[],"windows":[],\
            "new":[],"changed":[]}
            """
        var last = LastBoard()
        let run = NotchRun(at: 1000, in: setting, wall: { now }, calendar: london)

        _ = last.hear(.line(line), at: Date())
        _ = run.show(PanelBoard(last), NotchRun.Moment(time: 1000, pointer: nil, setting: setting))
        return run
    }

    /// Ten seconds to midnight, the row folds then, before its time next ticks at 00:00:30.
    @Test func itsFrameIsArmedForTheNextRefold() throws {
        let now = Self.midnight - 10_000

        #expect(try #require(NotchController.wait(for: Self.run(period: .today, at: now), at: now)) == 10)
    }

    /// With nothing folding, the row's time next ticking.
    @Test func itsFrameIsArmedForTheNextTimeWithNothingFolding() throws {
        let now = Self.midnight - 10_000

        #expect(try #require(NotchController.wait(for: Self.run(period: .never, at: now), at: now)) == 40)
    }
}
