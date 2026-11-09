import Foundation
@testable import SitRepCore
import SitRepLines
import Testing

struct BoardTests {
    @Test func aLineGivesTheBoardAtItsTimeWithTheCLIsVersionAndItsHead() throws {
        let board = try Board.read(watched)

        #expect(board.at == at(1_792_445_574_706))
        #expect(board.version == "0.1.0")
        #expect(board.head.needYou == 2)
        #expect(board.head.sessions == 3)
        #expect(!board.head.isAllClear)
    }

    @Test func theRowsComeInTheLinesOrderASessionEachInItsSectionEachLineWhatItIsAndOfAnAskOrAWindow() throws {
        let rows = try Board.read(watched).rows
        let lines = rows.map(\.newest)

        #expect(rows.map(\.id) == ["sr-7e68fj", "sr-y4d0qj", "sr-aw3bgs"])
        #expect(rows.map(\.section) == [.needsYou, .needsYou, .yourTurn])
        #expect(rows.map(\.needsLee) == [true, true, false])
        #expect(lines.map(\.id) == [
            "ask:sr-7e68fj:k1hs",
            "stop:sr-y4d0qj:6c847b5b-722d-4343-88e0-42ece4662e7d:1792445500000",
            "turn:sr-aw3bgs",
        ])
        #expect(lines.map(\.kind) == [.ask, .permission, .yourTurn])
        #expect(lines.map(\.ask) == ["k1hs", nil, nil])
        #expect(lines.map(\.writer) == [nil, "6c847b5b-722d-4343-88e0-42ece4662e7d", "408a755f-ed3a-4ee1-9cc0-c0208cf3e03b"])
    }

    @Test func aRowsLineComesInItsPartsThenTheRowsSecondAndItsTime() throws {
        let stop = try Board.read(watched).rows[1]

        #expect(stop.lines.map(\.first) == [Board.Row.Words(lead: "Allow Bash", mono: "gh pr create", more: nil)])
        #expect(stop.newest.since == at(1_792_445_500_000))
        #expect(stop.second == "Switchboard · Dashboard memory and snags")
        #expect(stop.since == at(1_792_445_500_000))
        #expect(stop.letters == "Sw")
        #expect(stop.project == "switchboard-7a75d7ba")
        #expect(stop.session == "sr-y4d0qj")
        #expect(!stop.isAway)
    }

    /// Each row names its session and its project by name, fields of their own, as a Needs you row shows them; an
    /// away row too, whose second line says no window holds it.
    @Test func aRowNamesItsSessionAndItsProject() throws {
        let rows = try Board.read(watched).rows
        let byName = try Board.read(Lines.bySession[0]).rows

        #expect(rows.map(\.name) == ["Plan the tool", "Dashboard memory and snags", "Build the Mac app"])
        #expect(rows.map(\.projectName) == ["Terrace", "Switchboard", "SitRep"])
        #expect(byName[2].isAway && byName[2].name == "Onboarding" && byName[2].projectName == "Goosemates")
        #expect(byName[2].second == "No window holds it. Carry it on in Claude.")
    }

    /// The real CLI's lines (`Lines.bySession`): Harness's three asks one row, the oldest first; Switchboard's ask and
    /// its window's permission prompt another; Goosemates' away row last in Needs you; then Working, the Mac app's
    /// turn running before Kit's on its own work; then Fumi's turn.
    @Test func aSessionWithSeveralLinesWaitingIsOneRowOfThemTheOldestFirst() throws {
        let board = try Board.read(Lines.bySession[0])
        let lines = board.rows.map { $0.lines.map(\.id) }

        #expect(board.rows.map(\.id) == ["sr-4g01a7", "sr-dash02", "sr-gs7kq2", "sr-macapp", "sr-k7bt2s", "sr-v3t7a0"])
        #expect(board.rows.map(\.section) == [.needsYou, .needsYou, .needsYou, .working, .working, .yourTurn])
        #expect(board.rows.map(\.isAway) == [false, false, true, false, false, false])
        #expect(lines[0] == ["ask:sr-4g01a7:k1", "ask:sr-4g01a7:k2", "ask:sr-4g01a7:k3"])
        #expect(board.rows[0].lines.map(\.first.lead) == [
            "Approve the first fix batch from the branch review", "Choose how the release notes are grouped",
            "Paste the failing test's output",
        ])
        #expect(board.rows[0].lines.map(\.since) == board.rows[0].lines.map(\.since).sorted())
        #expect(board.rows[0].since == board.rows[0].newest.since)
        #expect(board.rows[0].second == "Harness · Finish the Harness modernisation")
        #expect(board.rows[1].lines.map(\.kind) == [.ask, .permission])
        #expect(board.rows[1].lines.map(\.first.mono) == [nil, "gh pr create --draft"])
        #expect(board.rows[4].newest.kind == .onItsWork)
        #expect(board.head.needYou == 6)
        #expect(board.head.sessions == 6)
    }

    /// The second line: a fourth ask posted into Harness's session, new on it, its row gaining it as its newest line.
    @Test func aLineNewOnTheBoardNamesItsRowAsNew() throws {
        let before = try Board.read(Lines.bySession[0])
        let after = try Board.read(Lines.bySession[1])

        #expect(before.new.isEmpty && before.newRows.isEmpty)
        #expect(after.new.count == 1)
        #expect(after.rows[0].lines.last?.id == after.new.first)
        #expect(after.rows[0].lines.count == 4)
        #expect(after.newRows == ["sr-4g01a7"])
        #expect(after.head.needYou == 7)
    }

    @Test func theWindowsSayWhereTheyAreWhatTheyAreDoingAndWhetherTheyNeedAReload() throws {
        let windows = try Board.read(watched).windows

        #expect(windows.map(\.id) == ["408a755f-ed3a-4ee1-9cc0-c0208cf3e03b", "6c847b5b-722d-4343-88e0-42ece4662e7d"])
        #expect(windows.map(\.version) == [nil, "0.1.0"])
        #expect(windows.map(\.needsReload) == [true, false])
        #expect(windows.first?.where?.tmux == Board.Window.Where.Tmux(socket: "/private/tmp/tmux-501/default", pane: "%148"))
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
        {"device":"/dev/ttys087","terminal":"ghostty","tmux":null,"zmx":{"session":"kit · restore-card"}}
        """#
        let decoded = try JSONDecoder().decode(Board.Window.Where.self, from: Data(printed.utf8))

        #expect(decoded == Board.Window.Where(device: "/dev/ttys087", terminal: "ghostty", zmx: .init(session: "kit · restore-card")))
    }

    /// A window of a line, as the watch prints one: its writer, its session, its place in the jump's order, and the
    /// device of its own Ghostty window.
    private static func window(_ writer: String, of session: String, order: Int?, on device: String?) -> String {
        let place = device.map { #"{"device":"\#($0)","terminal":"ghostty","tmux":null,"zmx":null}"# } ?? "null"

        return #"{"writer":"\#(writer)","session":"\#(session)","name":"Fumi","project":"Fumi","version":"0.1.0","needsReload":false,"where":\#(place),"state":null,"attachedAt":1792445500000,"jumpOrder":\#(order.map(String.init) ?? "null")}"#
    }

    /// A line holding only the windows given.
    private static func line(_ windows: [String]) throws -> Board {
        try Board.read(watchedEmpty.replacingOccurrences(of: #""windows":[]"#, with: #""windows":[\#(windows.joined(separator: ","))]"#))
    }

    @Test func aWindowSaysItsPlaceInTheOrderAJumpTriesItsSessionsWindowsInNoneInALineFromBeforeIt() throws {
        let board = try Self.line([
            Self.window("w1", of: "sr-a", order: 1, on: "/dev/ttys041"), Self.window("w2", of: "sr-a", order: nil, on: nil),
        ])

        #expect(board.windows.map(\.jumpOrder) == [1, nil])
        #expect(try Board.read(watched).windows.map(\.jumpOrder) == [nil, nil])
    }

    @Test func aSessionsWindowsAJumpTriesComeInCoresOrderNeverByTheirPlaceInTheLineThoseWithNoOrderLeftOut() throws {
        let board = try Self.line([
            Self.window("w1", of: "sr-a", order: 1, on: "/dev/ttys041"),
            Self.window("w2", of: "sr-b", order: 0, on: "/dev/ttys042"),
            Self.window("w3", of: "sr-a", order: nil, on: nil),
            Self.window("w4", of: "sr-a", order: 0, on: "/dev/ttys043"),
        ])

        #expect(board.jumpWindows(of: "sr-a").map(\.device) == ["/dev/ttys043", "/dev/ttys041"])
        #expect(board.jumpWindows(of: "sr-z").isEmpty)
    }

    @Test func aSessionIsNamedByItsRowItsSnoozedRowOrAWindowOfItAndNoneOffTheBoard() throws {
        let watching = try Board.read(watched)
        let snoozed = try Board.read(Lines.snoozed[0])
        let windowed = try Self.line([Self.window("w1", of: "sr-a", order: nil, on: nil)])

        #expect(watching.name(of: "sr-7e68fj") == "Plan the tool")
        #expect(snoozed.snoozed.first.map { snoozed.name(of: $0.session) } == snoozed.snoozed.first?.name)
        #expect(windowed.name(of: "sr-a") == "Fumi")
        #expect(windowed.name(of: "sr-z") == nil)
    }

    @Test func aLineSaysWhatIsNewOnIt() throws {
        let board = try Board.read(watched)

        #expect(board.new == ["stop:sr-y4d0qj:6c847b5b-722d-4343-88e0-42ece4662e7d:1792445500000"])
        #expect(board.newRows == ["sr-y4d0qj"])
    }

    /// The real CLI's line (`Lines.onItsWork`): Kit's window waiting on a wake, its row first, and SitRep's on three
    /// agents.
    @Test func aWindowOnItsOwnWorkIsItsRowAndItsOwnWithWhatItWaitsOnOrWhenItsWakeIsDue() throws {
        let board = try Board.read(Lines.onItsWork)

        #expect(board.head.isAllClear)
        #expect(board.rows.map(\.id) == ["sr-k7bt2s", "sr-macapp"])
        #expect(board.rows.map(\.section) == [.working, .working])
        #expect(board.rows.map(\.newest.id) == ["turn:sr-k7bt2s", "turn:sr-macapp"])
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
        watchedEmpty.replacingOccurrences(of: #""windows":[],"#, with: ""),
        watched.replacingOccurrences(of: #""is": "yourTurn""#, with: #""is": "napping""#),
        watched.replacingOccurrences(of: #""section": "yourTurn""#, with: #""section": "napping""#),
        watched.replacingOccurrences(of: #""name": "Plan the tool","# + "\n" + #"      "projectName""#, with: #""projectName""#),
        watched.replacingOccurrences(of: #""projectName": "Terrace","#, with: ""),
        Lines.bySession[0].replacingOccurrences(of: #""lines":[{"key":"turn:sr-v3t7a0""#, with: #""lines":[],"was":[{"key":"turn:sr-v3t7a0""#),
    ])
    func aLineThatIsNotABoardIsUnread(line: String) {
        #expect(throws: Unread.shape) { try Board.read(line) }
    }

    /// What no surface shows is not read: the projects, the sessions' boards, or `changed` in their place, in any
    /// shape or none, leave the board as it was.
    @Test(arguments: [
        watchedEmpty.replacingOccurrences(of: #","boards":{}"#, with: ""),
        watchedEmpty.replacingOccurrences(of: #""boards":{}"#, with: #""changed":[]"#),
        watchedEmpty.replacingOccurrences(of: #""projects":[]"#, with: #""projects":{"terrace":1}"#),
        watchedEmpty.replacingOccurrences(of: #""projects":[],"#, with: ""),
    ])
    func whatNoSurfaceShowsIsNotRead(line: String) throws {
        #expect(try Board.read(line) == (try Board.read(watchedEmpty)))
    }
}
