@testable import SitRep
import SitRepCore
import SitRepRelay
import SitRepTestSupport
import Testing

/// SitRep's banners through the notices helper, over a relay and a helper app of its own: nothing is posted, launched or
/// relayed for real.
@MainActor
struct BannersTests {
    private static let pid: Int32 = 4012
    /// The first helper, and the one macOS starts for a click after it.
    private static let first: Int32 = 5150
    private static let second: Int32 = 5151
    private static let ready = ToSitRep.ready(helper: first)
    private static let asked = Banner(title: "Pick a name", subtitle: "Trey Research · Build the desktop app", body: "", work: "sr-a8n2xc")
    private static let askedNotice = Notice(
        title: "Pick a name", subtitle: "Trey Research · Build the desktop app", body: "", work: "sr-a8n2xc"
    )

    /// What SitRep sent the helper, waited on.
    @MainActor
    final class Sent {
        private(set) var messages: [ToHelper] = []
        private(set) var pids: Set<Int32> = []
        private var waiter: CheckedContinuation<Void, Never>?

        func put(_ letter: Letter<ToHelper>) {
            messages.append(letter.message)
            pids.insert(letter.pid)
            waiter?.resume()
            waiter = nil
        }

        /// Once `count` messages are sent.
        func first(_ count: Int) async -> [ToHelper] {
            while messages.count < count {
                await withCheckedContinuation { waiter = $0 }
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

    @MainActor
    final class Clicks {
        var works: [String] = []
        var refused: (() -> Void)?
    }

    private let sent = Sent()
    private let app = App()
    private let clicks = Clicks()

    private func banners(answerWithin: Duration = .seconds(60)) -> Banners {
        let banners = Banners(pid: Self.pid, send: sent.put, helperApp: app, answerWithin: answerWithin)

        banners.start { [clicks] work, refused in
            clicks.works.append(work)
            clicks.refused = refused
        }

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
        banners.post(Self.asked)

        #expect(clicks.works.isEmpty)
        #expect(sent.messages == [.ready])
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

    @Test func itReadsMacOSsLeaveThroughTheHelper() async {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        async let leave = banners.leave()
        _ = await sent.first(3)
        let id = sent.lastId!

        banners.heard(Self.fromHelper(.status(.allowed(.alerts), id: "another")))
        banners.heard(Self.fromHelper(.status(.denied, id: id)))

        #expect(sent.messages.last == .status(id: id))
        #expect(await leave == .denied)
    }

    @Test func aLeaveTheHelperDoesNotAnswerInTimeIsUnknown() async {
        let banners = banners(answerWithin: .milliseconds(1))

        #expect(await banners.leave() == nil)
    }

    @Test func askingIsDoneOnceTheHelperAnswers() async {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        async let asked: Void = banners.ask()
        _ = await sent.first(3)

        #expect(sent.messages.last == .ask(id: sent.lastId!))

        banners.heard(Self.fromHelper(.status(.allowed(.banners), id: sent.lastId!)))
        await asked
    }

    /// What the helper had yet to answer is unknown, and what comes after waits for it, started again.
    @Test func theHelperEndingAnswersWhatItHadNotAndStartsItAgainForWhatComes() async {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        async let leave = banners.leave()
        _ = await sent.first(3)
        banners.helperEnded(Self.ended(Self.first))

        #expect(await leave == nil)

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
    @Test func aNewHelpersReadyBeforeTheLastOnesEndIsHeardAndTheLateEndPassedOver() async {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        async let leave = banners.leave()
        _ = await sent.first(3)
        let opened = app.opens

        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(await leave == nil)
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
    @Test func aReadGivenUpOnIsNotSentLater() async {
        let banners = banners(answerWithin: .milliseconds(1))

        #expect(await banners.leave() == nil)

        banners.heard(Self.fromHelper(Self.ready))

        #expect(sent.messages == [.ready, .ready])
    }

    /// An ask the helper that ended was never sent waits for the next, so Settings reads again only once Lee answers.
    @Test func theHelperEndingLeavesAnAskNotYetSentForTheNext() async {
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
        await asking.value

        #expect(banners.unanswered.isEmpty)
    }
}
