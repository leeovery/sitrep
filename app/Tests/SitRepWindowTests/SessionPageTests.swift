import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// A session's page, from what the real CLI printed: beside a place's list, the detail, led by the picked line's card;
/// filling the window, its meta line and every ask's card; on both what its window is doing, Now, and What happened.
struct SessionPageTests {
    private static func page(_ run: WindowRun, at time: Date = printedAt) throws -> SessionPage {
        try #require(run.page(at: time).session)
    }

    private static func card(_ ask: String, _ run: WindowRun, at time: Date = printedAt) throws -> Card {
        try #require(page(run, at: time).asks.first { $0.id.ask == ask })
    }

    private static func picked(_ session: String, boards: [String: String?]) -> WindowRun {
        let run = opened(boards: boards)

        run.land(session)
        take(boards, in: run)
        return run
    }

    /// A session's page filling the window, pushed from its project's, on the line given, `watch`'s first unless
    /// another, which then carries the boards given.
    private static func full(
        _ session: String, on line: Heard = line(0), boards: [String: String?] = ["sr-macapp": Lines.board]
    ) -> WindowRun {
        let run = opened(on: line, boards: [:])

        run.go(to: .session(session, from: .project("sitrep")), by: .projectSession)
        take(boards, in: run, on: line)
        return run
    }

    /// The card leading the detail, where an ask's leads it.
    private static func leading(_ run: WindowRun) throws -> Card {
        guard case let .ask(card) = try page(run).lead else {
            throw Unled()
        }
        return card
    }

    private struct Unled: Error {}

