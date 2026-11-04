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

    @Test func theProjectsHoldTheirSessionsEachWithItsStateAndItsAsks() throws {
        let projects = try Board.read(watched).projects

        #expect(projects.map(\.id) == ["terrace", "switchboard-7a75d7ba", "code-84dbac88"])
        #expect(projects.map(\.directory) == [nil, "/Users/leeovery/Code/switchboard", "/Users/leeovery/Code/sitrep"])

        let terrace = try #require(projects.first?.sessions.first)

        #expect(terrace.state == .needsYou)
        #expect(terrace.next == nil)
        #expect(terrace.since == at(1_791_991_983_206))
        #expect(terrace.asks.map(\.id) == ["k1hs"])
        #expect(terrace.asks.first?.wants == .yes)
        #expect(terrace.asks.first?.yes == "Approve")
        #expect(terrace.asks.first?.where == "In the chat: decision 3, what an approval binds to")
        #expect(terrace.asks.first?.state == .waiting)
        #expect(projects.last?.sessions.first?.state == .yourTurn)
    }

    @Test func eachSessionSaysWhatItIsDoingAsTheLineUnderItsNameSaysIt() throws {
        let sessions = try Board.read(watched).projects.flatMap(\.sessions)

        #expect(sessions.map(\.doing.kind) == [.yourTurn, .permission, .yourTurn])
        #expect(sessions[1].doing == Board.Session.Doing(
            kind: .permission,
            line: Board.Row.Words(lead: "Allow Bash", mono: "gh pr create", more: nil),
            since: at(1_792_445_500_000)
        ))
    }

    /// The real CLI's line (`Lines.parked`): every session, followed or not, with when it started and what it parked,
    /// oldest first.
    @Test func eachSessionSaysWhenItStartedAndWhatItParked() throws {
        let sessions = try Board.read(Lines.parked[0]).projects.flatMap(\.sessions)

        #expect(sessions.map(\.id) == ["sr-ctnbd2", "sr-fbrs7k", "sr-nwdgr4"])
        #expect(sessions.map(\.created) == [at(1_793_709_655_000), at(1_793_799_655_000), at(1_793_792_455_000)])
        #expect(sessions.map(\.parked) == sessions.map(\.parkedItems.count))
        #expect(sessions[2].parkedItems == [
            SessionBoard.Parked(
                id: "77k4",
                title: "Handle multi-currency rows",
                where: "After the first export ships",
                ref: "docs/export.md",
                at: at(1_793_803_255_257)
            ),
            SessionBoard.Parked(id: "3k0a", title: "Retry failed uploads", where: nil, ref: nil, at: at(1_793_803_255_326)),
        ])
    }

    /// A CLI from before the feed said them printed neither: no start, and nothing parked listed, though counted.
    @Test func outputFromBeforeTheFeedSaidThemReadsWithNoStartAndNoParkedItems() throws {
        let sessions = try Board.read(Lines.watch[0]).projects.flatMap(\.sessions)

        #expect(sessions.contains { $0.parked > 0 })
        #expect(sessions.allSatisfy { $0.created == nil && $0.parkedItems.isEmpty })
    }

    @Test func theWindowsSayWhereTheyAreWhatTheyAreDoingAndWhetherTheyNeedAReload() throws {
        let windows = try Board.read(watched).windows

        #expect(windows.map(\.id) == ["408a755f-ed3a-4ee1-9cc0-c0208cf3e03b", "6c847b5b-722d-4343-88e0-42ece4662e7d"])
        #expect(windows.map(\.version) == [nil, "0.1.0"])
        #expect(windows.map(\.needsReload) == [true, false])
        #expect(windows.first?.where?.tmux == Board.Window.Where.Tmux(socket: "/private/tmp/tmux-501/default", pane: "%148"))
        #expect(windows.last?.where?.tmux == nil)
        #expect(windows.first?.state == nil)
        #expect(windows.last?.state == Board.Window.State(
            kind: .permission,
            since: at(1_792_445_500_000),
            tool: .init(name: "Bash", subject: "gh pr create"),
            question: nil
        ))
    }

    @Test func aLineSaysWhatIsNewOnIt() throws {
        let board = try Board.read(watched)

        #expect(board.new == ["stop:sr-y4d0qj:6c847b5b-722d-4343-88e0-42ece4662e7d:1792445500000"])
        #expect(board.newRows == ["sr-y4d0qj"])
    }

    /// The real CLI's lines (`Lines.following`): none carried before the follow line, then the session followed and a
    /// null for the one no project files, then only the board that changed.
    @Test func aLineCarriesTheBoardsOfTheSessionsFollowedNewOrChangedAndANullForOneNotFound() throws {
        let boards = try Lines.following.map { try Board.read($0).boards }

        #expect(boards.map { $0.keys.sorted() } == [[], ["sr-h4rn3s", "sr-n0n3zz"], ["sr-h4rn3s"], ["sr-h4rn3s"]])
        #expect(boards[1]["sr-n0n3zz"] == .notFound)
        #expect(boards.map { $0["sr-h4rn3s"]?.board?.asks.map(\.id) } == [nil, ["ayh1", "vx3g"], ["ayh1", "vx3g", "0rzx"], ["ayh1", "vx3g", "0rzx"]])
        #expect(boards[3]["sr-h4rn3s"]?.board?.asks.first?.reply?.standing == .onItsWay)
    }

    /// Each board is read on its own: one that does not read is unread alone, and the line, and the boards beside it,
    /// read as usual.
    @Test(arguments: [#"{"v":3}"#, Lines.dashboard.replacingOccurrences(of: #""session": {"#, with: #""work": {"#)])
    func aBoardThatDoesNotReadIsUnreadAloneTheLineReadingAsUsual(_ unreadable: String) throws {
        let line = try Board.read(Lines.carrying(["sr-dash02": unreadable, "sr-macapp": Lines.board], on: Lines.watch[0]))

        #expect(line.boards["sr-dash02"] == .unread)
        #expect(line.boards["sr-macapp"]?.board?.asks.map(\.id) == ["k2", "k3", "k1"])
        #expect(line.rows == (try Board.read(Lines.watch[0])).rows)
    }

    @Test func aCarriedBoardIsTheSessionsBoardAsBoardJsonGivesIt() throws {
        let board = try #require(try Board.read(Lines.following[1]).boards["sr-h4rn3s"]?.board)

        #expect(board.project == SessionBoard.Project(key: "harness", name: "Harness"))
        #expect(board.session.id == "sr-h4rn3s")
        #expect(board.session.name == "Follow the boards")
        #expect(board.session.now == ["Following the boards through the watch"])
        #expect(board.parked.map(\.title) == ["Measure the line on a copy of Lee's board"])
        #expect(board.log.map(\.text).contains("The watch hears what the window follows"))
        #expect(board.resolved.isEmpty)
    }

    /// The real CLI's line (`Lines.onItsWork`): Kit's window waiting on a wake, its row first, and SitRep's on three
    /// agents.
    @Test func aWindowOnItsOwnWorkIsItsRowItsSessionsStateAndItsOwnWithWhatItWaitsOnOrWhenItsWakeIsDue() throws {
        let board = try Board.read(Lines.onItsWork)
        let sessions = board.projects.flatMap(\.sessions)

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
        #expect(sessions.map(\.state) == [.onItsWork, .onItsWork])
        #expect(sessions.map(\.doing.kind) == [.onItsWork, .onItsWork])
        #expect(sessions.map(\.doing.line) == board.rows.map(\.newest.first))
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
        watchedEmpty.replacingOccurrences(of: #","boards":{}"#, with: ""),
        watchedEmpty.replacingOccurrences(of: #""boards":{}"#, with: #""changed":[]"#),
        watchedEmpty.replacingOccurrences(of: #""boards":{}"#, with: #""boards":[]"#),
        watched.replacingOccurrences(of: #""is": "yourTurn""#, with: #""is": "napping""#),
        watched.replacingOccurrences(of: #""doing": {"# + "\n" + #"            "is": "permission""#, with: #""doing": {"# + "\n" + #"            "is": "napping""#),
        watched.replacingOccurrences(of: #""doing": {"#, with: #""doings": {"#),
        watched.replacingOccurrences(of: #""section": "yourTurn""#, with: #""section": "napping""#),
        watched.replacingOccurrences(of: #""name": "Plan the tool","# + "\n" + #"      "projectName""#, with: #""projectName""#),
        watched.replacingOccurrences(of: #""projectName": "Terrace","#, with: ""),
        Lines.bySession[0].replacingOccurrences(of: #""lines":[{"key":"turn:sr-v3t7a0""#, with: #""lines":[],"was":[{"key":"turn:sr-v3t7a0""#),
    ])
    func aLineThatIsNotABoardIsUnread(line: String) {
        #expect(throws: Unread.shape) { try Board.read(line) }
    }
}
