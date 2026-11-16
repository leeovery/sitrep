import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The controller's frame while the open panel is idle: armed for when it next draws differently, a row's time, and
/// nothing else, as no your-turn row folds away (board J).
@MainActor
@Suite(.backstop)
struct NotchControllerTests {
    private static let midnight = 1_792_710_000_000.0 // 23 October 2026, 00:00 BST

    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// A run over one your turn, its turn ended at 23:59:30 in London.
    private static func run() -> NotchRun {
        let setting = NotchRun.Setting(
            stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
            style: .meniscus, reducesMotion: false, isChosen: true
        )
        let since = Int(midnight) - 30_000
        let turn = WatchLine.Row(
            session: "sr-a", name: "The desktop app", projectName: "Trey Research",
            lines: [.init("turn:sr-a", .yourTurn, first: "Your turn", since: since)]
        )
        var last = LastBoard()
        let run = NotchRun(at: 1000, in: setting, calendar: london)

        _ = last.hear(.line(WatchLine(at: since, version: "0.2.0", rows: [turn]).text), at: Date())
        _ = run.show(PanelBoard(last), NotchRun.Moment(time: 1000, pointer: nil, setting: setting))
        return run
    }

    /// Ten seconds to midnight, the row's time next ticking, at 00:00:30.
    @Test func itsFrameIsArmedForTheNextTime() throws {
        let now = Self.midnight - 10_000

        #expect(try #require(NotchController.wait(for: Self.run(), at: now)) == 40)
    }

    /// Hours on, the row is still there, and still the next to tick: nothing folds it away.
    @Test func aYourTurnHoursOldStillTicks() throws {
        let now = Self.midnight + 5 * 3_600_000 - 10_000

        #expect(Self.run().list.content.items.map(\.key) == ["eyebrow:needsYou", "turn:sr-a"])
        #expect(try #require(NotchController.wait(for: Self.run(), at: now)) == 40)
    }
}
