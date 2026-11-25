@testable import SitRepNotices
import SitRepRelay
import SitRepTestSupport
import Testing

/// The helper between SitRep and macOS's notifications, over a SitRep and a macOS of its own: nothing is posted,
/// launched or relayed for real.
@MainActor
@Suite(.backstop)
struct HelperTests {
    private static let sitRep: Int32 = 4012
    private static let ownPid: Int32 = 5150
    private static let ready = ToSitRep.ready(helper: ownPid)

    /// What the helper asks of macOS, the first post held until `release` lets it go.
    @MainActor
    final class Mac: Notifying {
        var posted: [Notice] = []
        var asks = 0
        var leaveNow = NoticeLeave.allowed(.banners)
        var leaveAsked = NoticeLeave.denied
        var holdsFirstPost = false
        private var held: CheckedContinuation<Void, Never>?

        var isHolding: Bool { held != nil }

        func post(_ notice: Notice) async {
            if holdsFirstPost, posted.isEmpty, held == nil {
                await withCheckedContinuation { held = $0 }
            }
            posted.append(notice)
            done.append("post \(notice.title)")
        }

        /// What it posted and cleared, in order.
        var done: [String] = []

        func clear(ask: String, session: String) async {
            done.append("clear \(ask) of \(session)")
        }

        /// Once `count` banners are posted.
        func posts(_ count: Int) async -> [Notice] {
            await until(turns: 10_000) { posted.count >= count }
            return posted
        }

        func leave() async -> NoticeLeave {
            leaveNow
        }

        func ask() async -> NoticeLeave {
            asks += 1

            return leaveAsked
        }

        func release() {
            held?.resume()
        }
    }

    /// The SitRep the helper serves: running, or started by it.
    @MainActor
    final class SitRep: SitRepApp {
        var isRunning: Bool
        var starts: Bool
        var launches = 0
        var watched: Int32?
        var end: (@MainActor () -> Void)?

        init(isRunning: Bool, starts: Bool = true) {
            self.isRunning = isRunning
            self.starts = starts
        }

        func running() -> Int32? {
            isRunning ? HelperTests.sitRep : nil
        }

        func launch() async -> Int32? {
            launches += 1

            return starts ? HelperTests.sitRep : nil
        }

        func watch(_ pid: Int32, ended: @escaping @MainActor () -> Void) {
            watched = pid
            end = ended
        }
    }

    /// What the helper sent SitRep, waited on.
    @MainActor
    final class Sent {
        private(set) var messages: [ToSitRep] = []
        private(set) var pids: Set<Int32> = []
        private var waiter: (@Sendable (()) -> Void)?

        func put(_ letter: Letter<ToSitRep>) {
            messages.append(letter.message)
            pids.insert(letter.pid)
            waiter?(())
            waiter = nil
        }

        /// Once `count` messages are sent; the next not sent within the time ends the test.
        func first(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async throws -> [ToSitRep] {
            while messages.count < count {
                try await answer(
                    within: .seconds(10), "for message \(messages.count + 1) to be sent", sourceLocation: sourceLocation
                ) { waiter = $0 }
            }

            return messages
        }
    }

    @MainActor
    final class Calls {
        var quits = 0
        var handBacks = 0
    }

    private let mac = Mac()
    private let sent = Sent()
    private let calls = Calls()

    private func helper(_ sitRep: SitRep) -> Helper {
        Helper(
            notifications: mac, sitRep: sitRep, send: sent.put,
            own: Helper.Own(
                pid: Self.ownPid, quit: { [calls] in calls.quits += 1 }, handBack: { [calls] in calls.handBacks += 1 }
            )
        )
    }

    private static func fromSitRep(_ message: ToHelper, pid: Int32 = sitRep) -> Letter<ToHelper> {
        Letter(message, pid: pid)
    }

    /// An ask of Trey Research's Build the desktop app.
    private static func ask(_ id: String, wants: NoticeAsk.Wants) -> NoticeAsk {
        NoticeAsk(
            id: id, session: "sr-a8n2xc", title: "Pick a name", place: "Trey Research · Build the desktop app",
            wants: wants
        )
    }

