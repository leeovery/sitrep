import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct BoardTests {
    @Test func aLineGivesTheBoardAtItsTimeWithTheCLIsVersionAndItsHead() throws {
        let board = try Board.read(Lines.pretty)

        #expect(board.at == at(1_792_445_574_706))
        #expect(board.version == "0.1.0")
        #expect(board.head.needYou == 2)
        #expect(board.head.sessions == 3)
        #expect(!board.head.isAllClear)
    }

    @Test func theRowsComeInTheLinesOrderASessionEachInItsSectionEachLineWhatItIsAndOfAnAskOrAWindow() throws {
        let rows = try Board.read(Lines.pretty).rows
        let lines = rows.map(\.newest)

        #expect(rows.map(\.id) == ["sr-7p4wd2", "sr-y6m1pr", "sr-a8n2xc"])
        #expect(rows.map(\.section) == [.needsYou, .needsYou, .yourTurn])
        #expect(rows.map(\.needsLee) == [true, true, false])
        #expect(lines.map(\.id) == [
            "ask:sr-7p4wd2:k1hs",
            "stop:sr-y6m1pr:00000000-0000-4000-8000-000000000002:1792445500000",
            "turn:sr-a8n2xc",
        ])
        #expect(lines.map(\.kind) == [.ask, .permission, .yourTurn])
        #expect(lines.map(\.ask) == ["k1hs", nil, nil])
        #expect(lines.map(\.writer) == [nil, "00000000-0000-4000-8000-000000000002", "00000000-0000-4000-8000-000000000001"])
    }

    @Test func aRowsLineComesInItsPartsThenTheRowsSecondAndItsTime() throws {
        let stop = try Board.read(Lines.pretty).rows[1]

        #expect(stop.lines.map(\.first) == [Board.Row.Words(lead: "Allow Bash", mono: "gh pr create", more: nil)])
        #expect(stop.newest.since == at(1_792_445_500_000))
        #expect(stop.second == "Woodgrove · Report caching and snags")
        #expect(stop.since == at(1_792_445_500_000))
        #expect(stop.letters == "Wo")
        #expect(stop.project == "woodgrove-5c3e91f0")
        #expect(stop.session == "sr-y6m1pr")
        #expect(!stop.isAway)
    }

    /// Each row names its session and its project by name, fields of their own, as a Needs you row shows them; an
    /// away row too, whose second line says no window holds it.
    @Test func aRowNamesItsSessionAndItsProject() throws {
        let rows = try Board.read(Lines.pretty).rows
        let byName = try Board.read(Lines.bySession[0]).rows

        #expect(rows.map(\.name) == ["Plan the launch", "Report caching and snags", "Build the desktop app"])
        #expect(rows.map(\.projectName) == ["Humongous", "Woodgrove", "Trey Research"])
        #expect(byName[2].isAway && byName[2].name == "Onboarding" && byName[2].projectName == "Lucerne")
        #expect(byName[2].second == "No window holds it. Carry it on in Claude.")
    }

    /// The real CLI's lines (`Lines.bySession`): Tailspin's three asks one row, the oldest first; Woodgrove's ask and
    /// its window's permission prompt another; Lucerne's away row last in Needs you; then Working, the desktop app's
    /// turn running before Litware's on its own work; then Wingtip's turn.
    @Test func aSessionWithSeveralLinesWaitingIsOneRowOfThemTheOldestFirst() throws {
        let board = try Board.read(Lines.bySession[0])
        let lines = board.rows.map { $0.lines.map(\.id) }

        #expect(board.rows.map(\.id) == ["sr-4t2kq8", "sr-d6k1vt", "sr-g2r8mw", "sr-m4h6qe", "sr-k7bt2s", "sr-v9d2wj"])
        #expect(board.rows.map(\.section) == [.needsYou, .needsYou, .needsYou, .working, .working, .yourTurn])
        #expect(board.rows.map(\.isAway) == [false, false, true, false, false, false])
        #expect(lines[0] == ["ask:sr-4t2kq8:k1", "ask:sr-4t2kq8:k2", "ask:sr-4t2kq8:k3"])
        #expect(board.rows[0].lines.map(\.first.lead) == [
            "Approve the first copy edit for the landing page", "Choose how the release notes are grouped",
            "Paste the failing test's output",
        ])
        #expect(board.rows[0].lines.map(\.since) == board.rows[0].lines.map(\.since).sorted())
        #expect(board.rows[0].since == board.rows[0].newest.since)
        #expect(board.rows[0].second == "Tailspin · Finish the Tailspin migration")
        #expect(board.rows[1].lines.map(\.kind) == [.ask, .permission])
        #expect(board.rows[1].lines.map(\.first.mono) == [nil, "gh pr create --draft"])
        #expect(board.rows[4].newest.kind == .onItsWork)
        #expect(board.head.needYou == 6)
        #expect(board.head.sessions == 6)
    }

    /// The second line: a fourth ask posted into Tailspin's session, new on it, its row gaining it as its newest line.
    @Test func aLineNewOnTheBoardNamesItsRowAsNew() throws {
        let before = try Board.read(Lines.bySession[0])
        let after = try Board.read(Lines.bySession[1])

        #expect(before.new.isEmpty && before.newRows.isEmpty)
        #expect(after.new.count == 1)
        #expect(after.rows[0].lines.last?.id == after.new.first)
        #expect(after.rows[0].lines.count == 4)
        #expect(after.newRows == ["sr-4t2kq8"])
        #expect(after.head.needYou == 7)
    }

    @Test func theWindowsSayWhereTheyAreWhatTheyAreDoingAndWhetherTheyNeedAReload() throws {
        let windows = try Board.read(Lines.pretty).windows

        #expect(windows.map(\.id) == ["00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000002"])
        #expect(windows.map(\.version) == [nil, "0.1.0"])
        #expect(windows.map(\.needsReload) == [true, false])
        #expect(windows.first?.where?.tmux == Board.Window.Where.Tmux(socket: "/private/tmp/tmux-501/default", pane: "%12"))
        #expect(windows.last?.where?.tmux == nil)
        #expect(windows.map(\.where?.zmx) == [nil, nil], "lines from before windows said their zmx session")
        #expect(windows.first?.state == nil)
        #expect(windows.last?.state == Board.Window.State(
            kind: .permission,
            since: at(1_792_445_500_000),
            tool: .init(name: "Bash", subject: "gh pr create"),
            question: nil
        ))
    }

    @Test func aWindowInZmxSaysItsSessionWhole() throws {
        let printed = #"""
        {"device":"/dev/ttys087","terminal":"ghostty","tmux":null,"zmx":{"session":"litware · restore-card"}}
        """#
        let decoded = try JSONDecoder().decode(Board.Window.Where.self, from: Data(printed.utf8))

        #expect(decoded == Board.Window.Where(device: "/dev/ttys087", terminal: "ghostty", zmx: .init(session: "litware · restore-card")))
    }

    /// A window of a line: its writer, its session, its place in the jump's order, the device of its own Ghostty
    /// window, and its Claude's folder.
    private static func window(
        _ writer: String, of session: String, order: Int?, on device: String?, in folder: String? = nil
    ) -> WatchLine.Window {
        WatchLine.Window(
            writer: writer, session: session, name: "Wingtip", project: "Wingtip",
            where: device.map { WatchLine.Where(device: $0) }, directory: folder, attachedAt: 1_792_445_500_000,
            jumpOrder: order
        )
    }

    /// A line holding only the windows given.
    private static func line(_ windows: [WatchLine.Window]) throws -> Board {
        try Board.read(WatchLine(at: 1_792_445_580_000, windows: windows).text)
    }

    @Test func aWindowSaysItsPlaceInTheOrderAJumpTriesItsSessionsWindowsInNoneInALineFromBeforeIt() throws {
        let board = try Self.line([
            Self.window("w1", of: "sr-a", order: 1, on: "/dev/ttys041"), Self.window("w2", of: "sr-a", order: nil, on: nil),
        ])

        #expect(board.windows.map(\.jumpOrder) == [1, nil])
        #expect(try Board.read(Lines.pretty).windows.map(\.jumpOrder) == [nil, nil])
    }

    @Test func aSessionsWindowsAJumpTriesComeInCoresOrderNeverByTheirPlaceInTheLineThoseWithNoOrderLeftOut() throws {
        let board = try Self.line([
            Self.window("w1", of: "sr-a", order: 1, on: "/dev/ttys041"),
            Self.window("w2", of: "sr-b", order: 0, on: "/dev/ttys042"),
            Self.window("w3", of: "sr-a", order: nil, on: nil),
            Self.window("w4", of: "sr-a", order: 0, on: "/dev/ttys004"),
        ])

        #expect(board.jumpWindows(of: "sr-a").map(\.device) == ["/dev/ttys004", "/dev/ttys041"])
        #expect(board.jumpWindows(of: "sr-z").isEmpty)
    }

    /// A watch before the order (9 November 2026) gives no window one.
    @Test func aLineCarryingNoOrderGivesTheSessionsWindowsSayingWhereTheyAreInTheLinesOwnOrder() throws {
        let board = try Self.line([
            Self.window("w1", of: "sr-a", order: nil, on: "/dev/ttys041"),
            Self.window("w2", of: "sr-b", order: nil, on: "/dev/ttys042"),
            Self.window("w3", of: "sr-a", order: nil, on: nil),
            Self.window("w4", of: "sr-a", order: nil, on: "/dev/ttys004"),
        ])

        #expect(board.jumpWindows(of: "sr-a").map(\.device) == ["/dev/ttys041", "/dev/ttys004"])
    }

    @Test func aSessionIsNamedByItsRowItsSnoozedRowAWindowOfItOrItsProjectAndNoneOffTheBoard() throws {
        let watching = try Board.read(Lines.pretty)
        let snoozed = try Board.read(Lines.snoozed[0])
        let windowed = try Self.line([Self.window("w1", of: "sr-a", order: nil, on: nil)])
        let rowless = try Board.read(watchedEmpty.replacingOccurrences(
            of: #""projects":[]"#,
            with: #""projects":[{"key":"humongous","name":"Humongous","sessions":[{"id":"sr-q1","name":"Quiet one"}]}]"#
        ))

        #expect(watching.name(of: "sr-7p4wd2") == "Plan the launch")
        #expect(snoozed.snoozed.first.map { snoozed.name(of: $0.session) } == snoozed.snoozed.first?.name)
        #expect(windowed.name(of: "sr-a") == "Wingtip")
        #expect(rowless.name(of: "sr-q1") == "Quiet one", "a session with no row and no window, by its project")
        #expect(windowed.name(of: "sr-z") == nil)
        #expect(rowless.name(of: "sr-z") == nil)
    }

    /// A line whose project lists the sessions given, each as the watch prints one, its `lastWindow` as given.
    private static func listing(_ sessions: [String]) throws -> Board {
        try Board.read(watchedEmpty.replacingOccurrences(
            of: #""projects":[]"#,
            with: #""projects":[{"key":"humongous","name":"Humongous","sessions":[\#(sessions.joined(separator: ","))]}]"#
        ))
    }

    /// An away session is carried on from the window it was last in: its writer, where it was, whether its device is
    /// its conversation's, and its folder, as the watch prints them; one from a line that does not say whose its device
    /// is says none. A session a window holds, null, and the `attaches` a line of 12 November 2026 printed, passed over.
    @Test func anAwaySessionIsCarriedOnFromTheWindowItWasLastIn() throws {
        let board = try Self.listing([
            #"{"id":"sr-q1","name":"Quiet one","lastWindow":{"writer":"w9","where":{"device":"/dev/ttys087","terminal":"ghostty","tmux":null,"zmx":{"session":"litware · card"}},"attaches":true,"ownsDevice":false,"directory":"/Users/me/Code/litware"}}"#,
            #"{"id":"sr-q2","name":"Older one","lastWindow":{"writer":"w8","where":null,"directory":null}}"#,
            #"{"id":"sr-h1","name":"Held one","lastWindow":null}"#,
        ])

        #expect(board.resumeWindow(of: "sr-q1") == Board.LastWindow(
            writer: "w9", where: .init(device: "/dev/ttys087", terminal: "ghostty", zmx: .init(session: "litware · card")),
            ownsDevice: false, directory: "/Users/me/Code/litware"
        ))
        #expect(board.resumeWindow(of: "sr-q2") == Board.LastWindow(writer: "w8"), "whose its device is not said")
        #expect(board.resumeWindow(of: "sr-h1") == nil)
        #expect(board.resumeWindow(of: "sr-z") == nil)
        #expect(!board.isHeld("sr-q1"))
    }

    /// A held session is carried on from the live window a jump tries first, else, none saying where it is, the first
    /// on the line: its device its own, and its folder as the watch prints it, none from a line before windows said it.
    @Test func aHeldSessionIsCarriedOnFromTheWindowAJumpTriesFirst() throws {
        let board = try Self.line([
            Self.window("w1", of: "sr-a", order: 1, on: "/dev/ttys041", in: "/Users/me/Code/wingtip"),
            Self.window("w2", of: "sr-a", order: 0, on: "/dev/ttys042", in: "/Users/me/Code/wingtip/.claude/worktrees/x"),
            Self.window("w3", of: "sr-b", order: nil, on: nil),
            Self.window("w4", of: "sr-b", order: nil, on: nil, in: "/Users/me/Code/b"),
        ])

        #expect(board.isHeld("sr-a"))
        #expect(board.resumeWindow(of: "sr-a") == Board.LastWindow(
            writer: "w2", where: .init(device: "/dev/ttys042", terminal: "ghostty"), ownsDevice: true,
            directory: "/Users/me/Code/wingtip/.claude/worktrees/x"
        ))
        #expect(board.resumeWindow(of: "sr-b") == Board.LastWindow(writer: "w3", ownsDevice: true))
        expectEvery(try Board.read(Lines.pretty).windows, "a line from before windows said it") { $0.directory == nil }
    }

    /// From a CLI before it, or in a shape that does not read, a session has none, and is named all the same.
    @Test(arguments: [#"{"id":"sr-q1","name":"Quiet one"}"#, #"{"id":"sr-q1","name":"Quiet one","lastWindow":{"where":5}}"#])
    func aSessionsLastWindowMissingOrNotReadingIsNoneItsNameKept(session: String) throws {
        let board = try Self.listing([session])

        #expect(board.resumeWindow(of: "sr-q1") == nil)
        #expect(board.name(of: "sr-q1") == "Quiet one")
    }

    @Test func aLineSaysWhatIsNewOnIt() throws {
        let board = try Board.read(Lines.pretty)

        #expect(board.new == ["stop:sr-y6m1pr:00000000-0000-4000-8000-000000000002:1792445500000"])
        #expect(board.newRows == ["sr-y6m1pr"])
    }

    /// The real CLI's line (`Lines.onItsWork`): Litware's window waiting on a wake, its row first, and Trey Research's
    /// on three agents.
    @Test func aWindowOnItsOwnWorkIsItsRowAndItsOwnWithWhatItWaitsOnOrWhenItsWakeIsDue() throws {
        let board = try Board.read(Lines.onItsWork)

        #expect(board.head.isAllClear)
        #expect(board.rows.map(\.id) == ["sr-k7bt2s", "sr-m4h6qe"])
        #expect(board.rows.map(\.section) == [.working, .working])
        #expect(board.rows.map(\.newest.id) == ["turn:sr-k7bt2s", "turn:sr-m4h6qe"])
        #expect(board.rows.map(\.newest.kind) == [.onItsWork, .onItsWork])
        #expect(board.rows.map(\.newest.first) == [
            Board.Row.Words(lead: "Wakes", until: at(1_792_670_195_432)),
            Board.Row.Words(lead: "Waiting on", subject: "3 agents"),
        ])
        #expect(board.rows.map(\.since) == [at(1_792_669_295_432), at(1_792_669_295_432)])
        #expect(board.windows.map(\.state?.kind) == [.onItsWork, .onItsWork])
    }

    @Test func anEmptyBoardIsAllClear() throws {
        let board = try Board.read(watchedEmpty)

        #expect(board.head.isAllClear)
        #expect(board.rows.isEmpty)
    }

    /// Version 1, a row per ask or stop, is the plugin before rows by session; version 2, `changed` in place of
    /// `boards`, the plugin before the watch carried them: this app reads neither.
    @Test func aLineOfAnotherVersionIsNamedAsSuchWhateverItsShape() {
        #expect(throws: Unread.version(given: 1, read: 3)) { try Board.read(#"{"v": 1, "feed": {}}"#) }
        #expect(throws: Unread.version(given: 2, read: 3)) {
            try Board.read(watchedEmpty.replacingOccurrences(of: #""v":3"#, with: #""v":2"#))
        }
        #expect(throws: Unread.version(given: 4, read: 3)) { try Board.read(#"{"v": 4, "feed": {}}"#) }
    }

    @Test(arguments: [
        "",
        "{\"v\":1,\"at\":17924455",
        #"{"head": {"needYou": 0, "sessions": 0}}"#,
        watchedEmpty.replacingOccurrences(of: #","windows":[]"#, with: ""),
        Lines.pretty.replacingOccurrences(of: #""is": "yourTurn""#, with: #""is": "napping""#),
        Lines.pretty.replacingOccurrences(of: #""section": "yourTurn""#, with: #""section": "napping""#),
        Lines.pretty.replacingOccurrences(of: #""name": "Plan the launch","# + "\n" + #"      "projectName""#, with: #""projectName""#),
        Lines.pretty.replacingOccurrences(of: #""projectName": "Humongous","#, with: ""),
        Lines.bySession[0].replacingOccurrences(of: #""lines":[{"key":"turn:sr-v9d2wj""#, with: #""lines":[],"was":[{"key":"turn:sr-v9d2wj""#),
    ])
    func aLineThatIsNotABoardIsUnread(line: String) {
        #expect(throws: Unread.shape) { try Board.read(line) }
    }

    /// What no surface shows is not read: the sessions' boards, or `changed` in their place, in any shape or none,
    /// leave the board as it was.
    @Test(arguments: [
        watchedEmpty.replacingOccurrences(of: #","boards":{}"#, with: ""),
        watchedEmpty.replacingOccurrences(of: #""boards":{}"#, with: #""changed":[]"#),
    ])
    func whatNoSurfaceShowsIsNotRead(line: String) throws {
        #expect(try Board.read(line) == (try Board.read(watchedEmpty)))
    }

    /// The projects, read for the names a jump gives sessions and for their asks, in any shape or none, leave every
    /// surface's board as it was; such a line only says nothing of its asks, so none is told to have left.
    @Test(arguments: [
        watchedEmpty.replacingOccurrences(of: #""projects":[]"#, with: #""projects":{"humongous":1}"#),
        watchedEmpty.replacingOccurrences(of: #""projects":[],"#, with: ""),
    ])
    func projectsThatDoNotReadLeaveTheBoardSayingNothingOfItsAsks(line: String) throws {
        let read = try Board.read(line), empty = try Board.read(watchedEmpty)

        #expect(read.waitingOnLee == nil)
        #expect(empty.waitingOnLee == [])
        #expect(read.rows == empty.rows && read.snoozed == empty.snoozed && read.windows == empty.windows)
        #expect(read.head == empty.head && read.new == empty.new && read.at == empty.at)
        #expect(read == (try Board.read(watchedEmpty.replacingOccurrences(of: #""projects":[],"#, with: ""))))
    }
}
