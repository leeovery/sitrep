import Foundation
@testable import SitRepCore
import SitRepEdge
import SitRepLines
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

    @Test func eachRowIsASessionInCoresOrderKeyedByItsSession() {
        let sessions = Self.board(Self.heard(.line(watchLine))).sessions

        #expect(sessions.map(\.id) == ["sr-7e68fj", "sr-y4d0qj", "sr-j94s0e", "sr-50f7g8", "sr-aw3bgs", "sr-q7njzv"])
    }

    /// The real CLI's line (`Lines.bySession`): Harness's three asks, the oldest first, each its words and its time;
    /// Switchboard's ask and its window's permission prompt, the command in mono after a space.
    @Test func aRowWithSeveralLinesKeepsEachInCoresOrderWithItsWordsAndItsTime() throws {
        let line = try Board.read(Lines.bySession[0])
        let sessions = Self.board(Self.heard(.line(Lines.bySession[0]))).sessions
        let harness = try #require(sessions.first), switchboard = sessions[1]

        #expect(harness.id == "sr-4g01a7")
        #expect(harness.kind == .needs)
        #expect(harness.lines.map(\.title) == [
            "Approve the first fix batch from the branch review", "Choose how the release notes are grouped",
            "Paste the failing test's output",
        ])
        #expect(harness.lines.map(\.since) == line.rows[0].lines.map { $0.since.timeIntervalSince1970 * 1000 })
        #expect(harness.since == harness.lines[0].since)
        #expect(harness.name == "Finish the Harness modernisation")
        #expect(harness.sub == "Harness")
        #expect(switchboard.lines.map(\.title) == ["Paste the load test's output", "Allow Bash "])
        #expect(switchboard.lines.map(\.code) == [nil, "gh pr create --draft"])
        #expect(sessions.map(\.lines.count) == [3, 2, 1, 1, 1, 1])
    }

    /// The second line: a fourth ask in Harness's session, new on it, which washes its row.
    @Test func aRowHoldingALineNewOnTheBoardIsNewByItsSession() {
        let board = Self.board(Self.heard(.line(Lines.bySession[0]), .line(Lines.bySession[1])))

        #expect(board.new == ["sr-4g01a7"])
        #expect(board.sessions.first?.lines.count == 4)
    }

    @Test func anAskAPermissionPromptAndAQuestionNeedLeeAndTheRestAreYourTurnOrWorking() {
        let sessions = Self.board(Self.heard(.line(watchLine))).sessions

        #expect(sessions.map(\.kind) == [.needs, .needs, .needs, .needs, .turn, .working])
        #expect(sessions.map(\.away) == [false, false, false, true, false, false])
    }

    /// A session a window holds that this Mac does not show is drawn as an away one is, whatever its state, keeping its
    /// section, its words and its place in core's order (stage 8's "The rows").
    @Test func aHeldSessionNotHereIsDrawnAwayKeepingItsStateItsWordsAndItsPlace() {
        let last = Self.heard(.line(watchLine))
        let here = Self.board(last).sessions
        let notHere = PanelBoard(
            last, notHere: ["sr-7e68fj", "sr-aw3bgs", "sr-q7njzv", "sr-gone00"], clock: Self.london
        )

        #expect(notHere.sessions.map(\.away) == [true, false, false, true, true, true])
        #expect(notHere.sessions.map(\.id) == here.map(\.id))
        #expect(notHere.sessions.map(\.kind) == here.map(\.kind))
        #expect(notHere.sessions.map(\.sub) == here.map(\.sub))
        #expect(notHere.sessions.map(\.lines) == here.map(\.lines))
        #expect(notHere.head == Self.board(last).head)
    }

    /// Told again as what this Mac shows changes, nothing on it is new again, so nothing swells or washes twice.
    @Test func aBoardToldAgainHasNothingNewAndIsOtherwiseTheSame() {
        let board = Self.board(Self.heard(.line(Lines.bySession[0]), .line(Lines.bySession[1])))

        #expect(!board.new.isEmpty)
        #expect(board.retold.new.isEmpty)
        #expect(board.retold.sessions == board.sessions)
        #expect(board.retold.head == board.head)
        #expect(board.retold.needsLee == board.needsLee)
    }

    @Test func aWorkingRowLeadsWithItsVerbItsPathInMono() {
        let working = Self.board(Self.heard(.line(watchLine))).sessions[5]

        #expect(working.title == "Editing ")
        #expect(working.code == "app/Report.php")
    }

    /// The real CLI's line: Kit's window waiting on a wake, SitRep's on three agents.
    @Test func aRowOnItsOwnWorkLeadsWithItsVerbThenItsPlainSubjectOrTheWakeItCountsDownTo() {
        let sessions = Self.board(Self.heard(.line(Lines.onItsWork))).sessions

        #expect(sessions.map(\.kind) == [.onItsWork, .onItsWork])
        #expect(sessions.map(\.title) == ["Wakes ", "Waiting on "])
        #expect(sessions.map(\.subject) == [nil, "3 agents"])
        #expect(sessions.map(\.until) == [1_792_670_195_432, nil])
        #expect(sessions.map(\.code) == [nil, nil])
    }

    /// A row needing Lee is its session: its name over its project, its oldest line's time; its line keeps its words,
    /// a prompt's command in mono after a space, for its page.
    @Test func aRowNeedingLeeReadsItsSessionsNameOverItsProject() {
        let prompt = Self.board(Self.heard(.line(watchLine))).sessions[1]

        #expect(prompt.title == "Dashboard memory and snags")
        #expect(prompt.code == nil && prompt.more == nil)
        #expect(prompt.sub == "Switchboard")
        #expect(prompt.since == 1_792_445_500_000)
        #expect(prompt.lines[0].title == "Allow Bash: " && prompt.lines[0].code == "gh pr create")
    }

    /// An away row's line under its name says no window holds it, as core words it.
    @Test func anAwayRowSaysNoWindowHoldsItUnderItsName() {
        let away = Self.board(Self.heard(.line(realLine))).sessions[1]

        #expect(away.title == "Dashboard memory")
        #expect(away.sub == "No window holds it. Carry it on in Claude.")
    }

    /// A question's own "+2" stays on its line, for its page, and shows on no row.
    @Test func aQuestionKeepsCoresWordsForHowManyMoreOnItsLine() {
        let question = Self.board(Self.heard(.line(watchLine))).sessions[2]

        #expect(question.lines[0].title == "Which edge should it start on?")
        #expect(question.lines[0].more == "+2")
        #expect(question.more == nil)
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

    @Test func whatIsNewIsTheRowsHoldingTheLinesNew() {
        #expect(Self.board(Self.heard(.line(watchLine))).new == ["sr-y4d0qj"])
        #expect(Self.board(Self.heard(.line(allClearLine))).new.isEmpty)
    }

    @Test func theRealWatchsFirstLineMapsRowForRow() {
        let board = Self.board(Self.heard(.line(realLine)))

        #expect(board.sessions == [
            Session(
                id: "sr-n0tch1", project: "SitRep", name: "Build the Mac app", letters: "SR", kind: .needs,
                ask: "k1ap", title: "Approve the caption", sub: "SitRep", since: 1_792_452_732_636
            ),
            Session(
                id: "sr-dash02", project: "Switchboard", name: "Dashboard memory", letters: "Sw", kind: .needs,
                away: true, ask: "k2pc", title: "Pick the cache size", sub: "No window holds it. Carry it on in Claude.",
                since: 1_792_451_832_636
            ),
        ])
        #expect(board.head == Head(title: "2 need you", count: "2 sessions"))
        #expect(board.needsLee)
        #expect(board.new.isEmpty)
    }

    @Test func aRowNamesItsProjectAsTheBoardDoesWithCoresLetters() {
        let sessions = Self.board(Self.heard(.line(realLine))).sessions

        #expect(sessions.map(\.project) == ["SitRep", "Switchboard"])
        #expect(sessions.map(\.letters) == ["SR", "Sw"])
    }

    /// A row names its project and its session by core's own fields, whatever projects the line lists.
    @Test func aRowNamesItsProjectAndSessionByItsOwnFields() {
        let sessions = Self.board(Self.heard(.line(watchLine))).sessions

        #expect(sessions.map(\.project) == ["Terrace", "Switchboard", "Goosemates", "Kit", "SitRep", "DocMan"])
        #expect(sessions.map(\.name) == [
            "Plan the tool", "Dashboard memory and snags", "Settle the older open questions", "The bootstrap",
            "Build the Mac app", "Fix inverted exception reporting",
        ])
        #expect(sessions.allSatisfy { $0.letters == "Pr" })
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

    @Test func goneStaleItsNewRowsAreNotNewAgain() {
        let current = Self.board(Self.heard(.line(watchLine)))
        let stale = Self.board(Self.heard(.line(watchLine), .exited(.status(1), stderr: "")))
        let staleAgain = Self.board(
            Self.heard(.line(watchLine), .exited(.status(1), stderr: ""), .exited(.status(1), stderr: ""))
        )

        #expect(!current.new.isEmpty)
        #expect(stale.new.isEmpty)
        #expect(staleAgain.new.isEmpty)
        #expect(stale.sessions == current.sessions)
    }

    @Test func withNoWatchToRunItsHeadSaysWhy() {
        let board = PanelBoard(unrun: "This SitRep names no plugin to run: build it with app/build.")

        #expect(board.head == Head(title: "This SitRep names no plugin to run: build it with app/build.", count: ""))
        #expect(board.sessions.isEmpty)
        #expect(!board.needsLee)
    }

    @Test func aLineReadAgainIsCurrentAgain() {
        let back = Self.heard(.line(watchLine), .exited(.status(1), stderr: ""), .line(watchLine))

        #expect(Self.board(back).head.count == "6 sessions")
        #expect(Self.board(back).asOf == nil)
    }

    /// The strip has no head: before any board, its notch at rest says what the panel's head says.
    @Test func beforeAnyBoardTheStripSaysWhatThePanelsHeadSays() {
        #expect(Self.board(LastBoard()).unread == "Looking for sessions…")
        #expect(Self.board(Self.heard(.unstartable("no such file"))).unread == "SitRep can't read the board")
        #expect(Self.board(Self.heard(.line(watchLine))).unread == nil)
    }

    /// While the board is stale the strip says as of when, as the panel's head does; while it is current, nothing.
    @Test func withWatchStoppedTheStripSaysAsOfWhen() {
        let stopped = Self.heard(.line(watchLine), .exited(.status(1), stderr: ""))

        #expect(Self.board(stopped).asOf == "as of 12:01")
        #expect(Self.board(stopped).unread == nil)
        #expect(Self.board(Self.heard(.line(watchLine))).asOf == nil)
    }
}
