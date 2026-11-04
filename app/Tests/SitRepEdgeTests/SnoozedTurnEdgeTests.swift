import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepLines
import Testing

/// A turn snoozed at the edge, over what the real CLI printed (`Lines.snoozedTurn`): a row of its own in the card's
/// Snoozed, counted there and gone from Your turn and its count, saying when it wakes or that it waits until it moves;
/// back on Your turn woken.
@MainActor
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
        #expect(board.snoozed.map(\.id) == ["sr-ctnbd2", "sr-nwtrn5"])
        #expect(board.snoozed.map(\.kind) == [.snoozedTurn, .snoozedTurn])
        #expect(board.snoozed.allSatisfy { $0.isSnoozed && $0.isTurn && $0.asks.isEmpty })
        #expect(board.snoozed.map(\.name) == ["Onboarding flow", "Ledger export"])
        #expect(board.snoozed.map(\.sub) == ["Contoso", "Northwind"])
        #expect(board.snoozed.map(\.wakesAt) == [1_793_869_200_000, nil])
        #expect(board.snoozed.map(\.since) == [1_793_819_270_000, 1_793_818_490_000])
    }

    /// Its time's place says when it wakes, or that it waits until it moves.
    @Test func itsTimeSaysWhenItWakesOrUntilItMoves() {
        let snoozed = Self.board(upTo: 0).snoozed

        #expect(snoozed.map { $0.timeText(at: Self.now, in: Self.london) } == ["Thu 09:00", "until it moves"])
    }

    /// Unfolded, Snoozed counts the turns and Your turn no longer does; each row its own key.
    @Test func snoozedCountsItAndYourTurnNoLonger() {
        let run = Self.opened(Self.board(upTo: 0))

        #expect(Self.keys(run) == [
            "eyebrow:yourTurn", "turn:sr-fbrk3m", "eyebrow:snoozed", "snoozedTurn:sr-ctnbd2", "snoozedTurn:sr-nwtrn5",
        ])
        #expect(Self.eyebrows(run) == [
            Eyebrow(section: .yourTurn, count: 1, isFolded: false, above: Eyebrow.first),
            Eyebrow(section: .snoozed, count: 2, isFolded: false, above: Eyebrow.after),
        ])
    }

    /// Woken, or its session at another turn, it is back on Your turn, counted there.
    @Test func wokenOrMovedOnItIsBackOnYourTurn() {
        let run = Self.opened(Self.board(upTo: 2))

        #expect(Self.keys(run) == ["eyebrow:yourTurn", "turn:sr-nwtrn5", "turn:sr-ctnbd2", "turn:sr-fbrk3m"])
        #expect(Self.eyebrows(run).map(\.count) == [3])
    }

    // MARK: Helpers

    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false
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

        let run = NotchRun(at: 1000, in: setting, kept: kept, calendar: london)

        _ = run.show(board, NotchRun.Moment(time: run.time, pointer: nil, setting: setting))
        return run
    }

    private static func keys(_ run: NotchRun) -> [String] {
        run.list.content.entries.map(\.item.key)
    }

    private static func eyebrows(_ run: NotchRun) -> [Eyebrow] {
        run.list.content.items.compactMap { if case let .eyebrow(eyebrow) = $0 { eyebrow } else { nil } }
    }
}
