import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepTestSupport

/// The board the asks panel's tests read, as Paper's boards draw it: in Needs you, Help desk redesign of Northwind
/// with two asks, a choice Claude recommends one of and a yes; Shift schedules of Contoso with a words ask; Invoice
/// ledger of Fabrikam stopped at a permission prompt alone; Onboarding flow of Tailspin at Lee's turn; Data import of
/// Litware asking a yes; Mobile app at work; and in Snoozed, Help desk redesign's third ask, put off until tomorrow.
enum AsksBoard {
    /// When the line is printed, ms.
    static let at = 1_792_445_574_706
    static let minute = 60_000

    static let helpDesk = "sr-nw0001", shifts = "sr-ct0002", ledger = "sr-fb0003", dataImport = "sr-lw0006"

    /// The choice, its line 4 minutes old though it was posted long before, reopened since.
    static let choice = WatchLine.Ask(
        id: "k1", wants: .choice, yes: nil, title: "Thread replies, or keep them flat?", options: ["Threaded", "Flat"],
        recommended: "Threaded", at: at - 600 * minute
    )
    /// The same choice of three, on the board with Help desk redesign alone.
    static let choiceOfThree = WatchLine.Ask(
        id: "k1", wants: .choice, yes: nil, title: "Thread replies, or keep them flat?",
        options: ["Threaded", "Flat", "Nested"], recommended: "Threaded", at: at - 600 * minute
    )
    static let yes = WatchLine.Ask(id: "k2", wants: .yes, yes: "Approve", title: "Review Tickets & Replies, round 1")
    static let mapping = WatchLine.Ask(id: "k1", wants: .yes, yes: "Map", title: "Map the columns by their names?")
    static let tomorrow = at + 1_440 * minute
    static let asleep = WatchLine.Ask(
        id: "k3", wants: .yes, yes: "Ship", title: "Ship the help desk", snooze: .until(tomorrow)
    )
    /// A third ask of Help desk redesign's, on the board `withNotes`.
    static let notes = WatchLine.Ask(id: "k4", wants: .yes, yes: "Ship", title: "Ship the release notes?")
    static let words = WatchLine.Ask(
        id: "k1", wants: .words, yes: nil, title: "Say what an empty rota should read", needs: "The empty state's words"
    )

    /// The rows, those named in `without` left out of Help desk redesign's lines and asks, as an ask leaves the board;
    /// `alone`, Help desk redesign's row alone, its choice one of three, with nothing snoozed; `withNotes`, a third ask
    /// of its, after its two.
    static func line(without: Set<String> = [], alone: Bool = false, withNotes: Bool = false) -> WatchLine {
        let notesLine = WatchLine.Row.Line(
            "ask:\(helpDesk):k4", .ask, ask: "k4", first: "Ship the release notes?", since: ago(20)
        )
        let helpDeskLines: [WatchLine.Row.Line] = [
            .init("ask:\(helpDesk):k1", .ask, ask: "k1", first: "Thread replies, or keep them flat?", since: ago(4)),
            .init("ask:\(helpDesk):k2", .ask, ask: "k2", first: "Review Tickets & Replies, round 1", since: ago(12)),
            withNotes ? notesLine : nil,
        ].compactMap { $0 }.filter { !without.contains($0.ask ?? "") }
        let rows = [
            helpDeskLines.isEmpty ? nil : WatchLine.Row(
                session: helpDesk, name: "Help desk redesign", projectName: "Northwind", lines: helpDeskLines
            ),
            WatchLine.Row(
                session: shifts, name: "Shift schedules", projectName: "Contoso",
                lines: [
                    .init(
                        "ask:\(shifts):k1", .ask, ask: "k1", first: "Say what an empty rota should read", since: ago(7)
                    ),
                ]
            ),
            WatchLine.Row(
                session: ledger, name: "Invoice ledger", projectName: "Fabrikam",
                lines: [
                    .init(
                        "stop:w1", .permission, writer: "w1", first: .init(lead: "Allow", mono: "Bash"), since: ago(2)
                    ),
                ]
            ),
            WatchLine.Row(
                session: "sr-ts0004", name: "Onboarding flow", projectName: "Tailspin",
                lines: [.init("turn:sr-ts0004", .yourTurn, first: "Built the steps", since: ago(9))]
            ),
            WatchLine.Row(
                session: "sr-wg0005", name: "Mobile app", projectName: "Woodgrove",
                lines: [.init("work:sr-wg0005", .working, first: "Running the tests", since: ago(3))]
            ),
            WatchLine.Row(
                session: dataImport, name: "Data import", projectName: "Litware",
                lines: [
                    .init(
                        "ask:\(dataImport):k1", .ask, ask: "k1", first: "Map the columns by their names?", since: ago(5)
                    ),
                ]
            ),
        ].compactMap { $0 }.filter { !alone || $0.session == helpDesk }
        let projects = [
            WatchLine.Project(name: "Northwind", sessions: [
                WatchLine.Session(
                    id: helpDesk, name: "Help desk redesign", state: .needsYou,
                    asks: [alone ? choiceOfThree : choice, yes, asleep, withNotes ? notes : nil].compactMap { $0 }
                        .filter { !without.contains($0.id) }
                ),
            ]),
            WatchLine.Project(name: "Contoso", sessions: [
                WatchLine.Session(id: shifts, name: "Shift schedules", state: .needsYou, asks: [words]),
            ]),
            WatchLine.Project(name: "Litware", sessions: [
                WatchLine.Session(id: dataImport, name: "Data import", state: .needsYou, asks: [mapping]),
            ]),
        ]

        let snoozed = WatchLine.SnoozedRow(
            session: helpDesk, name: "Help desk redesign", projectName: "Northwind",
            lines: [
                .init("ask:\(helpDesk):k3", ask: "k3", first: "Ship the help desk", since: ago(30), wakesAt: tomorrow),
            ]
        )

        return WatchLine(at: at, rows: rows, snoozed: alone ? [] : [snoozed], projects: projects)
    }

    /// The board as the panel has it.
    static func board(without: Set<String> = [], alone: Bool = false, withNotes: Bool = false) -> PanelBoard {
        var last = LastBoard()

        _ = last.hear(
            .line(line(without: without, alone: alone, withNotes: withNotes).text),
            at: Date(timeIntervalSince1970: Double(at) / 1000)
        )
        return PanelBoard(last)
    }

    static func ago(_ minutes: Int) -> Int {
        at - minutes * minute
    }
}