    /// Started by SitRep, it finds SitRep running and says it listens, under SitRep's pid.
    @Test func itServesTheSitRepRunningAndSaysItListens() async {
        let sitRep = SitRep(isRunning: true)
        let helper = helper(sitRep)

        await helper.start()

        #expect(sitRep.launches == 0)
        #expect(sitRep.watched == Self.sitRep)
        #expect(sent.messages == [Self.ready])
        #expect(sent.pids == [Self.sitRep])
    }

    @Test func itQuitsAsSitRepEnds() async {
        let sitRep = SitRep(isRunning: true)
        let helper = helper(sitRep)

        await helper.start()
        #expect(calls.quits == 0)
        sitRep.end?()

        #expect(calls.quits == 1)
    }

    /// As "SitRep could not jump" or the test with no window holding a session: nothing jumps, so the front goes back
    /// to the app Lee was in.
    @Test func aClickOnABannerNamingNoSessionHandsTheFrontBack() async {
        let helper = helper(SitRep(isRunning: true))

        await helper.start()
        helper.heard(Self.fromSitRep(.ready))
        helper.clicked(nil)

        #expect(calls.handBacks == 1)
        #expect(sent.messages == [Self.ready, Self.ready])
    }

    @Test func aClickNamingASessionKeepsTheFrontForTheJump() async {
        let helper = helper(SitRep(isRunning: true))

        await helper.start()
        helper.heard(Self.fromSitRep(.ready))
        helper.clicked("sr-a8n2xc")

        #expect(calls.handBacks == 0)
    }

    /// SitRep refused the jump for a click the helper relayed: nothing jumps, so the front goes back.
    @Test func itHandsTheFrontBackWhenSitRepSays() async {
        let helper = helper(SitRep(isRunning: true))

        await helper.start()
        helper.heard(Self.fromSitRep(.handBack))

        #expect(calls.handBacks == 1)
    }

    @Test func anotherSitRepCannotTakeTheFront() async {
        let helper = helper(SitRep(isRunning: true))

        await helper.start()
        helper.heard(Self.fromSitRep(.handBack, pid: 977))

        #expect(calls.handBacks == 0)
    }

    @Test func aClickIsRelayedToSitRep() async {
        let helper = helper(SitRep(isRunning: true))

        await helper.start()
        helper.heard(Self.fromSitRep(.ready))
        helper.clicked("sr-a8n2xc")

        #expect(sent.messages.last == .clicked(work: "sr-a8n2xc"))
        #expect(sent.pids == [Self.sitRep])
    }

    /// The click that started the helper, with SitRep not running: SitRep is started, and the click waits for it.
    @Test func aClickWithNoSitRepStartsItAndIsHandedOverOnceItListens() async {
        let sitRep = SitRep(isRunning: false)
        let helper = helper(sitRep)

        helper.clicked("sr-a8n2xc")
        await helper.start()

        #expect(sitRep.launches == 1)
        #expect(sitRep.watched == Self.sitRep)
        #expect(sent.messages == [Self.ready])

        helper.heard(Self.fromSitRep(.ready))

        #expect(sent.messages == [Self.ready, Self.ready, .clicked(work: "sr-a8n2xc")])
    }

    /// A banner's button answers through SitRep. Nothing jumps, so the front is handed back, should macOS have made
    /// the helper active for the press.
    @Test func aBannersAnswerIsRelayedToSitRepAndTheFrontHandedBack() async {
        let helper = helper(SitRep(isRunning: true))
        let answer = NoticeAnswer(to: Self.ask("k2", wants: .choice(["Right"])), words: "Right")

        await helper.start()
        helper.heard(Self.fromSitRep(.ready))
        helper.answered(answer)

        #expect(sent.messages.last == .answered(answer))
        #expect(sent.pids == [Self.sitRep])
        #expect(calls.handBacks == 1)
    }

    /// The button that started the helper, with SitRep not running: SitRep is started, and the answer, with any click
    /// before it, waits for it, in order.
    @Test func anAnswerWithNoSitRepStartsItAndIsHandedOverInOrderOnceItListens() async {
        let sitRep = SitRep(isRunning: false)
        let helper = helper(sitRep)
        let answer = NoticeAnswer(to: Self.ask("k3", wants: .words), words: "12 passed, 0 failed")

        helper.clicked("sr-a8n2xc")
        helper.answered(answer)
        await helper.start()

        #expect(sitRep.launches == 1)
        #expect(sent.messages == [Self.ready])

        helper.heard(Self.fromSitRep(.ready))
        helper.heard(Self.fromSitRep(.ready))

        #expect(sent.messages == [Self.ready, Self.ready, .clicked(work: "sr-a8n2xc"), .answered(answer), Self.ready])
    }

