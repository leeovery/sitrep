import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepLines
import Testing

/// A turn snoozed at the edge, over what the real CLI printed (`Lines.snoozedTurn`): a row of its own in the card's
/// Snoozed, counted there and gone from Your turn and its count, saying when it wakes or that it waits until it moves;
/// back on Your turn woken; and held apart from its session's asks asleep, two rows, while the panel is out.
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

    /// Out, the panel holds a session's asks asleep and its turn asleep as two rows, each kept in its place as core
    /// turns their order; in again, they take core's.
    @Test func outThePanelHoldsASessionsAsksAndItsTurnAsleepApart() {
        let run = Self.opened(Self.bothAsleep(asksFirst: true))
        let asleep = ["snoozedTurn:sr-ctnbd2", "snoozed:sr-nwtrn5", "snoozedTurn:sr-nwtrn5"]
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

    /// The first line with Northwind's asks asleep too, a row in Snoozed of their own, before its turn's or after it.
    private static func bothAsleep(asksFirst: Bool) -> PanelBoard {
        var line = try! JSONSerialization.jsonObject(with: Data(Lines.snoozedTurn[0].utf8)) as! [String: Any]
        var rows = line["snoozed"] as! [[String: Any]]
        var asks = rows[1]
        var last = LastBoard()

        asks["lines"] = [[
            "key": "ask:sr-nwtrn5:k1", "is": "ask", "ask": "k1", "since": 1_793_818_000_000,
            "wakesAt": 1_793_869_200_000,
            "first": ["lead": "Pick the export's columns", "mono": NSNull(), "subject": NSNull(), "more": NSNull(),
                      "until": NSNull()],
        ]]
        asks["wakesAt"] = 1_793_869_200_000
        rows.insert(asks, at: asksFirst ? 1 : 2)
        line["snoozed"] = rows

        let text = String(decoding: try! JSONSerialization.data(withJSONObject: line), as: UTF8.self)

        _ = last.hear(.line(text), at: .now)
        return PanelBoard(last)
    }

    private static func eyebrows(_ run: NotchRun) -> [Eyebrow] {
        run.list.content.items.compactMap { if case let .eyebrow(eyebrow) = $0 { eyebrow } else { nil } }
    }
}
