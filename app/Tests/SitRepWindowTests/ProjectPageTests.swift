import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// A project's page, as A3 revised draws it: its counts, each a part left out where it is none; its sessions, each
/// with where it stands and "not on screen" where the last look says no terminal shows it; the lines waiting on Lee
/// across them in Needs you's order; a card per session in Now, its time from its newest status line; each session's
/// three newest log lines; "N parked" only where it parked something; Now and Log as many across as fit; and its
/// sessions held in their order under the pointer.
struct ProjectPageTests {
    /// The window opened on the line given, `watch`'s first unless another, then the project's page, its line carrying
    /// the boards given.
    private static func page(
        _ project: String, on line: Heard = line(0), boards: [String: String?] = [:], in run: WindowRun = opened()
    ) throws -> ProjectPage {
        run.click(.project(project))
        take(boards, in: run, on: line)
        return try #require(run.page(at: printedAt).project)
    }

    private static func standing(_ page: ProjectPage) -> [[String]] {
        page.sessions.map { $0.standing.parts(at: printedAt) }
    }

    // MARK: Its counts

    @Test func itsCountsSayItsSessionsWhatWaitsOnLeeAndWhatItParked() throws {
        let page = try Self.page("sitrep")

        #expect(page.counts == ["1 session", "3 waiting on you", "1 parked"])
        #expect(Spoken.counts(page) == "1 session, 3 waiting on you, 1 parked")
    }

    @Test func aCountThatIsNoneIsLeftOut() throws {
        #expect(try Self.page("switchboard").counts == ["2 sessions", "2 waiting on you"])
        #expect(try Self.page("kit").counts == ["1 session"])
    }

    /// Dashboard redesign stopped on a prompt, an ask waiting: the header's two waiting on you are its row's stop and
    /// its ask, as Waiting on you lists them.
    @Test func aStopAndItsAsksAreWhatTheHeaderCounts() throws {
        let page = try Self.page("switchboard")

        #expect(page.waitingCount == 2 && page.waitingBadge == 2)
        #expect(page.sessions[0].standing == .waits(stop: .permission, asks: 1))
        #expect(page.waiting.map(\.line.ask) == [nil, "k1"])
    }

    // MARK: Sessions

    /// Switchboard's Dashboard redesign, stopped on a permission prompt with a words ask waiting; Request ledger on
    /// Lee's turn; the Mac app, working, three asks waiting.
    @Test func whatWaitsOnLeeLeadsWhereASessionStandsAStopFirst() throws {
        #expect(try Self.standing(Self.page("switchboard")) == [["Stopped on a prompt", "1 ask waiting"], ["Your turn"]])
        #expect(try Self.standing(Self.page("sitrep")) == [["3 asks waiting"]])
    }

    @Test func aWindowStoppedOnAQuestionSaysSo() throws {
        let line = line(with: "sr-dash02", doing: .question)

        #expect(try Self.standing(Self.page("switchboard", on: line, in: opened(on: line)))[0] == ["Stopped on a question", "1 ask waiting"])
    }

    /// With nothing waiting on Lee, its window's line: working, its verb and what it acts on; on its own work, what it
    /// waits on.
    @Test func withNothingWaitingASessionSaysWhatItsWindowIsDoing() throws {
        let working = line(with: "sr-rq7dgr", doing: .working)
        let ledger = try Self.page("switchboard", on: working, in: opened(on: working)).sessions[1]
        let onItsWork = Heard.line(Lines.onItsWork)
        let macApp = try Self.page("sitrep", on: onItsWork, in: opened(on: onItsWork)).sessions[0]

        #expect(ledger.standing == .doing(.working, Board.Row.Words(lead: "Drawing the ledger schema", mono: nil, more: nil)))
        #expect(macApp.standing.parts(at: printedAt) == ["Waiting on 3 agents"])
        #expect(macApp.mark == .onItsWork)
    }

    /// Goosemates' session, which no window holds, its ask waiting: the away ring; Kit's, with nothing: the away mark,
    /// and says no window holds it.
    @Test func aSessionNoWindowHoldsIsAwayItsAsksStillLeading() throws {
        let goosemates = try Self.page("goosemates").sessions[0]
        let kit = try Self.page("kit").sessions[0]

        #expect(goosemates.isAway && kit.isAway)
        #expect([goosemates.mark, kit.mark] == [.awayAsk, .away])
        #expect(goosemates.standing.parts(at: printedAt) == ["1 ask waiting"])
        #expect(kit.standing.parts(at: printedAt) == ["No window holds it"])
    }

