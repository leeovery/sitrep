import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepLines
import SitRepPanelTestSupport
import SitRepTestSupport
import Testing

/// Snooze at the edge, over what the real CLI printed (`Lines.snoozed`): the Snoozed rows the card and the strip show
/// (the strip's since 14 November 2026) apart from the rows the menu shows; Snoozed the card's last section, folded at
/// first; and an ask woken at its time arriving as a new one does, the notch swelling, the strip flashing and Needs you
/// unfolding, while one Lee wakes does not.
@MainActor
struct SnoozedEdgeTests {
    /// `watch`'s lines up to this one, heard in order.
    private static func board(upTo place: Int) -> PanelBoard {
        var last = LastBoard()

        for line in Lines.snoozed.prefix(place + 1) {
            _ = last.hear(.line(line), at: .now)
        }
        return PanelBoard(last)
    }

    @Test func theSnoozedRowsAreApartFromTheRowsTheMenuShows() throws {
        let board = Self.board(upTo: 0)
        let asleep = try #require(board.snoozed.first)

        #expect(board.sessions.map(\.id) == ["sr-4g01a7"])
        #expect(board.sessions.allSatisfy { !$0.isSnoozed })
        #expect(board.sessions[0].asks == ["k3"])
        #expect(asleep.id == "sr-4g01a7" && asleep.isSnoozed && asleep.away)
        #expect(asleep.asks == ["k1", "k2"])
        #expect(asleep.lines.map(\.title) == ["Review the plan", "Pick when stage 2 runs"])
        #expect(asleep.name == "Finish the Harness modernisation" && asleep.project == "Harness")
        // away, its second line still its project: it was put off, so it urges nothing
        #expect(asleep.sub == "Harness")
        #expect(board.sessions[0].sub == "No window holds it. Carry it on in Claude.")
        #expect(asleep.wakesAt == 1_792_741_532_000)
        #expect(board.cardSessions == board.sessions + [asleep])
    }

    /// A Snoozed row's words change only at midnight, so the card is drawn again then for it, not each minute.
    @Test func aSnoozedRowIsDrawnAgainAtMidnight() throws {
        let run = Self.opened(Self.ledger(), kept: Self.kept([]))
        let now = 1_792_741_527_619.0
        let midnight = 1_792_796_400_000.0

        #expect(run.nextAgeChange(after: now).map { $0 < midnight } == true)
        _ = run.show(Self.ledger(waiting: false), Self.at(run.time))
        #expect(run.nextAgeChange(after: now) == midnight)
    }

    @Test func snoozedIsTheCardsLastSectionFoldedAtFirst() {
        let run = Self.opened()

        #expect(Self.keys(run) == ["eyebrow:needsYou", "needs:sr-4g01a7", "eyebrow:snoozed"])
        #expect(run.list.content.items.last == .eyebrow(Eyebrow(section: .snoozed, counts: [Eyebrow.Count(2)], isFolded: true, above: 14)))
    }

    /// Unfolded as Lee left it, the session has a row in each.
    @Test func unfoldedTheSessionHasARowInEach() {
        let run = Self.opened(kept: Self.kept([]))

        #expect(Self.keys(run).suffix(2) == ["eyebrow:snoozed", "snoozed:sr-4g01a7"])
        #expect(Self.keys(run).contains("needs:sr-4g01a7"))
    }

    /// With nothing waiting but asks asleep, the card lists Snoozed with no head.
    @Test func aCardOfSnoozedAloneHasNoHead() {
        let run = Self.opened(Self.ledger())

        _ = run.show(Self.ledger(waiting: false), Self.at(run.time))
        #expect(run.list.head == nil)
        #expect(Self.keys(run) == ["eyebrow:snoozed"])
    }

    @Test func aWakeAtItsTimeSwellsTheNotchAndUnfoldsNeedsYou() {
        let told = Told()

        Self.board(upTo: 1).tell(told, after: Self.board(upTo: 0))
        #expect(told.told == ["newAsk"])
        #expect(Self.board(upTo: 1).new == ["sr-4g01a7"])

        let run = Self.opened(kept: Self.kept([.needsYou]))

        _ = run.show(Self.board(upTo: 1), Self.at(run.time))
        #expect(!run.folded.sections.contains(.needsYou))
    }

    @Test func aWakeNowSwellsNothingAndLeavesNeedsYouFolded() {
        let told = Told()

        Self.board(upTo: 2).tell(told, after: Self.board(upTo: 1))
        #expect(told.told.isEmpty)
        #expect(Self.board(upTo: 2).new.isEmpty)

        let run = Self.opened(kept: Self.kept([.needsYou]))

        _ = run.show(Self.board(upTo: 2), Self.at(run.time))
        #expect(run.folded.sections.contains(.needsYou))
    }

