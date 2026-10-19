import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import Testing

struct PanelBoardTests {
    private static let london = Date.FormatStyle(
        date: .omitted, time: .shortened, locale: Locale(identifier: "en_GB"),
        timeZone: TimeZone(identifier: "Europe/London")!
    )

    /// Noon in London on 19 October 2026, hours before the fixture's line was printed.
    private static let noon = Date(timeIntervalSince1970: 1_792_407_600)

    /// What `watch` said, heard a minute apart from noon.
    private static func heard(_ said: Heard...) -> LastBoard {
        var last = LastBoard()

        for (minute, heard) in said.enumerated() {
            _ = last.hear(heard, at: noon.addingTimeInterval(Double(minute) * 60))
        }

        return last
    }

    private static func board(_ last: LastBoard) -> PanelBoard {
        PanelBoard(last, clock: london)
    }

    @Test func eachRowIsASessionInCoresOrderKeyedByTheRowsKey() {
        let sessions = Self.board(Self.heard(.line(watchLine))).sessions

        #expect(sessions.map(\.id) == [
            "ask:sr-7e68fj:k1hs", "stop:sr-y4d0qj:w1:1792445500000", "stop:sr-j94s0e:w2:1792445400000",
            "ask:sr-50f7g8:a2", "turn:sr-aw3bgs", "work:sr-q7njzv",
        ])
    }

    @Test func anAskAPermissionPromptAndAQuestionNeedLeeAndTheRestAreYourTurnOrWorking() {
        let sessions = Self.board(Self.heard(.line(watchLine))).sessions

        #expect(sessions.map(\.kind) == [.needs, .needs, .needs, .needs, .turn, .working])
        #expect(sessions.map(\.away) == [false, false, false, true, false, false])
    }

    @Test func aWorkingRowLeadsWithItsVerbItsPathInMono() {
        let working = Self.board(Self.heard(.line(watchLine))).sessions[5]

        #expect(working.title == "Editing ")
        #expect(working.code == "app/Report.php")
    }

    @Test func aRowReadsItsFirstLineItsSubjectInMonoAfterASpaceAndItsSecond() {
        let prompt = Self.board(Self.heard(.line(watchLine))).sessions[1]

        #expect(prompt.title == "Allow Bash: ")
        #expect(prompt.code == "gh pr create")
        #expect(prompt.more == nil)
        #expect(prompt.sub == "Switchboard · Dashboard memory and snags")
        #expect(prompt.since == 1_792_445_500_000)
    }

    @Test func aQuestionKeepsCoresWordsForHowManyMore() {
        let question = Self.board(Self.heard(.line(watchLine))).sessions[2]

        #expect(question.title == "Which edge should it start on?")
        #expect(question.code == nil)
        #expect(question.more == "+2")
    }

    @Test func theHeadIsCoresCounts() {
        let board = Self.board(Self.heard(.line(watchLine)))

        #expect(board.head == Head(title: "4 need you", count: "6 sessions"))
        #expect(board.needsLee)
    }

    @Test func nothingNeedingLeeIsAllClear() {
        let board = Self.board(Self.heard(.line(allClearLine)))

        #expect(board.head == Head(title: "All clear", count: "1 session"))
        #expect(!board.needsLee)
    }

    @Test func whatIsNewIsTheLinesNew() {
        #expect(Self.board(Self.heard(.line(watchLine))).new == ["stop:sr-y4d0qj:w1:1792445500000"])
        #expect(Self.board(Self.heard(.line(allClearLine))).new.isEmpty)
    }

    @Test func aRowJumpsToItsSessionAndAnAwayOneNowhere() {
        let board = Self.board(Self.heard(.line(watchLine)))

        #expect(board.sessions.map(board.jump) == [
            "sr-7e68fj", "sr-y4d0qj", "sr-j94s0e", nil, "sr-aw3bgs", "sr-q7njzv",
        ])
    }

    @Test func beforeTheFirstLineThePanelIsLookingWithNothingNeedingLee() {
        let board = Self.board(LastBoard())

        #expect(board.sessions.isEmpty)
        #expect(board.head.title == "Looking for sessions…")
        #expect(!board.needsLee)
    }

    @Test func withWatchStoppedBeforeAnyLineThePanelSaysItCantReadTheBoard() {
        let board = Self.board(Self.heard(.unstartable("no such file")))

        #expect(board.sessions.isEmpty)
        #expect(board.head.title == "SitRep can't read the board")
    }

    /// The menu's "4 need you · as of 12:04": the panel's head keeps its count of what needs Lee, and says in the
    /// count's place when the board was last known current, which is when `watch` was heard ending, not when it last
    /// printed (the line's own time is 22:32).
    @Test func withWatchStoppedTheLastBoardStaysItsHeadSayingAsOfWhen() {
        let stopped = Self.heard(
            .line(watchLine), .line(watchLine), .exited(.status(1), stderr: "sitrep: the state folder went away")
        )

        let board = Self.board(stopped)

        #expect(board.sessions == Self.board(Self.heard(.line(watchLine))).sessions)
        #expect(board.head == Head(title: "4 need you", count: "as of 12:02"))
        #expect(board.needsLee)
    }

    @Test func aLineReadAgainIsCurrentAgain() {
        let back = Self.heard(.line(watchLine), .exited(.status(1), stderr: ""), .line(watchLine))

        #expect(Self.board(back).head.count == "6 sessions")
    }
}