    @Test func aSessionNoTerminalShowsIsNotOnScreen() throws {
        let run = opened()

        Self.look(at: Self.switchboardScreen, in: run)

        let page = try Self.page("switchboard", in: run)

        #expect(page.sessions.map(\.isOffScreen) == [true, false])
        #expect(page.waiting.map(\.isOffScreen) == [true, true])
        #expect(Spoken.session(page.sessions[0], at: printedAt) == "Dashboard redesign, Stopped on a prompt, 1 ask waiting, not on screen, 2 hours")
        #expect(Spoken.session(page.sessions[1], at: printedAt) == "Request ledger, Your turn, 12 minutes")
    }

    /// Goosemates' session, which no window holds, read as on no terminal: no terminal could show it, so it is away,
    /// not "not on screen".
    @Test func anAwaySessionIsNeverNotOnScreen() throws {
        let run = opened()

        Self.look(at: Lines.screen.replacingOccurrences(of: "sr-n0pane", with: "sr-gs7kq2"), in: run)

        let page = try Self.page("goosemates", in: run)

        #expect(run.onScreen(of: "sr-gs7kq2") == .off)
        #expect(page.sessions.map(\.isOffScreen) == [false])
        #expect(page.waiting.map(\.isOffScreen) == [false])
    }

    /// Unknown, where tmux gave no answer, or with no look yet, says nothing of the screen.
    @Test func onlyALookSayingOffIsNotOnScreen() throws {
        let unanswered = opened()

        Self.look(at: Self.switchboardUnanswered, in: unanswered)
        #expect(try Self.page("switchboard", in: unanswered).sessions.map(\.isOffScreen) == [false, false])
        #expect(try Self.page("switchboard").sessions.map(\.isOffScreen) == [false, false])
    }

    /// An away session with an ask reads "away" before where it stands, as its dimmed row shows it.
    @Test func voiceOverReadsAnAwaySessionWithAnAskAsAway() throws {
        let goosemates = try Self.page("goosemates").sessions[0]

        #expect(Spoken.session(goosemates, at: printedAt) == "Settle the older open questions, away, 1 ask waiting, 1 day")
    }

    /// With nothing waiting on Lee, a wake its window waits on counts down after the lead, and a command or a path
    /// follows it.
    @Test func aWindowsLineCountsAWakeDownAndSaysWhatItActsOn() throws {
        let onItsWork = Heard.line(Lines.onItsWork)
        let kit = try Self.page("kit", on: onItsWork, in: opened(on: onItsWork)).sessions[0]
        let writing = ProjectPage.Standing.doing(.working, Board.Row.Words(lead: "Writing", mono: ".scratch/step-back.md", more: nil))

        #expect(kit.standing.parts(at: Date(timeIntervalSince1970: 1_792_669_295.432)) == ["Wakes in 15m"])
        #expect(writing.parts(at: printedAt) == ["Writing .scratch/step-back.md"])
    }

    // MARK: Holding the page

