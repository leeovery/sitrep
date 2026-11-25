@testable import SitRep
@testable import SitRepCore
import SitRepRelay
import SitRepTestSupport
import Testing

/// SitRep's banners through the notices helper, over a relay and a helper app of its own: nothing is posted, launched or
/// relayed for real.
@MainActor
@Suite(.backstop)
struct BannersTests {
    private static let pid: Int32 = 4012
    /// The first helper, and the one macOS starts for a click after it.
    private static let first: Int32 = 5150
    private static let second: Int32 = 5151
    private static let ready = ToSitRep.ready(helper: first)
    private static let asked = Banner(title: "Pick a name", subtitle: "Trey Research · Build the desktop app", body: "", work: "sr-a8n2xc")
    private static let pressed = NoticeAnswer(
        to: NoticeAsk(
            id: "k2", session: "sr-a8n2xc", title: "Pick a name", place: "Trey Research · Build the desktop app",
            wants: .choice(["Left", "Right"])
        ),
        words: "Right"
    )
    private static let askedNotice = Notice(
        title: "Pick a name", subtitle: "Trey Research · Build the desktop app", body: "", work: "sr-a8n2xc"
    )

    /// What SitRep sent the helper, waited on.
    @MainActor
    final class Sent {
        private(set) var messages: [ToHelper] = []
        private(set) var pids: Set<Int32> = []
        private var waiter: (@Sendable (()) -> Void)?

        func put(_ letter: Letter<ToHelper>) {
            messages.append(letter.message)
            pids.insert(letter.pid)
            waiter?(())
            waiter = nil
        }

        /// Once `count` messages are sent; the next not sent within the time ends the test.
        func first(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async throws -> [ToHelper] {
            while messages.count < count {
                try await answer(
                    within: .seconds(10), "for message \(messages.count + 1) to be sent", sourceLocation: sourceLocation
                ) { waiter = $0 }
            }

            return messages
        }

        /// The id of the last request sent.
        var lastId: String? {
            switch messages.last {
            case let .status(id), let .ask(id): id
            default: nil
            }
        }
    }

    /// The helper as an app: how often SitRep opened it, the one it watches, and the helpers running.
    @MainActor
    final class App: HelperStarting {
        var opens = 0
        var watched: Int32?
        var running: Set<Int32> = [BannersTests.first, BannersTests.second]

        func open() {
            opens += 1
        }

        func isRunning(_ pid: Int32) -> Bool {
            running.contains(pid)
        }
    }

    /// What `Answers` ran through the CLI, and the banners it posted.
    @MainActor
    final class Ran {
        var answerings: [Answering] = []
        var banners: [Banner] = []
    }

    @MainActor
    final class Clicks {
        var works: [String] = []
        var refused: (() -> Void)?
        var answers: [NoticeAnswer] = []
    }

    private let sent = Sent()
    private let app = App()
    private let clicks = Clicks()

    private func banners(answerWithin: Duration = .seconds(60)) -> Banners {
        let banners = Banners(pid: Self.pid, send: sent.put, helperApp: app, answerWithin: answerWithin)

        banners.start(
            onClick: { [clicks] work, refused in
                clicks.works.append(work)
                clicks.refused = refused
            },
            onAnswer: { [clicks] in clicks.answers.append($0) }
        )

        return banners
    }

    private static func fromHelper(_ message: ToSitRep, pid: Int32 = pid) -> Letter<ToSitRep> {
        Letter(message, pid: pid)
    }

    private static func ended(_ pid: Int32, wasRunning: Bool = false) -> HelperApp.End {
        HelperApp.End(pid: pid, wasRunning: wasRunning)
    }

    /// Listening, ready, the helper started, all as SitRep's launching ends.
    @Test func itSaysItListensAndStartsTheHelper() {
        _ = banners()

        #expect(sent.messages == [.ready])
        #expect(sent.pids == [Self.pid])
        #expect(app.opens == 1)
    }

