import Foundation
@testable import SitRepCore
import SitRepMenu
import SitRepTestSupport

/// Lines of `sitrep watch` with the parts the menu, the notifications and Settings read: the rows, the projects naming
/// their sessions, and the windows.
enum Watched {
    /// An ask a window holds, a permission prompt, an away ask, a turn and a window working, as core orders them.
    static let rows = [
        WatchLine.Row(
            session: "sr-ledger", name: "Usage", projectName: "Switchboard",
            lines: [
                .init(
                    "ask:sr-ledger:k1", .ask, first: "Choose how long the ledger keeps requests",
                    since: 1_792_445_000_000
                ),
            ]
        ),
        WatchLine.Row(
            session: "sr-dash", name: "Dashboard memory", projectName: "Switchboard",
            lines: [
                .init(
                    "stop:sr-dash:w1:1792445500000", .permission,
                    first: .init(lead: "Allow Bash:", mono: "gh pr create"), since: 1_792_445_500_000
                ),
            ]
        ),
        WatchLine.Row(
            session: "sr-plan", isAway: true, name: "Plan the tool", projectName: "Terrace",
            lines: [.init("ask:sr-plan:k2", .ask, first: "Pick the plan's shape", since: 1_792_440_000_000)]
        ),
        WatchLine.Row(
            session: "sr-boot", name: "The bootstrap", projectName: "Kit",
            lines: [.init("turn:sr-boot", .yourTurn, first: "Write round 4 into DESIGN.md", since: 1_792_445_400_000)]
        ),
        WatchLine.Row(
            session: "sr-diff", name: "Token-aware diff sizing", projectName: "Mint",
            lines: [
                .init(
                    "work:sr-diff", .working, first: .init(lead: "Reading", mono: "StatusMenu.swift"),
                    since: 1_792_445_540_000
                ),
            ]
        ),
    ]

    static let projects = [
        WatchLine.Project(
            name: "Switchboard",
            sessions: [.init(id: "sr-ledger", name: "Usage"), .init(id: "sr-dash", name: "Dashboard memory")]
        ),
        WatchLine.Project(name: "Terrace", sessions: [.init(id: "sr-plan", name: "Plan the tool")]),
        WatchLine.Project(name: "Kit", sessions: [.init(id: "sr-boot", name: "The bootstrap")]),
        WatchLine.Project(name: "Mint", sessions: [.init(id: "sr-diff", name: "Token-aware diff sizing")]),
    ]

    /// The board of these rows, with these new on it, these windows, at this CLI version; `needYou` of their lines
    /// needing Lee, counted from them unless given.
    static func line(
        needYou: Int? = nil, rows: [WatchLine.Row] = rows, new: [String] = [], windows: [WatchLine.Window] = [],
        version: String? = "0.2.0"
    ) -> String {
        WatchLine(
            version: version, head: needYou.map { .init(needYou: $0, sessions: rows.count) }, rows: rows,
            projects: projects, windows: windows, new: new
        ).text
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

extension AppSettings {
    /// As Lee leaves them, but sending a notification for each new ask.
    static var notifyingAsks: AppSettings {
        var settings = AppSettings()

        settings.notifiesNewAsks = true
        return settings
    }
}
