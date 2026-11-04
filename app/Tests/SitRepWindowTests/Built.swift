import Foundation
@testable import SitRepCore
@testable import SitRepWindow

/// A session for a board built in parts, `watch`'s line made from them with the fields the real CLI prints
/// (`Lines`), in loops rather than literals, so one the size of Lee's real board costs the compiler nothing. Every time
/// counts back from when the fixtures' board was seeded.
struct Built {
    let id: String
    /// Its project's key, whose name is its key capitalised.
    let project: String
    var state: Board.Session.State = .working
    /// No window holds it.
    var isAway = false
    /// Its lines waiting on Lee, each so many minutes old, the oldest first: its row in Needs you.
    var waiting: [Double] = []
    /// Its asks asleep, each so many minutes old and waking so many minutes after the board was seeded.
    var snoozed: [(age: Double, wakesIn: Double)] = []
    var parked = 0
    /// How many minutes ago its turn began, or ended on Your turn.
    var turn: Double = 1

    var name: String { "Session \(id)" }
    var projectName: String { project.capitalized }

    /// Its line waiting on Lee at this place, by its key.
    func line(_ place: Int) -> String { "ask:\(id):k\(place)" }

    /// Its ask asleep at this place, by its key: numbered after those waiting, as an ask keeps its key in Needs you
    /// and in Snoozed, so one snoozed or woken keeps it.
    func asleep(_ place: Int) -> String { "ask:\(id):k\(waiting.count + place)" }

    /// `watch`'s line over these sessions, its projects in the order they first come, its rows in core's: Needs you
    /// by its newest line, the newest first, those a window holds first, each row's lines the newest first; Your turn,
    /// the newest first; Working.
    static func printed(_ sessions: [Built], new: [String] = []) -> Heard {
        let needing = sessions.filter { !$0.waiting.isEmpty }.sorted { $0.coreOrder < $1.coreOrder }
        let turning = sessions.filter { $0.waiting.isEmpty && !$0.isAway }
        let working = turning.filter { $0.state == .working }
        let turns = turning.filter { $0.state == .yourTurn }.sorted { $0.turn < $1.turn }
        let keys = sessions.map(\.project).reduce(into: [String]()) { keys, key in
            if !keys.contains(key) {
                keys.append(key)
            }
        }
        let board: [String: Any] = [
            "v": 3, "at": ms(0), "version": "0.2.0",
            "head": ["needYou": sessions.map(\.waiting.count).reduce(0, +), "sessions": sessions.count],
            "rows": needing.map { $0.row(.needsYou) } + turns.map { $0.row(.yourTurn) }
                + working.map { $0.row(.working) },
            "snoozed": sessions.filter { !$0.snoozed.isEmpty }.map(\.asleepRow),
            "projects": keys.map { key in project(key, sessions.filter { $0.project == key }) },
            "windows": [], "new": new, "boards": [:],
        ]

        return .line(String(decoding: try! JSONSerialization.data(withJSONObject: board), as: UTF8.self))
    }

    /// Core's order in Needs you: those a window holds first, then the newest first, by the newest line.
    private var coreOrder: (Int, Double) { (isAway ? 1 : 0, waiting.min()!) }

    private static func project(_ key: String, _ sessions: [Built]) -> [String: Any] {
        [
            "key": key, "name": key.capitalized, "directory": NSNull(),
            "open": sessions.filter { !$0.isAway }.count, "waiting": sessions.map(\.waiting.count).reduce(0, +),
            "snoozed": sessions.map(\.snoozed.count).reduce(0, +), "parked": sessions.map(\.parked).reduce(0, +),
            "updatedAt": ms(0), "sessions": sessions.map(\.session),
        ]
    }

