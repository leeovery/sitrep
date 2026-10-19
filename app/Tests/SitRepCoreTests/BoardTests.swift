import Foundation
@testable import SitRepCore
import Testing

struct BoardTests {
    private static func at(_ milliseconds: Double) -> Date {
        Date(timeIntervalSince1970: milliseconds / 1000)
    }

    @Test func aLineGivesTheBoardAtItsTimeWithTheCLIsVersionAndItsHead() throws {
        let board = try Board.read(watched)

        #expect(board.at == Self.at(1_792_445_574_706))
        #expect(board.version == "0.1.0")
        #expect(board.head.needYou == 2)
        #expect(board.head.sessions == 3)
        #expect(!board.head.isAllClear)
    }

    @Test func theRowsComeInTheLinesOrderEachWhatItIsAndOfAnAskOrAWindow() throws {
        let rows = try Board.read(watched).rows

        #expect(rows.map(\.id) == [
            "ask:sr-7e68fj:k1hs",
            "stop:sr-y4d0qj:6c847b5b-722d-4343-88e0-42ece4662e7d:1792445500000",
            "turn:sr-aw3bgs",
        ])
        #expect(rows.map(\.kind) == [.ask, .permission, .yourTurn])
        #expect(rows.map(\.ask) == ["k1hs", nil, nil])
        #expect(rows.map(\.writer) == [nil, "6c847b5b-722d-4343-88e0-42ece4662e7d", "408a755f-ed3a-4ee1-9cc0-c0208cf3e03b"])
    }

    @Test func aRowsFirstLineComesInItsPartsThenItsSecondAndItsTime() throws {
        let stop = try Board.read(watched).rows[1]

        #expect(stop.first == Board.Row.Line(lead: "Allow Bash:", mono: "gh pr create", more: nil))
        #expect(stop.second == "Switchboard · Dashboard memory and snags")
        #expect(stop.since == Self.at(1_792_445_500_000))
        #expect(stop.letters == "Sw")
        #expect(stop.project == "switchboard-7a75d7ba")
        #expect(stop.session == "sr-y4d0qj")
        #expect(!stop.isAway)
    }

    @Test func theProjectsHoldTheirSessionsEachWithItsStateAndItsAsks() throws {
        let projects = try Board.read(watched).projects

        #expect(projects.map(\.id) == ["terrace", "switchboard-7a75d7ba", "code-84dbac88"])
        #expect(projects.map(\.directory) == [nil, "/Users/leeovery/Code/switchboard", "/Users/leeovery/Code/sitrep"])

        let terrace = try #require(projects.first?.sessions.first)

        #expect(terrace.state == .needsYou)
        #expect(terrace.next == nil)
        #expect(terrace.since == Self.at(1_791_991_983_206))
        #expect(terrace.asks.map(\.id) == ["k1hs"])
        #expect(terrace.asks.first?.wants == .yes)
        #expect(terrace.asks.first?.yes == "Approve")
        #expect(terrace.asks.first?.where == "In the chat: decision 3, what an approval binds to")
        #expect(terrace.asks.first?.state == .waiting)
        #expect(projects.last?.sessions.first?.state == .yourTurn)
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
            since: Self.at(1_792_445_500_000),
            tool: .init(name: "Bash", subject: "gh pr create"),
            question: nil
        ))
    }

    @Test func aLineSaysWhatIsNewOnItAndWhichSessionsChanged() throws {
        let board = try Board.read(watched)

        #expect(board.new == ["stop:sr-y4d0qj:6c847b5b-722d-4343-88e0-42ece4662e7d:1792445500000"])
        #expect(board.changed == ["sr-y4d0qj"])
    }

    @Test func anEmptyBoardIsAllClear() throws {
        let board = try Board.read(watchedEmpty)

        #expect(board.head.isAllClear)
        #expect(board.rows.isEmpty)
    }

    @Test func aLineOfAnotherVersionIsNamedAsSuchWhateverItsShape() {
        #expect(throws: Unread.version(given: 2, read: 1)) { try Board.read(#"{"v": 2, "feed": {}}"#) }
    }

    @Test(arguments: [
        "",
        "{\"v\":1,\"at\":17924455",
        #"{"head": {"needYou": 0, "sessions": 0}}"#,
        watchedEmpty.replacingOccurrences(of: #""windows":[],"#, with: ""),
        watched.replacingOccurrences(of: #""is": "yourTurn""#, with: #""is": "napping""#),
    ])
    func aLineThatIsNotABoardIsUnread(line: String) {
        #expect(throws: Unread.shape) { try Board.read(line) }
    }
}