    @Test func aBannerWaitsForTheHelperToListenThenGoesInOrder() {
        let banners = banners()
        let second = Banner.unjumped("Ghostty did not answer")

        banners.post(Self.asked)
        banners.post(second)

        #expect(sent.messages == [.ready])
        #expect(app.opens == 3)

        banners.heard(Self.fromHelper(Self.ready))

        #expect(sent.messages == [
            .ready, .ready, .post(Self.askedNotice),
            .post(Notice(title: "SitRep could not jump", subtitle: nil, body: "Ghostty did not answer", work: nil)),
        ])
    }

    /// The helper may have missed SitRep's ready, so its first is answered; no more, or the two would never stop.
    @Test func itAnswersTheHelpersFirstReadyAlone() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.heard(Self.fromHelper(Self.ready))

        #expect(sent.messages == [.ready, .ready])
    }

    @Test func onceTheHelperListensABannerGoesAtOnce() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.post(Self.asked)

        #expect(sent.messages == [.ready, .ready, .post(Self.askedNotice)])
    }

    /// A helper running and watched that has not said it listens, its ready perhaps lost, is told SitRep's again for
    /// what waits, which it answers, rather than the banner waiting till SitRep quits.
    @Test func aHelperRunningThatHasNotSaidItListensIsToldReadyAgain() {
        let banners = banners()

        app.watched = Self.first
        banners.post(Self.asked)

        #expect(sent.messages == [.ready, .ready])
        #expect(app.opens == 1)

        banners.heard(Self.fromHelper(Self.ready))

        #expect(sent.messages.last == .post(Self.askedNotice))
    }

    /// The handler SitRep gives is the jump.
    @Test func aClickTheHelperRelaysReachesTheJump() {
        let banners = banners()

        banners.heard(Self.fromHelper(.clicked(work: "sr-a8n2xc")))

        #expect(clicks.works == ["sr-a8n2xc"])
    }

    @Test func aLetterForAnotherSitRepIsPassedOver() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready, pid: 977))
        banners.heard(Self.fromHelper(.clicked(work: "sr-a8n2xc"), pid: 977))
        banners.heard(Self.fromHelper(.answered(Self.pressed), pid: 977))
        banners.post(Self.asked)

        #expect(clicks.works.isEmpty)
        #expect(clicks.answers.isEmpty)
        #expect(sent.messages == [.ready])
    }

    /// A new ask's banner goes with its ask, whatever it wants, for the helper to draw its buttons.
    @Test(arguments: [
        (Banner.Ask.Wants.yes("Go"), NoticeAsk.Wants.yes("Go")),
        (.choice(["Left", "Right"]), .choice(["Left", "Right"])),
        (.words, .words),
    ])
    func aNewAsksBannerGoesWithItsAsk(wants: Banner.Ask.Wants, relayed: NoticeAsk.Wants) {
        let banners = banners()
        let ask = Banner.Ask(
            id: "k2", session: "sr-a8n2xc", title: "Pick a name", place: "Trey Research · Build the desktop app",
            wants: wants
        )

        banners.heard(Self.fromHelper(Self.ready))
        banners.post(Banner(title: "Pick a name", subtitle: nil, body: "", work: "sr-a8n2xc", ask: ask))

        #expect(sent.messages.last == .post(Notice(
            title: "Pick a name", subtitle: nil, body: "", work: "sr-a8n2xc",
            ask: NoticeAsk(
                id: "k2", session: "sr-a8n2xc", title: "Pick a name", place: "Trey Research · Build the desktop app",
                wants: relayed
            )
        )))
    }

    @Test func anAnswerTheHelperRelaysReachesItsHandler() {
        let banners = banners()

        banners.heard(Self.fromHelper(.answered(Self.pressed)))

        #expect(clicks.answers == [Self.pressed])
        #expect(clicks.works.isEmpty)
    }

    /// The app's handler: the banner's answer sent through `Answers` at once, with no hold, as its words, with what the
    /// banner showed it wanting, the board still holding the ask as its banner showed it.
    @Test func aRelayedAnswerIsSentAtOnceThroughAnswers() async throws {
        let ran = Ran()
        let board = try Self.board(
            WatchLine.Ask(id: "k2", wants: .choice, yes: nil, title: "Pick a name", options: ["Left", "Right"])
        )
        let answers = Self.answers(ran, on: board)

        Self.relay(Self.pressed, to: answers)
        await until(turns: 10_000) { !ran.answerings.isEmpty }

        #expect(ran.answerings == [Answering(.words("Right"), to: "k2", of: "sr-a8n2xc", wanting: .choice)])
        #expect(answers.held == nil)
        #expect(ran.banners.isEmpty)
    }

    /// The board's ask reshaped since its banner showed: "Not answered", and nothing sent.
    @Test func aRelayedAnswerToAnAskReshapedSinceIsNotSent() async throws {
        let ran = Ran()
        let answers = Self.answers(ran, on: try Self.board(WatchLine.Ask(id: "k2", wants: .words, yes: nil)))

        Self.relay(Self.pressed, to: answers)
        await until(turns: 10_000) { !ran.banners.isEmpty }

        #expect(ran.banners == [Self.named("The ask changed after its banner showed, so nothing was sent.")])
        #expect(ran.answerings.isEmpty)
    }

    /// A refusal, as for an ask answered in its window meanwhile, posts "Not answered" in the CLI's words.
    @Test func aRelayedAnswerTheCLIRefusesPostsNotAnswered() async {
        let ran = Ran()
        let answers = Self.answers(ran, on: nil, written: .refused("Answered already"))

        Self.relay(Self.pressed, to: answers)
        await until(turns: 10_000) { !ran.banners.isEmpty }

        #expect(ran.banners == [Self.named("Answered already")])
    }

    /// An ask that waits on Lee no more has its banners cleared through the helper.
    @Test func anAskLeftIsClearedThroughTheHelper() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.clear(AskOf(session: "sr-a8n2xc", ask: "k2"))

        #expect(sent.messages.last == .cleared(ask: "k2", session: "sr-a8n2xc"))
    }

    /// Answers through a CLI that writes as given, recording what it ran and posted, on this board.
    private static func answers(_ ran: Ran, on board: Board?, written: WriteAnswer = .written) -> Answers {
        Answers(
            answer: { ran.answerings.append($0); return written }, post: { ran.banners.append($0) },
            board: { board }
        )
    }

    /// The answer relayed through banners started as the app starts them.
    private static func relay(_ answer: NoticeAnswer, to answers: Answers) {
        let banners = Banners(pid: pid, send: { _ in }, helperApp: App())

        banners.start(onClick: { _, _ in }, onAnswer: answers.send)
        banners.heard(fromHelper(.answered(answer)))
    }

    /// "Not answered" in these words, naming the ask `pressed` answers as its banner showed it, which the board, with no
    /// row for its session, does not name.
    private static func named(_ why: String) -> Banner {
        Banner(title: "Not answered", subtitle: "Trey Research · Build the desktop app", body: why, work: "sr-a8n2xc")
    }

    /// A board holding this one ask of the session `pressed` answers.
    private static func board(_ ask: WatchLine.Ask) throws -> Board {
        let session = WatchLine.Session(id: "sr-a8n2xc", asks: [ask])

        return try Board.read(WatchLine(projects: [WatchLine.Project(sessions: [session])]).text)
    }

    /// Its ready and its end come by different ways, in no order: a ready from a helper already ended would take what
    /// waits to nothing.
    @Test func aReadyFromAHelperAlreadyEndedIsPassedOver() {
        let banners = banners()

        app.running = [Self.second]
        banners.post(Self.asked)
        banners.heard(Self.fromHelper(Self.ready))

        #expect(sent.messages == [.ready])

        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(sent.messages == [.ready, .ready, .post(Self.askedNotice)])
    }

    @Test func itReadsMacOSsLeaveThroughTheHelper() async throws {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        let leave = Task { await banners.leave() }
        _ = try await sent.first(3)
        let id = sent.lastId!

        banners.heard(Self.fromHelper(.status(.allowed(.alerts), id: "another")))
        banners.heard(Self.fromHelper(.status(.denied, id: id)))

        #expect(sent.messages.last == .status(id: id))
        #expect(try await value(of: leave, within: .seconds(10)) == .denied)
    }

    @Test func aLeaveTheHelperDoesNotAnswerInTimeIsUnknown() async throws {
        let banners = banners(answerWithin: .milliseconds(1))

        #expect(try await value(of: Task { await banners.leave() }, within: .seconds(10)) == nil)
    }

    @Test func askingIsDoneOnceTheHelperAnswers() async throws {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        let asking = Task { await banners.ask() }
        _ = try await sent.first(3)

        #expect(sent.messages.last == .ask(id: sent.lastId!))

        banners.heard(Self.fromHelper(.status(.allowed(.banners), id: sent.lastId!)))
        try await value(of: asking, within: .seconds(10))
    }

    /// What the helper had yet to answer is unknown, and what comes after waits for it, started again.
    @Test func theHelperEndingAnswersWhatItHadNotAndStartsItAgainForWhatComes() async throws {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        let leave = Task { await banners.leave() }
        _ = try await sent.first(3)
        banners.helperEnded(Self.ended(Self.first))

        #expect(try await value(of: leave, within: .seconds(10)) == nil)

        let opened = app.opens

        banners.post(Self.asked)

        #expect(sent.messages.count == 3)
        #expect(app.opens == opened + 1)

        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(sent.messages.dropFirst(3) == [.ready, .post(Self.askedNotice)])
    }

    /// Whoever started it, SitRep or macOS for a click, a helper that says it listens is watched for ending, through
    /// the open, which finds it running.
    @Test func aHelperThatSaysItListensIsWatched() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        #expect(app.opens == 2)
    }

    /// Ended with nothing to say, the helper is not started again, so one that ends as it starts is not started over
    /// and over; the next that says it listens, as macOS starts one for a click, is heard and watched.
    @Test func aHelperStartedForAClickAfterOneEndedIsHeardAndWatched() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.helperEnded(Self.ended(Self.first))

        #expect(app.opens == 2)

        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(app.opens == 3)
        #expect(sent.messages == [.ready, .ready, .ready])

        banners.helperEnded(Self.ended(Self.second))
        banners.post(Self.asked)

        #expect(sent.messages.count == 3)
        #expect(app.opens == 4)
    }

    /// A helper this SitRep started that ends before it says it listens, as one crashing as it starts, is not started
    /// again for what waits: only for what SitRep says next, so it is never started over and over.
    @Test func aHelperEndingBeforeItSaidItListensIsNotStartedAgain() {
        let banners = banners()

        banners.post(Self.asked)
        let opened = app.opens

        banners.helperEnded(Self.ended(Self.first))

        #expect(app.opens == opened)

        banners.post(Self.asked)

        #expect(app.opens == opened + 1)
    }

    /// SitRep restarted at once and was handed the SitRep before's helper, which ended without a word for it: one of
    /// its own is started for what waits, once; should that one end as it starts, no more.
    @Test func aHelperLeftFromTheSitRepBeforeIsFollowedByOneOfItsOwnOnce() {
        let banners = banners()

        banners.post(Self.asked)
        let opened = app.opens

        banners.helperEnded(Self.ended(Self.first, wasRunning: true))

        #expect(app.opens == opened + 1)

        banners.helperEnded(Self.ended(Self.second))

        #expect(app.opens == opened + 1)
    }

    @Test func aHelperLeftFromTheSitRepBeforeWithNothingWaitingIsFollowedByNone() {
        let banners = banners()
        let opened = app.opens

        banners.helperEnded(Self.ended(Self.first, wasRunning: true))

        #expect(app.opens == opened)
    }

    /// macOS started a second helper for a click on the first one's banner, and its ready came before the first one's
    /// end was told: the second is heard, answered and watched, and the first one's end changes nothing of it.
    @Test func aNewHelpersReadyBeforeTheLastOnesEndIsHeardAndTheLateEndPassedOver() async throws {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        let leave = Task { await banners.leave() }
        _ = try await sent.first(3)
        let opened = app.opens

        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(try await value(of: leave, within: .seconds(10)) == nil)
        #expect(sent.messages.last == .ready)
        #expect(app.opens == opened + 1)

        banners.helperEnded(Self.ended(Self.first))
        banners.post(Self.asked)

        #expect(app.opens == opened + 2)
        #expect(sent.messages.last == .post(Self.askedNotice))
    }

    /// The jump for a relayed click refused, the helper is told to hand the front back.
    @Test func aRefusedJumpForAClickHandsTheFrontBack() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.heard(Self.fromHelper(.clicked(work: "sr-gone")))

        #expect(sent.messages.last == .ready)

        clicks.refused?()

        #expect(sent.messages.last == .handBack)
    }

    /// Never held for a later helper, which it would hide mid-way through a click of its own, nor starting one.
    @Test func aRefusedJumpWhoseHelperEndedHandsNothingBack() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.heard(Self.fromHelper(.clicked(work: "sr-gone")))
        banners.helperEnded(Self.ended(Self.first))
        let opened = app.opens

        clicks.refused?()
        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(!sent.messages.contains(.handBack))
        #expect(app.opens == opened + 1)
    }

    @Test func aRefusedJumpGoesToTheHelperThatRelayedTheClickAlone() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.heard(Self.fromHelper(.clicked(work: "sr-gone")))
        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        clicks.refused?()

        #expect(!sent.messages.contains(.handBack))
    }

    /// Given up on, it is not sent to a helper that comes later, nor kept waiting for one that never does.
    @Test func aReadGivenUpOnIsNotSentLater() async throws {
        let banners = banners(answerWithin: .milliseconds(1))

        #expect(try await value(of: Task { await banners.leave() }, within: .seconds(10)) == nil)

        banners.heard(Self.fromHelper(Self.ready))

        #expect(sent.messages == [.ready, .ready])
    }

    /// An ask the helper that ended was never sent waits for the next, so Settings reads again only once Lee answers.
    @Test func theHelperEndingLeavesAnAskNotYetSentForTheNext() async throws {
        let banners = banners()
        let asking = Task { await banners.ask() }

        await until(turns: 10_000) { !banners.unanswered.isEmpty }
        #expect(app.opens == 2)
        banners.helperEnded(Self.ended(Self.first))
        #expect(banners.unanswered.count == 1)

        banners.heard(Self.fromHelper(Self.ready))

        #expect(sent.messages.last == .ask(id: sent.lastId!))
        #expect(banners.unanswered == [sent.lastId!])

        banners.heard(Self.fromHelper(.status(.allowed(.banners), id: sent.lastId!)))
        try await value(of: asking, within: .seconds(10))

        #expect(banners.unanswered.isEmpty)
    }
}