    private var session: [String: Any] {
        [
            "id": id, "name": name, "summary": "", "now": [], "next": NSNull(), "isOpen": !isAway,
            "waiting": waiting.count, "snoozed": snoozed.count, "parked": parked, "updatedAt": Self.ms(0),
            "state": isAway ? "away" : state.rawValue, "since": Self.ms(turn),
            "doing": ["is": isAway ? "away" : "working", "line": Self.words("Working"), "since": Self.ms(turn)],
            "asks": [],
        ]
    }

    private func row(_ section: Board.Row.Section) -> [String: Any] {
        let lines = section == .needsYou
            ? waiting.indices.sorted { waiting[$0] < waiting[$1] }
                .map { lineOf(key: line($0), is: "ask", "Ask \($0) of \(id)", age: waiting[$0]) }
            : [lineOf(key: "turn:\(id)", is: section == .working ? "working" : "yourTurn", "Turn of \(id)", age: turn)]

        return [
            "session": id, "section": section.rawValue, "isAway": isAway && section == .needsYou, "project": project,
            "name": name, "projectName": projectName, "letters": "Pr", "lines": lines, "second": projectName,
            "since": lines[0]["since"]!,
        ]
    }

    private var asleepRow: [String: Any] {
        let lines = snoozed.indices.map { place in
            [
                "key": asleep(place), "ask": "k\(waiting.count + place)", "first": Self.words("Asleep \(place) of \(id)"),
                "since": Self.ms(snoozed[place].age), "wakesAt": Self.ms(-snoozed[place].wakesIn),
            ]
        }

        return [
            "session": id, "isAway": isAway, "project": project, "name": name, "projectName": projectName,
            "letters": "Pr", "lines": lines, "second": projectName, "wakesAt": Self.ms(-snoozed.map(\.wakesIn).min()!),
        ]
    }

    private func lineOf(key: String, is kind: String, _ lead: String, age: Double) -> [String: Any] {
        ["key": key, "is": kind, "ask": NSNull(), "writer": NSNull(), "first": Self.words(lead), "since": Self.ms(age)]
    }

    private static func words(_ lead: String) -> [String: Any] {
        ["lead": lead, "mono": NSNull(), "subject": NSNull(), "more": NSNull(), "until": NSNull()]
    }

    /// So many minutes before the board was seeded, as `watch` prints a time.
    private static func ms(_ minutes: Double) -> Double {
        (SitRepWindowTests.minutes(before: minutes).timeIntervalSince1970 * 1000).rounded()
    }

    /// The board as the window lists it.
    static func listed(_ sessions: [Built], new: [String] = []) -> Listed {
        Listed(heard(printed(sessions, new: new)))
    }
}

extension Built {
    /// A board the size of Lee's real one: 20 projects, 19 sessions a window holds and 6 away, 100 items parked. The
    /// first five projects hold two live sessions each, the next nine one, each with 5 parked: 7 need Lee, with 1 to 3
    /// lines each, 13 in all, 6 work and 6 are on Lee's turn. Projects 15 and 16 hold an away session with an ask
    /// waiting; 17 an away one with 5 parked; 18 an away one with nothing, as do 19 and 20: the three quiet.
    static let leesSize: [Built] = {
        let live = (1 ... 5).flatMap { [$0, $0] } + Array(6 ... 14)
        let sessions = live.enumerated().map { place, project in
            var session = Built(id: String(format: "s%02d", place + 1), project: String(format: "p%02d", project))

            session.parked = 5
            session.turn = Double(place + 1)
            switch place % 3 {
            case 0: session.waiting = (0 ... place / 3 % 3).map { Double(200 - place * 7 - $0 * 30) }
            case 1: session.state = .working
            default: session.state = .yourTurn
            }
            return session
        }
        let away = (15 ... 18).map { project in
            var session = Built(id: "a\(project)", project: String(format: "p%02d", project), isAway: true)

            session.waiting = project <= 16 ? [Double(500 + project)] : []
            session.parked = project == 17 ? 5 : 0
            return session
        }
        let quiet = (19 ... 20).map { Built(id: "q\($0)", project: "p\($0)", isAway: true) }

        return sessions + away + quiet
    }()
}
