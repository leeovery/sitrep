import Foundation
@testable import SitRepCore

/// Lines of `sitrep watch` as cli/output.ts's `watchLine` prints them, with the parts the menu, the notifications and
/// Settings read: the rows, the projects naming their sessions, and the windows.
enum Watched {
    /// An ask a window holds, a permission prompt, an away ask, a turn and a window working, as core orders them.
    static let rows = [
        row("ask:sr-ledger:k1", "ask", session: "sr-ledger", project: "switchboard", lead: "Choose how long the ledger keeps requests", second: "Switchboard · Usage", since: 1_792_445_000_000),
        row("stop:sr-dash:w1:1792445500000", "permission", session: "sr-dash", project: "switchboard", lead: "Allow Bash:", mono: "gh pr create", second: "Switchboard · Dashboard memory", since: 1_792_445_500_000),
        row("ask:sr-plan:k2", "ask", away: true, session: "sr-plan", project: "terrace", lead: "Pick the plan's shape", second: "No window holds it. Carry it on in Claude.", since: 1_792_440_000_000),
        row("turn:sr-boot", "yourTurn", session: "sr-boot", project: "kit", lead: "Write round 4 into DESIGN.md", second: "Kit · The bootstrap", since: 1_792_445_400_000),
        row("work:sr-diff", "working", session: "sr-diff", project: "mint", lead: "Reading", mono: "StatusMenu.swift", second: "Mint · Token-aware diff sizing", since: 1_792_445_540_000),
    ]

    static let projects = [
        project("switchboard", "Switchboard", sessions: [("sr-ledger", "Usage"), ("sr-dash", "Dashboard memory")]),
        project("terrace", "Terrace", sessions: [("sr-plan", "Plan the tool")]),
        project("kit", "Kit", sessions: [("sr-boot", "The bootstrap")]),
        project("mint", "Mint", sessions: [("sr-diff", "Token-aware diff sizing")]),
    ]

    /// The board with these rows new on it, these windows, at this CLI version.
    static func line(
        needYou: Int = 3, rows: [String] = rows, new: [String] = [], windows: [String] = [], version: String? = "0.2.0"
    ) -> String {
        """
        {"v":1,"at":1792445574706,"version":\(json(version)),"head":{"needYou":\(needYou),"sessions":\(rows.count)},\
        "rows":[\(rows.joined(separator: ","))],"projects":[\(projects.joined(separator: ","))],\
        "windows":[\(windows.joined(separator: ","))],\
        "new":[\(new.map { "\"\($0)\"" }.joined(separator: ","))],"changed":[]}
        """
    }

    static func row(
        _ key: String, _ kind: String, away: Bool = false, session: String, project: String, lead: String,
        mono: String? = nil, more: String? = nil, second: String, since: Int
    ) -> String {
        """
        {"key":"\(key)","is":"\(kind)","isAway":\(away),"session":"\(session)","project":"\(project)",\
        "letters":"Pr","ask":null,"writer":null,"first":{"lead":"\(lead)","mono":\(json(mono)),\
        "more":\(json(more))},"second":"\(second)","since":\(since)}
        """
    }

    /// A window on a session, running this sitrep.
    static func window(_ writer: String, session: String, name: String, project: String, version: String?, needsReload: Bool) -> String {
        """
        {"writer":"\(writer)","session":"\(session)","name":"\(name)","project":"\(project)",\
        "version":\(json(version)),"needsReload":\(needsReload),"where":null,"state":null,"attachedAt":1792440000000}
        """
    }

    private static func project(_ key: String, _ name: String, sessions: [(id: String, name: String)]) -> String {
        let sessions = sessions.map { session in
            """
            {"id":"\(session.id)","name":"\(session.name)","summary":"","now":[],"next":null,"isOpen":true,\
            "waiting":0,"parked":0,"updatedAt":1792440000000,"state":"working","since":1792440000000,\
            "doing":{"is":"working","line":{"lead":"Working","mono":null,"more":null},"since":1792440000000},\
            "asks":[]}
            """
        }

        return """
            {"key":"\(key)","name":"\(name)","directory":null,"open":\(sessions.count),"waiting":0,"parked":0,\
            "updatedAt":1792440000000,"sessions":[\(sessions.joined(separator: ","))]}
            """
    }

    private static func json(_ text: String?) -> String {
        text.map { "\"\($0)\"" } ?? "null"
    }
}

/// What `watch` said, in runs: each run begun, then what it said, heard a minute apart from noon.
func heard(_ runs: [Heard]...) -> LastBoard {
    var last = LastBoard()
    var minute = 0.0

    for run in runs {
        last.begin()
        for said in run {
            _ = last.hear(said, at: noon.addingTimeInterval(minute * 60))
            minute += 1
        }
    }

    return last
}

/// Noon in London on 20 October 2026.
let noon = Date(timeIntervalSince1970: 1_792_494_000)

let london = Date.FormatStyle(
    date: .omitted, time: .shortened, locale: Locale(identifier: "en_GB"),
    timeZone: TimeZone(identifier: "Europe/London")!
)