    /// The window's last look at the screen, as `sitrep screen` read this session, in the app given, as the CLI says
    /// it since it said one, or as one before said it, with none.
    private static func looked(_ run: WindowRun, at session: String, is state: OnScreen, in app: String? = nil) throws {
        let app = app.map { #","app":"\#($0)""# } ?? ""
        let reading = #"{"v":1,"sessions":[{"id":"\#(session)","is":"\#(state.rawValue)"\#(app)}],"unanswered":[]}"#

        run.window(isVisible: true)

        let look = try #require(run.looksAtScreen(at: printedAt))

        _ = run.looked(.read(try ScreenReading.read(reading)), of: look, at: printedAt)
    }

    /// `watch`'s first line, the Mac app started at this time.
    private static func started(_ time: Date) -> Heard {
        .line(edited(Lines.watch[0]) { board in
            board["projects"] = (board["projects"] as! [[String: Any]]).map { project in
                var project = project

                project["sessions"] = (project["sessions"] as! [[String: Any]]).map { session in
                    session["id"] as? String == "sr-macapp"
                        ? session.merging(["created": (time.timeIntervalSince1970 * 1000).rounded()]) { $1 } : session
                }
                return project
            }
        })
    }

    /// The Mac app's board with its log as given, each line so many minutes before the board was seeded.
    private static func logged(_ ages: [Double], kind: String = "note") -> String {
        edited(Lines.board) { board in
            board["log"] = ages.enumerated().map { place, age in
                [
                    "kind": kind, "id": "l\(place)", "text": "Line \(place)", "detail": [String](), "ref": NSNull(),
                    "by": "w1", "at": (minutes(before: age).timeIntervalSince1970 * 1000).rounded(),
                ] as [String: Any]
            }
        }
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // MARK: The head of the page

    @Test func itSaysItsProjectAndItsNameAndOffersTheJumpWhileAWindowHoldsIt() throws {
        let page = try Self.page(opened())

        #expect(page.projectKey == "sitrep")
        #expect(page.projectName == "SitRep")
        #expect(page.name == "The Mac app")
        #expect(page.jumps)
        #expect(page.finish == nil)
    }

    @Test func theDoingLineIsWhatWatchSaysTheSessionIsDoingThoughNoRowOfItsWindowsShows() throws {
        let page = try Self.page(opened())

        #expect(page.doing == doing(.working, "Writing", mono: ".scratch/step-back.md", since: minutes(before: 6)))
        #expect(page.doingLine == .line)
    }

    @Test func yourTurnSaysWhatItsRowSays() throws {
        let page = try Self.page(Self.picked("sr-rq7dgr", boards: [:]))

        #expect(page.doing == doing(.yourTurn, "Drawing the ledger schema", since: minutes(before: 12)))
    }

    @Test func anAwaySessionHasNoJumpAndOffersToFinishIt() throws {
        let page = try Self.page(Self.picked("sr-gs7kq2", boards: ["sr-gs7kq2": Lines.away]))

        #expect(page.doing == doing(.away, "No window holds it. Carry it on in Claude.", since: minutes(before: 1440)))
        #expect(!page.jumps)
        #expect(page.finish == .offered)
    }

    /// With asks waiting while no window holds it, its mark beside what it is doing is the away ring, as its row's and
    /// its cards'; held, what it is doing's.
    @Test func anAwaySessionWithAsksWaitingIsMarkedWithTheAwayRing() throws {
        let away = try Self.page(Self.picked("sr-gs7kq2", boards: ["sr-gs7kq2": Lines.away]))
        let held = try Self.page(opened())

        try #require(away.waiting > 0 && held.waiting > 0)
        #expect(away.mark == .awayAsk)
        #expect(held.mark == held.doing.mark && held.mark != .awayAsk)
    }

    @Test func beforeItsBoardComesItSaysSoAndShowsNoAsksAndNothingHappened() throws {
        let page = try Self.page(opened(boards: [:]))

        #expect(!page.hasBoard)
        #expect(page.failure == nil)
        #expect(page.asks.isEmpty)
        #expect(page.happened.isEmpty)
    }

    @Test func itsJumpItsFinishAndItsButtonsFollowWhatWatchSaysItIsDoingTheOneFactOfAway() throws {
        let away = try Self.page(opened(on: line(with: "sr-macapp", doing: .away)))

        #expect(!away.jumps)
        #expect(away.finish == .offered)
        #expect(away.asks.first { $0.id.ask == "k1" }?.buttons == [.yes("Approve"), .ignore, .snooze])

        let held = line(with: "sr-gs7kq2", doing: .yourTurn)
        let run = opened(on: held)

        run.land("sr-gs7kq2")
        take(["sr-gs7kq2": Lines.away], in: run, on: held)

        let page = try Self.page(run)

        #expect(page.jumps)
        #expect(page.finish == nil)
        #expect(page.asks.first?.buttons.contains(.inClaude(.comment)) == true)
        #expect(run.list(at: printedAt)?.rows.first { $0.session == "sr-gs7kq2" }?.row.isAway == false)
    }

    // MARK: The lead, beside the list

    /// Opened on Needs you, the Mac app's newest line picked: its ask's card leads the detail, alone, as the session's
    /// other asks are rows of their own.
    @Test func inNeedsYouThePickedAsksCardLeadsTheDetailAlone() throws {
        let run = opened()
        let page = try Self.page(run)

        #expect(run.location.picked?.pick == macAppK1)
        #expect(page.mode == .detail)
        #expect(try Self.leading(run).id == AskAddress(session: "sr-macapp", ask: "k1"))
        #expect(page.cards.isEmpty)
        #expect(page.asks.map(\.id.ask) == ["k1", "k3", "k2"])
    }

    @Test func anotherLineOfTheSessionPickedLeadsWithItsCard() throws {
        let run = opened()

        run.pickInList(.line("ask:sr-macapp:k3"), at: printedAt)
        #expect(try Self.leading(run).id.ask == "k3")
        #expect(try Self.leading(run).needs == "the command's output")
    }

    /// Dashboard redesign's window stopped on Lee, as its row's line and what it is doing both say it.
    private static let dashStop = "stop:sr-dash02:w2:1792486361000"
    private static let allowBash = SessionPage.Stop(
        doing(.permission, "Allow Bash", mono: "gh pr create --draft --base main", since: minutes(before: 1))
    )!

    /// A window's stop picked leads as its line says it, and the line for what its window is doing, which would say
    /// the stop again, gives way to it.
    @Test func aStopPickedLeadsAsItsLineSaysItInPlaceOfTheDoingLine() throws {
        let run = opened()

        run.pickInList(.line(Self.dashStop), at: printedAt)

        let page = try Self.page(run)

        #expect(page.lead == .stop(Self.allowBash))
        #expect(page.doingLine == SessionPage.DoingLine.none)
    }

    /// Lee answered the stop picked in its terminal and the window stopped again: the new stop is another line, so
    /// the pick leads nothing, and the stop stands in the doing line's place as its card, its jump with it. Gone with
    /// no stop after it, nothing leads.
    @Test func aStopThatFollowsTheOnePickedStandsInTheDoingLinesPlace() throws {
        let run = opened()
        let restopped = Lines.watch[0].replacingOccurrences(of: Self.dashStop, with: "stop:sr-dash02:w2:1792486400000")

        run.pickInList(.line(Self.dashStop), at: printedAt)
        run.show(heard(.line(restopped)), at: printedAt, reducesMotion: false)

        let page = try Self.page(run)

        try #require(restopped != Lines.watch[0])
        #expect(page.lead == nil)
        #expect(page.doingLine == .stop(Self.allowBash))
        run.show(heard(answered("sr-dash02")), at: printedAt, reducesMotion: false)
        #expect(try Self.page(run).lead == nil)
    }

    /// An ask of a session its window has stopped on Lee leads with its card; the stop, a row of its own, stands in the
    /// doing line's place as its card.
    @Test func anAskOfAStoppedSessionLeadsWithItsCardTheStopInTheDoingLinesPlace() throws {
        let run = opened(boards: ["sr-dash02": Lines.dashboard])

        run.pickInList(.line("ask:sr-dash02:k1"), at: printedAt)
        take(["sr-dash02": Lines.dashboard], in: run)
        #expect(try Self.leading(run).id == AskAddress(session: "sr-dash02", ask: "k1"))
        #expect(try Self.page(run).doingLine == .stop(Self.allowBash))
    }

    /// Picked before the session's own board has come, its ask leads at once, as the board itself carries it, its
    /// buttons ready.
    @Test func beforeItsBoardComesThePickedAskLeadsAsTheBoardCarriesIt() throws {
        let run = opened(boards: [:])
        let card = try Self.leading(run)

        #expect(!(try Self.page(run).hasBoard))
        #expect(card.id == AskAddress(session: "sr-macapp", ask: "k1"))
        #expect(card.buttons == [.yes("Approve"), .inClaude(.comment), .ignore, .snooze])
    }

    /// A snooze refused on the card built from the board's ask says so there, as on any card.
    @Test func beforeItsBoardComesARefusedSnoozeShowsOnTheLeadingCard() throws {
        let run = opened(boards: [:])
        let k1 = AskAddress(session: "sr-macapp", ask: "k1")

        _ = run.snoozed(k1, .refused("No."))
        #expect(try Self.leading(run).lines == [.notSnoozed("No.")])
    }

    /// Answered on the card built from the board's ask, the session's own board coming in its wait: the card it gives
    /// way to is the same ask, unwashed, its answer still waiting, and the answer goes to that ask.
    @Test func theCardBuiltBeforeItsBoardGivesWayToTheBoardsWithItsAnswerWaiting() throws {
        let run = opened(boards: [:])
        let k1 = AskAddress(session: "sr-macapp", ask: "k1")

        _ = run.press(.yes("Approve"), on: k1, at: printedAt)
        take(["sr-macapp": Lines.board], in: run)

        let card = try Self.leading(run)

        #expect(try Self.page(run).hasBoard)
        #expect(card.id == k1)
        #expect(card.washed == nil)
        #expect(card.lines.map { if case let .waiting(pending) = $0 { pending.words } else { "" } } == ["→ Approve"])
        #expect(run.due(at: printedAt.addingTimeInterval(2)).map(\.ask) == [k1])
    }

    /// Answered before its board comes, with the pointer over the page: the board that comes, the ask closed on it,
    /// leaves the card leading closed and faint while the page holds, as an ask answered on its own board's card.
    @Test func answeredBeforeItsBoardComesTheLeadingCardHoldsClosed() throws {
        let run = opened(boards: [:])
        let k1 = AskAddress(session: "sr-macapp", ask: "k1")

        overThePage(run)
        _ = run.press(.yes("Approve"), on: k1, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        _ = run.answered(k1, .written, at: printedAt.addingTimeInterval(2))
        take(["sr-macapp": Lines.delivered], in: run, on: line(2))
        #expect(try Self.leading(run).id == k1)
        #expect(try Self.leading(run).isClosed)
    }

    /// Two sessions each with an ask k1: the one picked is its own session's, never the other's.
    @Test func theSameAskIdInAnotherSessionNeverLeads() throws {
        let run = opened()

        run.pickInList(.line("ask:sr-dash02:k1"), at: printedAt)
        #expect(try Self.leading(run).id == AskAddress(session: "sr-dash02", ask: "k1"))
        #expect(try Self.leading(run).title != (try Self.card("k1", opened())).title)
    }

    /// Dashboard redesign held by a second window, stopped before the first: the stop picked is the second's, and leads
    /// as its own line says it, though a jump goes first to the window stopped since.
    @Test func ofTwoWindowsStoppedThePickedOneLeadsThoughAJumpGoesFirstToTheOther() throws {
        let since = 1_792_486_000_000.0
        let key = "stop:sr-dash02:w9:1792486000000"
        let line = edited(Lines.watch[0]) { board in
            var windows = board["windows"] as! [[String: Any]]
            var other = windows[1]
            var state = other["state"] as! [String: Any]

            state["since"] = since
            other["writer"] = "w9"
            other["state"] = state
            windows.append(other)
            board["windows"] = windows
            board["rows"] = (board["rows"] as! [[String: Any]]).map { row in
                guard row["session"] as? String == "sr-dash02" else {
                    return row
                }

                var row = row
                var lines = row["lines"] as! [[String: Any]]
                var stop = lines[1]

                stop["key"] = key
                stop["writer"] = "w9"
                stop["since"] = since
                stop["first"] = ["lead": "Allow Edit", "mono": "DESIGN.md", "subject": NSNull(), "more": NSNull(), "until": NSNull()]
                lines.append(stop)
                row["lines"] = lines
                return row
            }
        }
        let run = opened(on: .line(line))

        try #require(run.pickInList(.line(key), at: printedAt))

        let page = try Self.page(run)

        guard case let .stop(stop) = page.lead else {
            Issue.record("No stop leads")
            return
        }
        #expect((stop.line.lead, stop.line.mono) == ("Allow Edit", "DESIGN.md"))
        #expect(stop.since == Date(timeIntervalSince1970: since / 1000))
        #expect(page.doing.line.lead == "Allow Bash")
        #expect(page.doingLine == SessionPage.DoingLine.none)
    }

    @Test(arguments: [(Place.yourTurn, Lines.watch[0]), (.working, Lines.onItsWork)])
    func onASessionsRowTheDetailHasNoLead(place: Place, line: String) throws {
        let run = opened(on: .line(line))

        run.click(.place(place))
        run.step(down: true, at: printedAt)
        try #require(run.location.picked != nil)

        let page = try Self.page(run)

        #expect(page.mode == .detail)
        #expect(page.lead == nil)
        #expect(page.cards.isEmpty)
    }

    /// Lee's answer to the picked ask goes in with the pointer over the page: its card stays leading, closed and
    /// faint, while the page holds; then the page has no lead, nothing else taking its place.
    @Test func thePickedAskAnsweredLeadsFaintWhileThePageHoldsThenNothingLeads() throws {
        let run = opened()
        let left = printedAt.addingTimeInterval(3)

        overThePage(run)
        take(["sr-macapp": Lines.delivered], in: run, on: line(2))
        #expect(try Self.leading(run).isClosed)
        run.pointer(overPage: false, from: pageRegion, at: left)
        run.settle(at: left.addingTimeInterval(1))
        #expect(try Self.page(run).lead == nil)
    }

    // MARK: Filling the window

    @Test func fillingTheWindowEveryAsksCardShowsAndNoneLeads() throws {
        let page = try Self.page(Self.full("sr-macapp"))

        #expect(page.mode == .full)
        #expect(page.lead == nil)
        #expect(page.cards.map(\.id.ask) == ["k1", "k3", "k2"])
    }

    @Test func fillingTheWindowAStopStandsInTheDoingLinesPlace() throws {
        #expect(try Self.page(Self.full("sr-dash02", boards: [:])).doingLine == .stop(Self.allowBash))
    }

    // MARK: The meta line

    /// Its terminal, from the board's windows, and when it started, from `watch`; nothing of the screen before a look.
    @Test func theMetaLineSaysItsTerminalAndWhenItStarted() throws {
        let start = minutes(before: 60)
        let meta = try #require(Self.page(Self.full("sr-macapp", on: Self.started(start))).meta)

        #expect(meta == SessionPage.Meta(terminal: "ghostty", app: nil, onScreen: nil, started: start, away: nil))
        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == "Ghostty · started today, 07:53")
    }

    @Test func withNoStartFromWatchTheMetaLineSaysOnlyWhereItsWindowIs() throws {
        let meta = try #require(Self.page(Self.full("sr-macapp")).meta)

        #expect(meta.started == nil)
        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == "Ghostty")
    }

    /// On screen as the window's last look said: on and off said, unknown not.
    @Test(arguments: [(OnScreen.on, "Ghostty, on screen"), (.off, "Ghostty, not on screen"), (.unknown, "Ghostty")])
    func theMetaLineSaysWhetherItsWindowIsOnScreen(state: OnScreen, words: String) throws {
        let run = Self.full("sr-macapp")

        try Self.looked(run, at: "sr-macapp", is: state)

        let meta = try #require(Self.page(run).meta)

        #expect(meta.onScreen == state)
        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == words)
        #expect(Spoken.meta(meta, at: printedAt, in: Self.utc) == words)
    }

