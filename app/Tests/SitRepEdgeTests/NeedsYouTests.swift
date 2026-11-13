import CoreGraphics
import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import Testing

/// Needs you at the edge as Lee decided it on 13 November 2026: its count is the asks and stops waiting and the
/// sessions at his turn alike; the notch's light is orange while an ask waits, else blue while a turn does, and keeps
/// its colour as it goes out; and the notch's pulse comes for a new ask and for a session moving into his turn, each
/// as he set it, never for a turn there as SitRep starts, and once for each turn.
@MainActor
struct NeedsYouTests {
    private static let ask = row(
        "ask:sr-a:k1", "ask", session: "sr-a", lead: "Approve the plan", second: "SitRep · Plan",
        since: 1_792_445_000_000
    )

    private static func turn(_ id: String = "sr-t", ended since: Int = 1_792_445_100_000) -> String {
        row("turn:\(id)", "yourTurn", session: id, lead: "Built it", second: "Kit · \(id)", since: since)
    }

    private static func working(_ id: String = "sr-w") -> String {
        row("work:\(id)", "working", session: id, lead: "Running", second: "DocMan · \(id)", since: 1_792_445_000_000)
    }

    /// The boards these lines make, heard in turn by one run, each its own, with these pulses.
    private static func boards(_ lines: [[String]], pulses: Set<Need> = [.ask]) -> [PanelBoard] {
        var last = LastBoard()

        return lines.map { rows in
            let asks = rows.filter { $0.contains(#""section":"needsYou""#) }.count

            _ = last.hear(.line(line(needYou: asks, sessions: rows.count, new: [], rows: rows)), at: .now)
            return PanelBoard(last, pulses: pulses)
        }
    }

    private static func board(_ rows: String...) -> PanelBoard {
        boards([rows])[0]
    }

    // MARK: The count

    /// Lee's "11 need you": three sessions with asks, one holding two, make 4, and seven others at his turn 7, working
    /// none of it. Each session is one row: one at his turn with asks waiting is its asks' row, as core gives it, so
    /// its turn counts nothing.
    @Test func needYouCountsTheAsksAndTheTurnsEachSessionOneRow() {
        let held = row(
            "ask:sr-a:k1", "ask", session: "sr-a", lead: "One", second: "SitRep · Plan", since: 1_792_445_000_000,
            newer: [(key: "ask:sr-a:k2", lead: "Two", since: 1_792_445_000_001)]
        )
        let asks = [held] + ["sr-b", "sr-c"].map { id in
            row("ask:\(id):k1", "ask", session: id, lead: "One", second: "SitRep · \(id)", since: 1_792_445_000_000)
        }
        let turns = (1 ... 7).map { Self.turn("sr-t\($0)") }
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: 4, sessions: 11, new: [], rows: asks + turns + [Self.working()])), at: .now)
        let board = PanelBoard(last)

        #expect(board.head.title == "11 need you")
        #expect(board.sessions.filter { $0.section == .needsYou }.map(\.kind) == Array(repeating: .needs, count: 3)
            + Array(repeating: .turn, count: 7))
        #expect(Self.board(Self.turn(), Self.working()).head.title == "1 needs you")
        #expect(Self.board(Self.working()).head.title == "All clear")
    }

    // MARK: The light

    @Test func theLightIsOrangeWhileAnAskWaitsElseBlueWhileATurnDoesElseOut() {
        #expect(Self.board(Self.ask, Self.turn(), Self.working()).need == .ask)
        #expect(Self.board(Self.turn(), Self.working()).need == .turn)
        #expect(Self.board(Self.working()).need == nil)
        #expect(Self.board(Self.turn()).needsLee && !Self.board(Self.working()).needsLee)
    }

    /// Lit by a turn, the light is blue; an ask turns it orange; and going out it keeps the colour it last had.
    @Test func theNotchsLightTakesItsColourFromWhatLitItAndKeepsItGoingOut() {
        let run = NotchRun(at: 1000, in: Self.setting)
        let moment = NotchRun.Moment(time: 1000, pointer: nil, setting: Self.setting)
        let shown = Self.boards([[Self.turn()], [Self.ask, Self.turn()], [Self.turn()], [Self.working()]])

        #expect(run.lightNeed == .ask)
        _ = run.show(shown[0], moment)
        #expect(run.lightNeed == .turn)
        _ = run.show(shown[1], moment)
        #expect(run.lightNeed == .ask)
        _ = run.show(shown[2], moment)
        _ = run.show(shown[3], moment)
        #expect(run.lightNeed == .turn)
    }

    private static let setting = NotchRun.Setting(
        stage: Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491), mirror: .identity,
        style: .meniscus, reducesMotion: false
    )

    // MARK: The pulse

    /// What the notch is told, board by board, each after the one before, the first after none.
    private static func told(_ lines: [[String]], pulses: Set<Need>) -> [[String]] {
        let shown = boards(lines, pulses: pulses)

        return zip([PanelBoard()] + shown, shown).map { last, board in
            let notch = Told()

            board.tell(notch, after: last)
            return notch.told
        }
    }

    /// A session moving into Lee's turn from working pulses the notch while that pulse is on; with it off, the turn
    /// lights the notch with no pulse.
    @Test(arguments: [(Set<Need>([.turn]), "newAsk"), (Set<Need>([.ask]), "needsLeeQuietly")])
    func aSessionMovingIntoLeesTurnPulsesTheNotchWhileThatPulseIsOn(pulses: Set<Need>, told: String) {
        #expect(Self.told([[Self.working("sr-t")], [Self.turn()]], pulses: pulses) == [[], [told]])
    }

    /// A turn already there on the first board lights the notch with no pulse, and the same turn on the boards after
    /// it pulses nothing, nor does it again as its session comes back to it from an ask.
    @Test func noPulseForATurnThereAtTheStartNorTwiceForOneTurn() {
        let told = Self.told(
            [[Self.turn()], [Self.turn(), Self.working()], [Self.ask.replacingOccurrences(of: "sr-a", with: "sr-t")],
             [Self.turn()]],
            pulses: [.turn]
        )

        #expect(told == [["needsLeeQuietly"], [], [], []])
    }

    /// A new ask pulses the notch while its pulse is on, as it always did; off, it lights the notch with none.
    @Test(arguments: [(Set<Need>([.ask]), "newAsk"), (Set<Need>(), "needsLeeQuietly")])
    func aNewAskPulsesTheNotchWhileItsPulseIsOn(pulses: Set<Need>, told: String) {
        let notch = Told()
        var last = LastBoard()

        _ = last.hear(.line(line(needYou: 0, sessions: 1, new: [], rows: [Self.working()])), at: .now)
        let before = PanelBoard(last, pulses: pulses)
        let asked = line(needYou: 1, sessions: 2, new: ["ask:sr-a:k1"], rows: [Self.ask, Self.working()])

        _ = last.hear(.line(asked), at: .now)
        PanelBoard(last, pulses: pulses).tell(notch, after: before)

        #expect(notch.told == [told])
    }

    /// Told again as what this Mac shows changes, a board brings no pulse of its own.
    @Test func aBoardToldAgainPulsesNothing() {
        let shown = Self.boards([[Self.working("sr-t")], [Self.turn()]], pulses: [.turn])

        #expect(!shown[1].newTurns.isEmpty && shown[1].retold.newTurns.isEmpty)
    }
}
