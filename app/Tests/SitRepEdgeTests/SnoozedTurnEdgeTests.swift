import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepLines
import SitRepTestSupport
import Testing

/// A turn snoozed at the edge, over what the real CLI printed (`Lines.snoozedTurn`): a row of its own in the card's
/// Snoozed, counted there and gone from Needs you and its count, saying when it wakes or that it waits until it moves;
/// back in Needs you woken; and held apart from its session's asks asleep, two rows, while the panel is out.
@MainActor
@Suite(.backstop)
struct SnoozedTurnEdgeTests {
    /// When the real `watch` printed its first line here: 19:19 in London on Wednesday 4 November 2026.
    private static let now = 1_793_819_990_622.0

    /// `watch`'s lines up to this one, heard in order.
    private static func board(upTo place: Int) -> PanelBoard {
        var last = LastBoard()

        for line in Lines.snoozedTurn.prefix(place + 1) {
            _ = last.hear(.line(line), at: .now)
        }
        return PanelBoard(last)
    }

    @Test func aSnoozedTurnIsACardRowInSnoozedApartFromTheRows() throws {
        let board = Self.board(upTo: 0)

        #expect(board.sessions.map(\.id) == ["sr-fbrk3m"])
        #expect(board.sessions.map(\.kind) == [.turn])
        #expect(board.snoozed.map(\.id) == ["sr-ctnbd2", "sr-nx7bky"])
        #expect(board.snoozed.map(\.kind) == [.snoozedTurn, .snoozedTurn])
        expectEvery(board.snoozed) { $0.isSnoozed && $0.isTurn && $0.asks.isEmpty }
        #expect(board.snoozed.map(\.name) == ["Onboarding flow", "Ledger export"])
        #expect(board.snoozed.map(\.sub) == ["Contoso", "Northwind"])
        #expect(board.snoozed.map(\.wakesAt) == [1_793_869_200_000, nil])
        #expect(board.snoozed.map(\.since) == [1_793_819_270_000, 1_793_818_490_000])
    }

    /// Its time's place says when it wakes, or that it waits until it moves.
    @Test func itsTimeSaysWhenItWakesOrUntilItMoves() {
        let snoozed = Self.board(upTo: 0).snoozed

        #expect(snoozed.map { $0.timeText(at: Self.now, in: Self.london) } == ["tomorrow 09:00", "until it moves"])
    }