    /// In tmux its window's `$TERM_PROGRAM` is tmux, which names no app: the app is the one the look saw showing it.
    @Test func theMetaLineNamesTheAppTheLookSawShowingIt() throws {
        let run = Self.full("sr-macapp", on: .line(Lines.watch[0].replacingOccurrences(of: #""terminal":"ghostty""#, with: #""terminal":"tmux""#)))

        try Self.looked(run, at: "sr-macapp", is: .on, in: "Ghostty")

        let meta = try #require(Self.page(run).meta)

        #expect((meta.terminal, meta.app) == ("tmux", "Ghostty"))
        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == "Ghostty, on screen")
    }

    /// The Mac app held by a second window, in iTerm2, besides its first, working: the meta line names the window a
    /// jump goes to first, the one working before one on its turn, one stopped on Lee before either.
    @Test(arguments: [("yourTurn", "ghostty"), ("permission", "iTerm.app")])
    func ofTwoWindowsTheMetaLineIsOfTheOneAJumpGoesToFirst(state: String, terminal: String) throws {
        let line = edited(Lines.watch[0]) { board in
            var windows = board["windows"] as! [[String: Any]]
            var other = windows[0]
            var doing = other["state"] as! [String: Any]

            doing["is"] = state
            doing["since"] = (doing["since"] as! Double) + 1000
            other["writer"] = "w9"
            other["where"] = ["device": "/dev/ttys002", "terminal": "iTerm.app", "tmux": NSNull()]
            other["state"] = doing
            windows.append(other)
            board["windows"] = windows
        }

        #expect(try Self.page(Self.full("sr-macapp", on: .line(line))).meta?.terminal == terminal)
    }

    /// Beside the list the page draws no meta line, so it has none.
    @Test func besideTheListThereIsNoMetaLine() throws {
        #expect(try Self.page(opened()).meta == nil)
    }

    /// Away, the away line in its place, and no doing line under it to say it again.
    @Test func awayTheAwayLineIsTheMetaLine() throws {
        let page = try Self.page(Self.full("sr-gs7kq2", boards: ["sr-gs7kq2": Lines.away]))

        let meta = try #require(page.meta)

        #expect(meta.away == "No window holds it. Carry it on in Claude.")
        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == "No window holds it. Carry it on in Claude.")
        #expect(page.doingLine == SessionPage.DoingLine.none)
    }

    @Test func itsWords() {
        let started = minutes(before: 60 * 24 * 3)
        let meta = SessionPage.Meta(terminal: "iTerm.app", app: nil, onScreen: .on, started: started, away: nil)
        let words = { (meta: SessionPage.Meta) in Words.meta(meta, at: printedAt, in: Self.utc) }

        #expect(words(meta) == "iTerm2, on screen · started Sat, 08:53")
        #expect(Spoken.meta(meta, at: printedAt, in: Self.utc) == "iTerm2, on screen, started Sat, 08:53")
        #expect(words(SessionPage.Meta(terminal: nil, app: nil, onScreen: nil, started: nil, away: nil)) == nil)
        #expect(words(SessionPage.Meta(terminal: nil, app: nil, onScreen: .on, started: started, away: nil))
            == "On screen · started Sat, 08:53")
        #expect(words(SessionPage.Meta(terminal: "tmux", app: nil, onScreen: .off, started: nil, away: nil))
            == "Not on screen")
        #expect(words(SessionPage.Meta(terminal: "tmux", app: nil, onScreen: nil, started: nil, away: nil)) == nil)
        #expect(words(SessionPage.Meta(terminal: "vscode", app: nil, onScreen: .on, started: started, away: nil))
            == "On screen · started Sat, 08:53")
        #expect(Words.started(minutes(before: 60 * 24 * 400), at: printedAt, in: Self.utc) == "started 15 Sep 2025, 08:53")
        #expect(Words.terminal("ghostty") == "Ghostty")
        #expect(Words.terminal("tmux") == nil)
        #expect(Words.terminal("vscode") == nil)
        #expect(Words.started(minutes(before: 60 * 16), at: printedAt, in: Self.utc) == "started yesterday, 16:53")
        #expect(Words.started(minutes(before: 60 * 24 * 6), at: printedAt, in: Self.utc) == "started Wed, 08:53")
        #expect(Words.started(minutes(before: 60 * 24 * 7), at: printedAt, in: Self.utc) == "started 13 Oct, 08:53")
        #expect(Spoken.updated(minutes(before: 60), at: printedAt) == "updated 1 hour ago")
        #expect(Spoken.updated(printedAt, at: printedAt) == "updated just now")
    }

    // MARK: The cards

    @Test func itsAsksShowTheNewestFirst() throws {
        #expect(try Self.page(opened()).asks.map(\.id.ask) == ["k1", "k3", "k2"])
    }

    @Test func aYesIsAPillInClaudesWordsBesideACommentInClaudeAndIgnore() throws {
        let yes = try Self.card("k1", opened())

        #expect(yes.buttons == [.yes("Approve"), .inClaude(.comment), .ignore, .snooze])
        #expect(yes.where == "In Paper: SitRep · side panel, page “The SitRep window”, artboards A to C")
        #expect(yes.lines.isEmpty)
    }

    @Test func aChoiceIsAPillPerOption() throws {
        #expect(try Self.card("k2", opened()).buttons == [
            .option("Left, the notch's edge"), .option("Right"), .inClaude(.comment), .ignore, .snooze,
        ])
    }

    @Test func aWordsAskIsAnsweredInClaudeAndSaysWhatItsWordsAre() throws {
        let words = try Self.card("k3", opened())

        #expect(words.buttons == [.inClaude(.answer), .ignore, .snooze])
        #expect(words.needs == "the command's output")
    }

    /// An ask whose session no window holds is marked with the away ring; one a window holds, needs you's dot.
    @Test func anAwaySessionsAskTakesTheAwayRing() throws {
        let away = try Self.card("k1", Self.picked("sr-gs7kq2", boards: ["sr-gs7kq2": Lines.away]))
        let held = try Self.card("k1", opened())

        #expect(away.isAway && away.mark == .awayAsk)
        #expect(!held.isAway && held.mark == .needs)
    }

    @Test func onAnAwaySessionAYesOrAChoiceWaitsInTheInboxAndNothingNeedsClaudesPrompt() throws {
        let choice = try Self.card("k1", Self.picked("sr-gs7kq2", boards: ["sr-gs7kq2": Lines.away]))

        #expect(choice.buttons == [.option("Keep it"), .option("Drop it"), .ignore, .snooze])
        #expect(choice.lines == [.inbox])
    }

    @Test func anAnswerOnItsWayTakesTheButtonsAwaySayingItWaitsForTheTurnToEnd() throws {
        let run = opened(boards: ["sr-macapp": Lines.onItsWay])
        let yes = try Self.card("k1", run)

        #expect(yes.buttons.isEmpty)
        #expect(yes.lines == [.onItsWay("→ Approve", .turn)])
    }

    @Test func onAnAwaySessionAnAnswerOnItsWayWaitsForAWindow() throws {
        let windowless = Lines.watch[0].replacingOccurrences(of: #""doing":{"is":"working""#, with: #""doing":{"is":"away""#)
        let run = opened(on: .line(windowless), boards: ["sr-macapp": Lines.onItsWay])

        #expect(try Self.card("k1", run).lines == [.onItsWay("→ Approve", .window)])
    }

    /// It bars no answer, so the buttons stay; but not Snooze, as an ask a reply of Lee's is on its way to waits on him
    /// no more.
    @Test func aCommentOnItsWayBarsNoAnswerSoTheButtonsStay() throws {
        let comment = Lines.onItsWay
            .replacingOccurrences(of: #""isAnswer": true,"# + "\n" + #"        "words": "→ Approve""#, with: #""isAnswer": false,"# + "\n" + #"        "words": "comment: “Tighten it”""#)
        let run = opened(boards: ["sr-macapp": comment])
        let yes = try Self.card("k1", run)

        try #require(comment != Lines.onItsWay)
        #expect(yes.buttons == [.yes("Approve"), .inClaude(.comment), .ignore])
        #expect(yes.lines == [.commentOnItsWay("comment: “Tighten it”")])
    }

    // MARK: Now

    @Test func nowIsItsStatusWhenItLastChangedAndHowManyItParked() throws {
        let page = try Self.page(opened())

        #expect(page.status.now == ["Drawing round 3, the SitRep window, in Paper", "Keeping DESIGN.md in step on docs/surfaces"])
        #expect(page.status.next == "round 4, the menu bar item and its menu")
        #expect(page.status.updated == minutes(before: 1100))
        #expect(page.parked == 1)
    }

    /// "updated …" comes from its log's newest status line, and goes once no line its board carries is one.
    @Test func updatedGoesOnceItsStatusLineIsPastItsLog() throws {
        let run = opened(boards: ["sr-macapp": Self.logged(Array(repeating: 10, count: 8))])

        #expect(try Self.page(run).status.updated == nil)
        take(["sr-macapp": Self.logged([10, 20], kind: "status")], in: run)
        #expect(try Self.page(run).status.updated == minutes(before: 10))
    }

    @Test func withNothingParkedThereIsNoLater() throws {
        #expect(try Self.page(Self.picked("sr-rq7dgr", boards: [:])).parked == 0)
    }

    /// With no status, no next and nothing parked, Now has nothing to say, so shows no heading; any one of them, it
    /// does.
    @Test func nowShowsOnlyWithSomethingUnderIt() throws {
        let line = edited(Lines.watch[0]) { board in
            board["projects"] = (board["projects"] as! [[String: Any]]).map { project in
                var project = project

                project["sessions"] = (project["sessions"] as! [[String: Any]]).map { session in
                    session["id"] as? String == "sr-macapp"
                        ? session.merging(["now": [String](), "next": NSNull(), "parked": 0]) { $1 } : session
                }
                return project
            }
        }

        #expect(try !Self.page(opened(on: .line(line))).hasNow)
        #expect(try Self.page(opened()).hasNow)
        #expect(try Self.page(Self.picked("sr-rq7dgr", boards: [:])).hasNow)
    }

    // MARK: What happened

    /// Filling the window, its asks, "Asked …", among its log's lines, all by their times, the newest first.
    @Test func whatHappenedMergesItsOpenAsksWithItsLogTheNewestFirst() throws {
        let page = try Self.page(Self.full("sr-macapp"))

        #expect(page.happened.map(\.id) == [
            "asked:k1", "asked:k3", "asked:k2", "sr-macapp:n2", "sr-macapp:n1",
            "sr-macapp:status@1792420421.0:w1:Status: now drawing round 3, the SitRep window, in Paper (and 1 more)",
        ])
        #expect(page.happened.map(\.at) == page.happened.map(\.at).sorted(by: >))
        guard case let .asked(asked) = page.happened.first else {
            Issue.record("No ask first")
            return
        }
        #expect(asked == SessionPage.Asked(id: AskAddress(session: "sr-macapp", ask: "k1"), title: "Look at round 3, the SitRep window, and approve it or comment", at: asked.at))
    }

    /// Beside the list the session's asks are rows of their own, the picked one leading: none is in What happened.
    @Test func besideTheListWhatHappenedIsItsLogAlone() throws {
        #expect(try Self.page(opened()).happened.map(\.id) == [
            "sr-macapp:n2", "sr-macapp:n1",
            "sr-macapp:status@1792420421.0:w1:Status: now drawing round 3, the SitRep window, in Paper (and 1 more)",
        ])
    }

    /// Its asks are the cards the page draws: an ask answered while the page holds keeps its entry, as its card keeps
    /// its place, faint; once the page lets go, both go.
    @Test func whileThePageHoldsAnAnsweredAsksEntryStaysAsItsCardDoes() throws {
        let run = Self.full("sr-macapp")
        let left = printedAt.addingTimeInterval(3)
        let asked = { try Self.page(run).happened.map(\.id).filter { $0.hasPrefix("asked:") } }

        overThePage(run)
        take(["sr-macapp": Lines.delivered], in: run)
        #expect(try asked() == ["asked:k1", "asked:k3", "asked:k2"])
        run.pointer(overPage: false, from: pageRegion, at: left)
        run.settle(at: left.addingTimeInterval(1))
        #expect(try asked() == ["asked:k2"])
    }

    /// An ask's entry opens in place, as every other line of What happened does.
    @Test func anAsksEntryOpensInPlace() throws {
        let run = Self.full("sr-macapp")
        let k1 = AskAddress(session: "sr-macapp", ask: "k1")

        run.toggle(.asked(k1))
        #expect(try Self.page(run).opened == [.asked(k1)])
    }

    @Test func anAskAsOldAsALineComesBeforeIt() {
        let at = minutes(before: 30)
        let line = Note(id: "n1", session: nil, text: "A note", detail: [], at: at)
        let happened = SessionPage.happened([line], asks: [Self.ask("k1", at: at)])

        #expect(happened.map(\.id) == ["asked:k1", "n1"])
    }

    /// With the log as full as a board carries it, 8 lines, the asks older than its oldest line are cut; with fewer,
    /// every ask stays, as nothing is missing between them.
    @Test(arguments: [8, 7])
    func asksOlderThanAFullLogsOldestLineAreCut(lines: Int) {
        let log = (0 ..< lines).map { Note(id: "l\($0)", session: nil, text: "Line \($0)", detail: [], at: minutes(before: Double(10 + $0))) }
        let asks = [Self.ask("k1", at: minutes(before: 60)), Self.ask("k2", at: minutes(before: 5))]
        let lineIDs = (0 ..< lines).map { "l\($0)" }

        #expect(SessionPage.happened(log, asks: asks).map(\.id)
            == ["asked:k2"] + lineIDs + (lines < SessionPage.logLines ? ["asked:k1"] : []))
    }

    @Test func itsResolvedSayHowEachClosedFoldedUnderNResolved() throws {
        let page = try Self.page(opened())

        #expect(page.resolved.map(\.title) == ["Look at round 1, the panel's rows", "Merge PR #4"])
        #expect(page.resolved.map(\.how) == [.resolved("you said \"left\" in the chat"), .sent])
        #expect(Words.resolved(page.resolved.count) == "2 resolved")
    }

    /// "N resolved" is folded at first, opens in place, and is folded again once another page has shown.
    @Test func nResolvedIsFoldedAtFirstAndOpensInPlace() throws {
        let run = opened()

        #expect(try !Self.page(run).opened.contains(.resolvedFold))
        run.toggle(.resolvedFold)
        #expect(try Self.page(run).opened.contains(.resolvedFold))
        run.pickInList(.line("ask:sr-dash02:k1"), at: printedAt)
        run.pickInList(macAppK1, at: printedAt)
        #expect(try !Self.page(run).opened.contains(.resolvedFold))
    }

    /// From the session's page beside the list to the same session's filling the window, and Back, are page turns:
    /// "N resolved" is folded again on each. Another line of the same session picked is no turn, and keeps it open.
    @Test func goingBetweenTheDetailAndTheSessionsFullPageTurnsThePage() throws {
        let run = opened()

        run.toggle(.resolvedFold)
        run.pickInList(.line("ask:sr-macapp:k3"), at: printedAt)
        #expect(try Self.page(run).opened.contains(.resolvedFold))
        run.go(to: .session("sr-macapp", from: .project("sitrep")), by: .projectSession)
        #expect(try Self.page(run).mode == .full)
        #expect(try !Self.page(run).opened.contains(.resolvedFold))
        run.toggle(.resolvedFold)
        run.goBack()
        #expect(try Self.page(run).mode == .detail)
        #expect(try !Self.page(run).opened.contains(.resolvedFold))
    }

    private static func ask(_ id: String, at time: Date) -> SessionPage.Asked {
        SessionPage.Asked(id: AskAddress(session: "s1", ask: id), title: "Ask \(id)", at: time)
    }
}
