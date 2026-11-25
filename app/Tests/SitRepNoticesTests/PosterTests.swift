@testable import SitRepNotices
import SitRepRelay
import SitRepTestSupport
import Testing
import UserNotifications

/// Each banner posted, a new ask's under a category of its own, the whole set built from the banners delivered and
/// those lately posted, and landed before the banner is added. Over a notification center of the test's own.
@MainActor
@Suite(.backstop)
struct PosterTests {
    /// What the poster asked of the center, in order.
    enum Step: Equatable {
        case delivered
        case set([String])
        /// The read that waits for the last set to land.
        case barrier
        case add(id: String, category: String)
        case remove([String])
    }

    @MainActor
    final class Center: BannerCenter {
        var delivered: [String: NoticeAsk] = [:]
        private(set) var steps: [Step] = []
        private(set) var added: [UNNotificationRequest] = []

        func deliveredAsks() async -> [String: NoticeAsk] {
            steps.append(.delivered)
            return delivered
        }

        func setCategories(_ categories: Set<UNNotificationCategory>) {
            steps.append(.set(categories.map(\.identifier).sorted()))
        }

        func categories() async -> Set<UNNotificationCategory> {
            steps.append(.barrier)
            return []
        }

        func add(_ request: UNNotificationRequest) async throws {
            steps.append(.add(id: request.identifier, category: request.content.categoryIdentifier))
            added.append(request)
        }

        func remove(_ ids: [String]) {
            steps.append(.remove(ids))
        }

        /// The ids of the last set registered.
        var lastSet: [String] {
            steps.reversed().lazy.compactMap { if case let .set(ids) = $0 { ids } else { nil } }.first ?? []
        }
    }

    private static let ask = NoticeAsk(id: "k1", session: "sr-nw0001", wants: .yes("Go"))
    private static let asking = Notice(
        title: "Pick the export format", subtitle: "Northwind · Ledger export", body: "", work: "sr-nw0001", ask: ask
    )

    private let center = Center()

    /// Ids b1, b2, … in the order the banners post.
    private func poster() -> Poster {
        var count = 0

        return Poster(center: center) {
            count += 1
            return "b\(count)"
        }
    }

    @Test func aBannerWithNoAskIsAddedWithNoCategoryAndNoSet() async {
        await poster().post(Notice(title: "Stopped", subtitle: "Northwind · Ledger export", body: "", work: "sr-nw0001"))

        #expect(center.steps == [.add(id: "b1", category: "")])
    }

    /// Its set registered, then landed, then the banner added under its category.
    @Test func aNewAsksBannerIsAddedOnlyOnceItsCategoryHasLanded() async {
        center.delivered = ["b0": NoticeAsk(id: "k0", session: "sr-nw0001", wants: .words)]

        await poster().post(Self.asking)

        #expect(center.steps == [.delivered, .set(["b0", "b1"]), .barrier, .add(id: "b1", category: "b1")])
        #expect(Buttons.ask(center.added[0].content.userInfo) == Self.ask)
        #expect(Buttons.work(center.added[0].content.userInfo) == "sr-nw0001")
    }

    /// Two posted back to back: the first keeps its buttons though Notification Center does not list it yet.
    @Test func aBannerJustPostedKeepsItsCategoryThoughNotListedAsDelivered() async {
        let poster = poster()

        await poster.post(Self.asking)
        await poster.post(Self.asking)

        #expect(center.lastSet == ["b1", "b2"])
    }

    /// A helper started again knows nothing it posted: the banners delivered keep their buttons all the same.
    @Test func aBannerDeliveredBeforeTheHelperStartedKeepsItsCategory() async {
        center.delivered = ["a1": Self.ask, "a2": NoticeAsk(id: "k2", session: "sr-nw0001", wants: .choice(["Left"]))]

        await poster().post(Self.asking)

        #expect(center.lastSet == ["a1", "a2", "b1"])
    }

    /// A banner neither delivered nor lately posted gives its category up, so the set stays bounded.
    @Test func onlyTheLastTenPostedAreKeptBeyondThoseDelivered() async {
        let poster = poster()

        for _ in 0 ..< Poster.keptRecent + 2 {
            await poster.post(Self.asking)
        }

        #expect(center.lastSet == (3 ... 12).map { "b\($0)" }.sorted())
    }

    /// An ask that waits on Lee no more: every banner of it still delivered goes, found by the ask and session it
    /// carries, and no other, a like id in another session's among them.
    @Test func clearingAnAskRemovesItsDeliveredBannersAlone() async {
        center.delivered = [
            "a1": Self.ask, "a2": Self.ask, "a3": NoticeAsk(id: "k1", session: "sr-nw0002", wants: .words),
            "a4": NoticeAsk(id: "k2", session: "sr-nw0001", wants: .words),
        ]

        await poster().clear(ask: "k1", session: "sr-nw0001")

        #expect(center.steps == [.delivered, .remove(["a1", "a2"])])
    }

    @Test func clearingAnAskWithNoBannerDeliveredRemovesNothing() async {
        center.delivered = ["a4": NoticeAsk(id: "k2", session: "sr-nw0001", wants: .words)]

        await poster().clear(ask: "k1", session: "sr-nw0001")

        #expect(center.steps == [.delivered])
    }
}
