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

    /// The window's last look at the screen, as `sitrep screen` read this session.
    private static func looked(_ run: WindowRun, at session: String, is state: OnScreen) throws {
        let reading = #"{"v":1,"sessions":[{"id":"\#(session)","is":"\#(state.rawValue)"}],"unanswered":[]}"#

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

    /// A window's stop picked leads as the stop's card, and the line for what its window is doing, which would say the
    /// stop again, gives way to it.
    @Test func aStopPickedLeadsWithTheStopInPlaceOfTheDoingLine() throws {
        let run = opened()

        run.pickInList(.line("stop:sr-dash02:w2:1792486361000"), at: printedAt)

        let page = try Self.page(run)

        #expect(page.lead == .stop)
        #expect(page.doing == doing(.permission, "Allow Bash", mono: "gh pr create --draft --base main", since: minutes(before: 1)))
        #expect(page.doingLine == SessionPage.DoingLine.none)
    }

    /// An ask of a session its window has stopped on Lee leads with its card; the stop, a row of its own, stays the
    /// line for what its window is doing.
    @Test func anAskOfAStoppedSessionLeadsWithItsCardTheStopItsDoingLine() throws {
        let run = opened(boards: ["sr-dash02": Lines.dashboard])

        run.pickInList(.line("ask:sr-dash02:k1"), at: printedAt)
        take(["sr-dash02": Lines.dashboard], in: run)
        #expect(try Self.leading(run).id == AskAddress(session: "sr-dash02", ask: "k1"))
        #expect(try Self.page(run).doingLine == .line)
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
        take(["sr-macapp": Lines.delivered], in: run)
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
        #expect(try Self.page(Self.full("sr-dash02", boards: [:])).doingLine == .stop)
    }

    // MARK: The meta line

    /// Its terminal, from the board's windows, and when it started, from `watch`; nothing of the screen before a look.
    @Test func theMetaLineSaysItsTerminalAndWhenItStarted() throws {
        let start = minutes(before: 60)
        let meta = try Self.page(Self.full("sr-macapp", on: Self.started(start))).meta

        #expect(meta == SessionPage.Meta(terminal: "ghostty", onScreen: nil, started: start, away: nil))
        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == "Ghostty · started today, 07:53")
    }

    @Test func withNoStartFromWatchTheMetaLineSaysOnlyWhereItsWindowIs() throws {
        let meta = try Self.page(Self.full("sr-macapp")).meta

        #expect(meta.started == nil)
        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == "Ghostty")
    }

    /// On screen as the window's last look said: on and off said, unknown not.
    @Test(arguments: [(OnScreen.on, "Ghostty, on screen"), (.off, "Ghostty, not on screen"), (.unknown, "Ghostty")])
    func theMetaLineSaysWhetherItsWindowIsOnScreen(state: OnScreen, words: String) throws {
        let run = Self.full("sr-macapp")

        try Self.looked(run, at: "sr-macapp", is: state)

        let meta = try Self.page(run).meta

        #expect(meta.onScreen == state)
        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == words)
        #expect(Spoken.meta(meta, at: printedAt, in: Self.utc) == words)
    }

    /// Away, the away line in its place, and no doing line under it to say it again.
    @Test func awayTheAwayLineIsTheMetaLine() throws {
        let page = try Self.page(Self.full("sr-gs7kq2", boards: ["sr-gs7kq2": Lines.away]))

        #expect(page.meta.away == "No window holds it. Carry it on in Claude.")
        #expect(Words.meta(page.meta, at: printedAt, in: Self.utc) == "No window holds it. Carry it on in Claude.")
        #expect(page.doingLine == SessionPage.DoingLine.none)
    }

    @Test func itsWords() {
        let meta = SessionPage.Meta(terminal: "iTerm.app", onScreen: .on, started: minutes(before: 60 * 24 * 3), away: nil)

        #expect(Words.meta(meta, at: printedAt, in: Self.utc) == "iTerm2, on screen · started Sat, 08:53")
        #expect(Spoken.meta(meta, at: printedAt, in: Self.utc) == "iTerm2, on screen, started Sat, 08:53")
        #expect(Words.meta(SessionPage.Meta(terminal: nil, onScreen: nil, started: nil, away: nil), at: printedAt, in: Self.utc) == nil)
        #expect(Words.terminal("ghostty") == "Ghostty")
        #expect(Words.terminal("tmux") == "tmux")
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

    // MARK: What happened

    /// Its asks still open, "Asked …", among its log's lines, all by their times, the newest first.
    @Test func whatHappenedMergesItsOpenAsksWithItsLogTheNewestFirst() throws {
        let page = try Self.page(opened())

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

    @Test func anAskAsOldAsALineComesBeforeIt() {
        let at = minutes(before: 30)
        let line = Note(id: "n1", session: nil, text: "A note", detail: [], at: at)
        let happened = SessionPage.happened([line], asks: [Self.ask("k1", at: at)], of: "s1")

        #expect(happened.map(\.id) == ["asked:k1", "n1"])
    }

    /// With the log as full as a board carries it, 8 lines, the asks older than its oldest line are cut; with fewer,
    /// every ask stays, as nothing is missing between them.
    @Test(arguments: [8, 7])
    func asksOlderThanAFullLogsOldestLineAreCut(lines: Int) {
        let log = (0 ..< lines).map { Note(id: "l\($0)", session: nil, text: "Line \($0)", detail: [], at: minutes(before: Double(10 + $0))) }
        let asks = [Self.ask("k1", at: minutes(before: 60)), Self.ask("k2", at: minutes(before: 5))]
        let lineIDs = (0 ..< lines).map { "l\($0)" }

        #expect(SessionPage.happened(log, asks: asks, of: "s1").map(\.id)
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

    private static func ask(_ id: String, at time: Date) -> Board.Ask {
        let json = #"{"id":"\#(id)","wants":"yes","yes":null,"title":"Ask \#(id)","where":null,"options":[],"needs":null,"ref":null,"state":"waiting","at":\#((time.timeIntervalSince1970 * 1000).rounded()),"reply":null}"#

        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try! decoder.decode(Board.Ask.self, from: Data(json.utf8))
    }
}