    @Test(arguments: [(1, true), (2, false)])
    func onlyAWakeAtItsTimeFlashesTheStrip(place: Int, flashes: Bool) {
        let strip = Strip(
            length: .full, maxLength: .full, along: 0.42, sessions: [], measure: Self.measure,
            StripInput(time: 0, pointer: nil, stage: Self.stage)
        )
        var time = 0.0
        let play = { (ms: Double) -> Double in
            var flash = 0.0

            for _ in 0 ..< Int(ms / (1000 / 60)) {
                time += 1000 / 60
                flash = max(flash, strip.frame(StripInput(time: time, pointer: nil, stage: Self.stage)).marks.map(\.flash).max() ?? 0)
            }
            return flash
        }
        let before = Self.board(upTo: place - 1), after = Self.board(upTo: place)

        strip.show(before.cardSessions, new: [])
        _ = play(3000)
        strip.show(after.cardSessions, new: after.new)
        #expect((play(1500) > 0.9) == flashes)
    }

    /// The menu's jump from a session's Snoozed row presses that row in, not its row in Needs you.
    @Test func theMenusJumpFromASnoozedRowPressesThatRow() throws {
        let run = Self.opened(Self.ledger(), kept: Self.kept([]))
        let onTheNotch = CGPoint(x: 3, y: 491)

        _ = run.show(Self.ledger(held: true), Self.at(run.time))
        while run.phase != .open, run.time < 5000 {
            run.step(NotchRun.Moment(time: run.time + 1000 / 60, pointer: onTheNotch, setting: Self.setting))
        }
        #expect(Self.keys(run).contains("needs:sr-nw0001"))
        guard case .jump? = run.jump(to: "snoozed:sr-nw0001", Self.at(run.time)) else {
            Issue.record("the menu's jump found no row")
            return
        }
        run.step(Self.at(run.time + 1000 / 60))
        #expect(run.frame.panel?.pressed == "snoozed:sr-nw0001")
    }

    // MARK: Helpers

    private static let stage = StripStage(width: 1512, height: 982, menu: 37)
    private static var measure: StripMeasure { .uniform(200) }

    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false, isChosen: true
    )

    private static func at(_ time: Double) -> NotchRun.Moment {
        NotchRun.Moment(time: time, pointer: nil, setting: setting)
    }

    /// A run over the board, the first line unless given, its folds as kept, unless none are.
    private static func opened(
        _ board: PanelBoard = SnoozedEdgeTests.board(upTo: 0), kept: SavedSettings<CardSettings>? = nil
    ) -> NotchRun {
        let run = NotchRun(at: 1000, in: setting, folding: Folding(kept: kept), calendar: london)

        _ = run.show(board, at(run.time))
        return run
    }

    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private static func kept(_ sections: Set<BoardSection>) -> SavedSettings<CardSettings> {
        let kept = SavedSettings<CardSettings>(MemoryDefaults())

        kept.save(CardSettings(folded: sections))
        return kept
    }

    private static func keys(_ run: NotchRun) -> [String] {
        run.list.content.entries.map(\.item.key)
    }

    /// Northwind's Ledger export at the time of the real CLI's first line here, its asks as that line has them: one
    /// waiting in Needs you, unless not `waiting`, as its last waiting ask snoozed would leave it, and two asleep, the
    /// first waking five seconds on; away, unless `held` by a window.
    private static func ledger(held: Bool = false, waiting: Bool = true) -> PanelBoard {
        let ask = WatchLine.Row(
            isAway: !held,
            lines: [
                .init("ask:sr-nw0001:k3", .ask, ask: "k3", first: "Give the go for stage 3", since: 1_792_741_127_000),
            ]
        )
        let asleep = WatchLine.SnoozedRow(isAway: !held, lines: [
            .init(
                "ask:sr-nw0001:k1", ask: "k1", first: "Review the plan", since: 1_792_740_927_000,
                wakesAt: 1_792_741_532_000
            ),
            .init(
                "ask:sr-nw0001:k2", ask: "k2", first: "Pick when stage 2 runs", since: 1_792_741_027_000,
                wakesAt: 1_792_745_127_000
            ),
        ])
        let line = WatchLine(at: 1_792_741_527_619, version: "0.2.0", rows: waiting ? [ask] : [], snoozed: [asleep])
        var last = LastBoard()

        _ = last.hear(.line(line.text), at: .now)
        return PanelBoard(last)
    }
}