    @Test func withNoSitRepToStartItQuits() async {
        let helper = helper(SitRep(isRunning: false, starts: false))

        await helper.start()

        #expect(calls.quits == 1)
        #expect(sent.messages.isEmpty)
    }

    /// SitRep may have missed the helper's ready, so each of SitRep's is answered, as SitRep says it again while it has
    /// not heard the helper; SitRep answers only the helper's first, so the two stop. A click held goes once.
    @Test func itAnswersEachOfSitRepsReadies() async {
        let helper = helper(SitRep(isRunning: false))

        helper.clicked("sr-a8n2xc")
        await helper.start()
        helper.heard(Self.fromSitRep(.ready))
        helper.heard(Self.fromSitRep(.ready))

        #expect(sent.messages == [Self.ready, Self.ready, .clicked(work: "sr-a8n2xc"), Self.ready])
    }

    /// Passed over, the other's banner is never posted: one of its own SitRep's, posted in order after it, is the first.
    @Test func aLetterFromAnotherSitRepIsPassedOver() async {
        let helper = helper(SitRep(isRunning: true))
        let own = Notice(title: "Own", subtitle: nil, body: "", work: nil)

        await helper.start()
        helper.heard(Self.fromSitRep(.ready, pid: 977))
        helper.heard(Self.fromSitRep(.post(Notice(title: "Stale", subtitle: nil, body: "", work: nil)), pid: 977))
        helper.clicked("sr-a8n2xc")
        helper.heard(Self.fromSitRep(.post(own)))

        #expect(sent.messages == [Self.ready])
        #expect(await mac.posts(1) == [own])
    }

    @Test func beforeItKnowsItsSitRepNoLetterIsHeard() {
        let helper = helper(SitRep(isRunning: true))

        helper.heard(Self.fromSitRep(.ready))

        #expect(sent.messages.isEmpty)
    }

    @Test func itPostsInTheOrderSitRepSent() async {
        let helper = helper(SitRep(isRunning: true))
        let first = Notice(title: "First", subtitle: nil, body: "", work: "sr-1")
        let second = Notice(title: "Second", subtitle: nil, body: "", work: "sr-2")

        mac.holdsFirstPost = true
        await helper.start()
        helper.heard(Self.fromSitRep(.post(first)))
        helper.heard(Self.fromSitRep(.post(second)))
        await until(turns: 10_000) { mac.isHolding }
        #expect(mac.posted.isEmpty)

        mac.release()

        #expect(await mac.posts(2) == [first, second])
    }

    /// An ask's banners are cleared in turn with the posts SitRep sent before, so one posted then cleared goes.
    @Test func itClearsAnAsksBannersInTheOrderSitRepSent() async {
        let helper = helper(SitRep(isRunning: true))
        let first = Notice(title: "First", subtitle: nil, body: "", work: "sr-1")

        mac.holdsFirstPost = true
        await helper.start()
        helper.heard(Self.fromSitRep(.post(first)))
        helper.heard(Self.fromSitRep(.cleared(ask: "k1", session: "sr-1")))
        await until(turns: 10_000) { mac.isHolding }
        #expect(mac.done.isEmpty)

        mac.release()
        await until(turns: 10_000) { mac.done.count == 2 }

        #expect(mac.done == ["post First", "clear k1 of sr-1"])
    }

    @Test func itAnswersAStatusWithMacOSsLeaveUnderItsId() async throws {
        let helper = helper(SitRep(isRunning: true))

        await helper.start()
        helper.heard(Self.fromSitRep(.status(id: "a")))

        #expect(try await sent.first(2).last == .status(.allowed(.banners), id: "a"))
        #expect(mac.asks == 0)
    }

    @Test func itAsksMacOSThenAnswersWithTheLeaveUnderItsId() async throws {
        let helper = helper(SitRep(isRunning: true))

        await helper.start()
        helper.heard(Self.fromSitRep(.ask(id: "b")))

        #expect(try await sent.first(2).last == .status(.denied, id: "b"))
        #expect(mac.asks == 1)
    }
}
