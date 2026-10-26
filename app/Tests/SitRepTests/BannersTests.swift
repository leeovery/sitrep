@testable import SitRep
import SitRepCore
import SitRepRelay
import Testing

/// SitRep's banners through the notices helper, over a relay of its own: nothing is posted, launched or relayed for
/// real.
@MainActor
struct BannersTests {
    private static let pid: Int32 = 4012
    /// The first helper, and the one macOS starts for a click after it.
    private static let first: Int32 = 5150
    private static let second: Int32 = 5151
    private static let ready = ToSitRep.ready(helper: first)
    private static let asked = Banner(title: "Pick a name", subtitle: "SitRep · Build the Mac app", body: "", work: "sr-aw3bgs")

    /// What SitRep sent the helper, waited on, and how often it started it.
    @MainActor
    final class Helper {
        private(set) var messages: [ToHelper] = []
        private(set) var pids: Set<Int32> = []
        var launches = 0
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

    @MainActor
    final class Clicks {
        var works: [String] = []
        var refused: (() -> Void)?
    }

    @MainActor
    final class Asked {
        var isDone = false
    }

    private let helper = Helper()
    private let clicks = Clicks()

    private func banners(answerWithin: Duration = .seconds(60)) -> Banners {
        let banners = Banners(pid: Self.pid, send: helper.put, launch: { [helper] in helper.launches += 1 }, answerWithin: answerWithin)

        banners.start { [clicks] work, refused in
            clicks.works.append(work)
            clicks.refused = refused
        }

        return banners
    }

    private static func fromHelper(_ message: ToSitRep, pid: Int32 = pid) -> Letter<ToSitRep> {
        Letter(message, pid: pid)
    }

    /// Listening, ready, the helper started, all as SitRep's launching ends.
    @Test func itSaysItListensAndStartsTheHelper() {
        _ = banners()

        #expect(helper.messages == [.ready])
        #expect(helper.pids == [Self.pid])
        #expect(helper.launches == 1)
    }