    /// Unfolded, Snoozed counts the turns and Needs you no longer does; each row its own key.
    @Test func snoozedCountsItAndNeedsYouNoLonger() {
        let run = Self.opened(Self.board(upTo: 0))

        #expect(Self.keys(run) == [
            "eyebrow:needsYou", "turn:sr-fbrk3m", "eyebrow:snoozed", "snoozedTurn:sr-ctnbd2", "snoozedTurn:sr-nx7bky",
        ])
        #expect(Self.eyebrows(run) == [
            Eyebrow(section: .needsYou, counts: [Eyebrow.Count(1, need: .turn)], isFolded: false, above: Eyebrow.first),
            Eyebrow(section: .snoozed, counts: [Eyebrow.Count(2)], isFolded: false, above: Eyebrow.after),
        ])
    }

    /// Woken, or its session at another turn, it is back in Needs you, counted there.
    @Test func wokenOrMovedOnItIsBackInNeedsYou() {
        let run = Self.opened(Self.board(upTo: 2))

        #expect(Self.keys(run) == ["eyebrow:needsYou", "turn:sr-nx7bky", "turn:sr-ctnbd2", "turn:sr-fbrk3m"])
        #expect(Self.eyebrows(run).map(\.counts) == [[Eyebrow.Count(3, need: .turn)]])
    }

    /// Out, the panel holds a session's asks asleep and its turn asleep as two rows, each kept in its place as core
    /// turns their order; in again, they take core's.
    @Test func outThePanelHoldsASessionsAsksAndItsTurnAsleepApart() {
        let run = Self.opened(Self.bothAsleep(asksFirst: true))
        let asleep = ["snoozedTurn:sr-ctnbd2", "snoozed:sr-nx7bky", "snoozedTurn:sr-nx7bky"]
        let onTheNotch = CGPoint(x: 3, y: 491), away = CGPoint(x: 900, y: 491)
        let at = { (time: Double, pointer: CGPoint?) in
            NotchRun.Moment(time: time, pointer: pointer, setting: Self.setting)
        }

        while run.phase != .open, run.time < 5000 {
            run.step(at(run.time + 1000 / 60, onTheNotch))
        }
        _ = run.show(Self.bothAsleep(asksFirst: false), at(run.time, onTheNotch))
        #expect(run.phase == .open)
        #expect(Array(Self.keys(run).suffix(3)) == asleep)

        run.clickElsewhere(at(run.time, nil))
        while run.phase != .closed, run.time < 15000 {
            run.step(at(run.time + 1000 / 60, away))
        }
        #expect(Array(Self.keys(run).suffix(3)) == [asleep[0], asleep[2], asleep[1]])
    }

    // MARK: Helpers

    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false, isChosen: true
    )

    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// A run over the board, nothing folded.
    private static func opened(_ board: PanelBoard) -> NotchRun {
        let kept = SavedSettings<CardSettings>(MemoryDefaults())

        kept.save(CardSettings(folded: []))

        let run = NotchRun(at: 1000, in: setting, folding: Folding(kept: kept), calendar: london)

        _ = run.show(board, NotchRun.Moment(time: run.time, pointer: nil, setting: setting))
        return run
    }

    private static func keys(_ run: NotchRun) -> [String] {
        run.list.content.entries.map(\.item.key)
    }

    /// The sessions of the first line, their turns as it has them: Fabrikam's at Lee's turn, Contoso's asleep until
    /// 09:00 tomorrow and Northwind's until it moves; and Northwind's asks asleep too, a row in Snoozed of their own,
    /// before its turn's or after it.
    private static func bothAsleep(asksFirst: Bool) -> PanelBoard {
        let fabrikam = WatchLine.Row(
            session: "sr-fbrk3m", name: "Release notes", projectName: "Fabrikam",
            lines: [
                .init(
                    "turn:sr-fbrk3m", .yourTurn, writer: "w-sr-fbrk3m", first: "Write the release notes",
                    since: 1_793_817_590_000
                ),
            ]
        )
        let contoso = WatchLine.SnoozedRow(
            session: "sr-ctnbd2", name: "Onboarding flow", projectName: "Contoso",
            lines: [
                .init(
                    "turn:sr-ctnbd2", .yourTurn, first: "Rework the onboarding flow", since: 1_793_819_270_000,
                    wakesAt: 1_793_869_200_000
                ),
            ]
        )
        let turn = WatchLine.SnoozedRow(
            session: "sr-nx7bky",
            lines: [
                .init(
                    "turn:sr-nx7bky", .yourTurn, first: "Export the ledger to CSV", since: 1_793_818_490_000,
                    wakesAt: nil
                ),
            ]
        )
        let asks = WatchLine.SnoozedRow(
            session: "sr-nx7bky",
            lines: [
                .init(
                    "ask:sr-nx7bky:k1", ask: "k1", first: "Pick the export's columns", since: 1_793_818_000_000,
                    wakesAt: 1_793_869_200_000
                ),
            ]
        )
        let line = WatchLine(
            at: 1_793_819_990_695, version: "0.3.0", rows: [fabrikam],
            snoozed: [contoso] + (asksFirst ? [asks, turn] : [turn, asks])
        )
        var last = LastBoard()

        _ = last.hear(.line(line.text), at: .now)
        return PanelBoard(last)
    }

    private static func eyebrows(_ run: NotchRun) -> [Eyebrow] {
        run.list.content.items.compactMap { if case let .eyebrow(eyebrow) = $0 { eyebrow } else { nil } }
    }
}