    /// Request ledger moving before Dashboard redesign while the pointer is over the page: Sessions, and Now and Log
    /// with them, keep the order they showed in, and take the board's a second after the pointer leaves.
    @Test func underThePointerTheSessionsKeepTheirOrder() throws {
        let run = opened()
        let left = printedAt.addingTimeInterval(3)
        let order = { try #require(run.page(at: left).project).sessions.map(\.id) }

        _ = try Self.page("switchboard", in: run)
        overThePage(run)
        take([:], in: run, on: .line(Self.ledgerFirst))
        #expect(try order() == ["sr-dash02", "sr-rq7dgr"])

        run.pointer(overPage: false, from: pageRegion, at: left)
        #expect(try order() == ["sr-dash02", "sr-rq7dgr"])
        run.settle(at: left.addingTimeInterval(1))
        #expect(try order() == ["sr-rq7dgr", "sr-dash02"])
    }

    /// `watch`'s first line with Switchboard's sessions the other way round, as a change in their states would order
    /// them.
    private static let ledgerFirst = edited(Lines.watch[0]) { board in
        board["projects"] = (board["projects"] as! [[String: Any]]).map { project in
            guard project["key"] as? String == "switchboard" else {
                return project
            }

            return project.merging(["sessions": Array((project["sessions"] as! [[String: Any]]).reversed())]) { $1 }
        }
    }

    // MARK: Waiting on you

    @Test func waitingOnYouIsALinePerAskAndStopTheNewestFirst() throws {
        let page = try Self.page("switchboard")

        #expect(page.waiting.map(\.id) == ["stop:sr-dash02:w2:1792486361000", "ask:sr-dash02:k1"])
        #expect(page.waiting.map(\.sessionName) == ["Dashboard redesign", "Dashboard redesign"])
        #expect(page.waitingCount == 2)
        #expect(try Self.page("sitrep").waiting.map(\.line.ask) == ["k1", "k3", "k2"])
    }

    /// Lines of sessions a window holds before those of sessions none does, the newest first among each, as Needs you
    /// lists the same lines, those of another project left out.
    @Test func waitingOnYouIsInNeedsYousOrder() throws {
        let harbor = [
            Built(id: "s1", project: "harbor", waiting: [30, 5]), Built(id: "s2", project: "harbor", isAway: true, waiting: [1]),
            Built(id: "s3", project: "harbor", waiting: [10]), Built(id: "s4", project: "dock", waiting: [2]),
        ]
        let run = WindowRun(wall: { printedAt })

        run.show(heard(Built.printed(harbor)), at: printedAt, reducesMotion: false)
        run.open()

        let needsYou = try #require(run.list(at: printedAt)).rows.compactMap(\.lineRow).filter { $0.session.project == "Harbor" }

        run.click(.project("harbor"))

        let waiting = try #require(run.page(at: printedAt).project).waiting

        #expect(waiting.map(\.id) == [harbor[0].line(1), harbor[2].line(0), harbor[0].line(0), harbor[1].line(0)])
        #expect(waiting.map(\.id) == needsYou.map(\.id))
        #expect(waiting.map(\.mark) == [.needs, .needs, .needs, .awayAsk])
    }

    @Test func aLineSaysItsWordsItsSessionAndHowLongItHasWaited() throws {
        let run = opened()

        Self.look(at: Self.switchboardScreen, in: run)

        let stop = try #require(Self.page("switchboard", in: run).waiting.first)

        #expect(Spoken.waiting(stop, at: printedAt) == "Allow Bash gh pr create --draft --base main, Dashboard redesign, not on screen, 1 minute")
    }

    /// An ask new on a followed session's board washes as it comes, as its card would.
    @Test func anAskNewOnTheBoardWashesItsLine() throws {
        let run = opened()

        _ = try Self.page("sitrep", boards: ["sr-macapp": Lines.board], in: run)
        take(["sr-macapp": deliveredAndNew], in: run, on: .line(Self.k4Asked), at: printedAt)

        let waiting = try #require(run.page(at: printedAt).project).waiting

        #expect(waiting.map(\.line.ask) == ["k4", "k2"])
        #expect(waiting.map(\.line.washed) == [printedAt, nil])
    }

    /// The Mac app's row with k4 asked, newest, beside k2, as `watch`'s third line has it.
    private static let k4Asked = edited(Lines.watch[2]) { board in
        board["rows"] = (board["rows"] as! [[String: Any]]).map { row in
            guard row["session"] as? String == "sr-macapp" else {
                return row
            }

            let lines = row["lines"] as! [[String: Any]]
            let asked = lines[0].merging(["key": "ask:sr-macapp:k4", "ask": "k4", "since": 1_792_486_400_000]) { $1 }

            return row.merging(["lines": [asked] + lines]) { $1 }
        }
    }

    // MARK: Now

    /// Dashboard redesign's status changed as its board's newest status line says; before a board of it comes, as the
    /// session last changed.
    @Test func nowsTimeIsTheNewestStatusLineElseWhenTheSessionChanged() throws {
        let run = opened()
        let before = try Self.page("switchboard", in: run).sessions[0]
        let after = try Self.page("switchboard", boards: ["sr-dash02": Lines.dashboard], in: run).sessions[0]

        #expect(before.updated == Date(timeIntervalSince1970: 1_792_476_221))
        #expect(after.updated == Date(timeIntervalSince1970: 1_792_475_621))
        #expect(after.now == "Drawing Usage, round 2")
        #expect(after.next == "Usage, round 3")
    }

    /// Its name, "away" where no window holds it, its now line, what comes next, and when its status changed.
    @Test func voiceOverReadsANowCardAsItShows() throws {
        let goosemates = try Self.page("goosemates").sessions[0]

        #expect(Spoken.nowCard(goosemates, at: printedAt)
            == "Settle the older open questions, away, Waiting on your call on the invite flow, next close the questions you drop, updated 1 day ago")
    }