    @Test func aBannerWaitsForTheHelperToListenThenGoesInOrder() {
        let banners = banners()
        let second = Banner.unjumped("Ghostty did not answer")

        banners.post(Self.asked)
        banners.post(second)

        #expect(helper.messages == [.ready])
        #expect(helper.launches == 3)

        banners.heard(Self.fromHelper(Self.ready))

        #expect(helper.messages == [
            .ready, .ready,
            .post(Notice(title: "Pick a name", subtitle: "SitRep · Build the Mac app", body: "", work: "sr-aw3bgs")),
            .post(Notice(title: "SitRep could not jump", subtitle: nil, body: "Ghostty did not answer", work: nil)),
        ])
    }

    /// The helper may have missed SitRep's ready, so its first is answered; no more, or the two would never stop.
    @Test func itAnswersTheHelpersFirstReadyAlone() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.heard(Self.fromHelper(Self.ready))

        #expect(helper.messages == [.ready, .ready])
    }

    @Test func onceTheHelperListensABannerGoesAtOnce() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.post(Self.asked)

        #expect(helper.messages.count == 3)
    }

    /// The handler SitRep gives is the jump.
    @Test func aClickTheHelperRelaysReachesTheJump() {
        let banners = banners()

        banners.heard(Self.fromHelper(.clicked(work: "sr-aw3bgs")))

        #expect(clicks.works == ["sr-aw3bgs"])
    }

    @Test func aLetterForAnotherSitRepIsPassedOver() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready, pid: 977))
        banners.heard(Self.fromHelper(.clicked(work: "sr-aw3bgs"), pid: 977))
        banners.post(Self.asked)

        #expect(clicks.works.isEmpty)
        #expect(helper.messages == [.ready])
    }

    @Test func itReadsMacOSsLeaveThroughTheHelper() async {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        async let leave = banners.leave()
        _ = await helper.first(3)
        let id = helper.lastId!

        banners.heard(Self.fromHelper(.status(.allowed(.alerts), id: "another")))
        banners.heard(Self.fromHelper(.status(.denied, id: id)))

        #expect(helper.messages.last == .status(id: id))
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
        _ = await helper.first(3)

        #expect(helper.messages.last == .ask(id: helper.lastId!))

        banners.heard(Self.fromHelper(.status(.allowed(.banners), id: helper.lastId!)))
        await asked
    }

    /// What the helper had yet to answer is unknown, and what comes after waits for it, started again.
    @Test func theHelperEndingAnswersWhatItHadNotAndStartsItAgainForWhatComes() async {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        async let leave = banners.leave()
        _ = await helper.first(3)
        banners.helperEnded(Self.first)

        #expect(await leave == nil)

        let launched = helper.launches

        banners.post(Self.asked)

        #expect(helper.messages.count == 3)
        #expect(helper.launches == launched + 1)

        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(helper.messages.dropFirst(3) == [.ready, .post(Notice(
            title: "Pick a name", subtitle: "SitRep · Build the Mac app", body: "", work: "sr-aw3bgs"
        ))])
    }

    /// Whoever started it, SitRep or macOS for a click, a helper that says it listens is watched for ending, through
    /// the launch, which finds it running.
    @Test func aHelperThatSaysItListensIsWatched() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        #expect(helper.launches == 2)
    }

    /// Ended with nothing to say, the helper is not started again, so one that ends as it starts is not started over
    /// and over; the next that says it listens, as macOS starts one for a click, is heard and watched.
    @Test func aHelperStartedForAClickAfterOneEndedIsHeardAndWatched() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.helperEnded(Self.first)

        #expect(helper.launches == 2)

        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(helper.launches == 3)
        #expect(helper.messages == [.ready, .ready, .ready])

        banners.helperEnded(Self.second)
        banners.post(Self.asked)

        #expect(helper.messages.count == 3)
        #expect(helper.launches == 4)
    }

    /// A helper that ends before it says it listens, as one crashing as it starts, is not started again for what
    /// waits: only for what SitRep says next, so it is never started over and over.
    @Test func aHelperEndingBeforeItSaidItListensIsNotStartedAgain() {
        let banners = banners()

        banners.post(Self.asked)
        let launched = helper.launches

        banners.helperEnded(Self.first)

        #expect(helper.launches == launched)

        banners.post(Self.asked)

        #expect(helper.launches == launched + 1)
    }

    /// macOS started a second helper for a click on the first one's banner, and its ready came before the first one's
    /// end was told: the second is heard, answered and watched, and the first one's end changes nothing of it.
    @Test func aNewHelpersReadyBeforeTheLastOnesEndIsHeardAndTheLateEndPassedOver() async {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))

        async let leave = banners.leave()
        _ = await helper.first(3)
        let launched = helper.launches

        banners.heard(Self.fromHelper(.ready(helper: Self.second)))

        #expect(await leave == nil)
        #expect(helper.messages.last == .ready)
        #expect(helper.launches == launched + 1)

        banners.helperEnded(Self.first)
        banners.post(Self.asked)

        #expect(helper.launches == launched + 2)
        #expect(helper.messages.last == .post(Notice(
            title: "Pick a name", subtitle: "SitRep · Build the Mac app", body: "", work: "sr-aw3bgs"
        )))
    }

    /// The jump for a relayed click refused, the helper is told to hand the front back.
    @Test func aRefusedJumpForAClickHandsTheFrontBack() {
        let banners = banners()

        banners.heard(Self.fromHelper(Self.ready))
        banners.heard(Self.fromHelper(.clicked(work: "sr-gone")))

        #expect(helper.messages.last == .ready)

        clicks.refused?()

        #expect(helper.messages.last == .handBack)
    }

    /// Given up on, it is not sent to a helper that comes later, nor kept waiting for one that never does.
    @Test func aReadGivenUpOnIsNotSentLater() async {
        let banners = banners(answerWithin: .milliseconds(1))

        #expect(await banners.leave() == nil)

        banners.heard(Self.fromHelper(Self.ready))

        #expect(helper.messages == [.ready, .ready])
    }

    /// An ask the helper that ended was never sent waits for the next, so Settings reads again only once Lee answers.
    @Test func theHelperEndingLeavesAnAskNotYetSentForTheNext() async {
        let banners = banners()
        let asked = Asked()
        let asking = Task {
            await banners.ask()
            asked.isDone = true
        }

        while helper.launches < 2 {
            await Task.yield()
        }
        banners.helperEnded(Self.first)
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        #expect(!asked.isDone)

        banners.heard(Self.fromHelper(Self.ready))

        #expect(helper.messages.last == .ask(id: helper.lastId!))

        banners.heard(Self.fromHelper(.status(.allowed(.banners), id: helper.lastId!)))
        await asking.value

        #expect(asked.isDone)
    }
}