    @Test func nowsTimeSaysHowLongAgo() {
        #expect(Words.ago(printedAt, at: printedAt) == "just now")
        #expect(Words.ago(printedAt, at: printedAt.addingTimeInterval(3600)) == "1h ago")
    }

    // MARK: Log

    @Test func theLogIsEachSessionsThreeNewestLines() throws {
        let page = try Self.page("sitrep", boards: ["sr-macapp": Self.fourLines])

        #expect(page.sessions[0].log.map(\.text) == ["Round 3 sent for a look", "The strip written into DESIGN.md", "PR #4 merged"])
        #expect(page.hasLog)
        #expect(Spoken.log(page.sessions[0].log[0], at: printedAt) == "Round 3 sent for a look, 15 hours")
    }

    /// A group per session, in the sessions' order, so each sits under its card; none shows before a board comes.
    @Test func theLogHasAGroupPerSessionAndShowsOnceABoardHasALine() throws {
        let run = opened()

        #expect(try !Self.page("switchboard", in: run).hasLog)

        let page = try Self.page("switchboard", boards: ["sr-dash02": Lines.dashboard, "sr-rq7dgr": Lines.ledger], in: run)

        #expect(page.sessions.map { $0.log.map(\.text) } == [["Status: now drawing Usage, round 2"], ["Status: now drawing the ledger schema"]])
    }

    /// The Mac app's board with a fourth line, newer than the rest.
    private static let fourLines = edited(Lines.board) { board in
        let log = board["log"] as! [[String: Any]]

        board["log"] = [log[0].merging(["id": "n9", "text": "Round 3 sent for a look", "at": 1_792_430_000_000]) { $1 }] + log
    }

    // MARK: Parked

    @Test func nParkedShowsOnlyWhereItParkedSomething() throws {
        #expect(try Self.page("sitrep").parkedRow == "1 parked")
        #expect(try Self.page("switchboard").parkedRow == nil)
    }

    // MARK: The grid

    /// Three across at the window's 1100, its page 776 inside; two at its narrowest, 940, its page 616; one under 492;
    /// never more than three.
    @Test func nowAndLogGoAsManyAcrossAsFitThreeAtMost() {
        #expect(ProjectPage.columns(across: 776) == 3)
        #expect(ProjectPage.columns(across: 744) == 3)
        #expect(ProjectPage.columns(across: 743) == 2)
        #expect(ProjectPage.columns(across: 616) == 2)
        #expect(ProjectPage.columns(across: 491) == 1)
        #expect(ProjectPage.columns(across: 100) == 1)
        #expect(ProjectPage.columns(across: 2000) == 3)
    }

    // MARK: The screen

    /// The real CLI's reading, its sessions renamed: Dashboard redesign on no terminal, Request ledger on one.
    private static let switchboardScreen = renamed(Lines.screen)
    /// The same with tmux unanswered, so both unknown.
    private static let switchboardUnanswered = renamed(Lines.screenUnanswered)

    private static func renamed(_ reading: String) -> String {
        reading.replacingOccurrences(of: "sr-0nscrn", with: "sr-rq7dgr").replacingOccurrences(of: "sr-n0pane", with: "sr-dash02")
    }

    /// The window shows, and looks at the screen, which gives this reading.
    private static func look(at reading: String, in run: WindowRun) {
        run.window(isVisible: true)
        if let look = run.looksAtScreen(at: printedAt) {
            _ = run.looked(.read(try! ScreenReading.read(reading)), of: look, at: printedAt)
        }
    }
}
