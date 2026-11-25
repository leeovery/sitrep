@testable import SitRepNotices
import SitRepRelay
import SitRepTestSupport
import Testing
import UserNotifications

/// Each banner posted with no buttons, carrying the session its click jumps to and the ask it tells of; and the banners
/// of an ask that waits on Lee no more taken down. Over a notification center of the test's own.
@MainActor
@Suite(.backstop)
struct PosterTests {
    /// What the poster asked of the center, in order.
    enum Step: Equatable {
        case delivered
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

        func add(_ request: UNNotificationRequest) async throws {
            steps.append(.add(id: request.identifier, category: request.content.categoryIdentifier))
            added.append(request)
        }

        func remove(_ ids: [String]) {
            steps.append(.remove(ids))
        }
    }

    private static let ask = NoticeAsk(id: "k1", session: "sr-nw0001")
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

    @Test func aBannerWithNoAskIsAddedAndCarriesItsSessionAlone() async {
        await poster().post(Notice(title: "Stopped", subtitle: "Northwind · Ledger export", body: "", work: "sr-nw0001"))

        #expect(center.steps == [.add(id: "b1", category: "")])
        #expect(center.added[0].content.userInfo as? [String: String] == ["work": "sr-nw0001"])
    }

    /// A new ask's banner has no buttons, as every banner: a click on it jumps to its session, and it carries its ask,
    /// to be found and taken down by.
    @Test func aNewAsksBannerIsAddedWithNoButtonsCarryingItsSessionAndItsAsk() async {
        await poster().post(Self.asking)

        #expect(center.steps == [.add(id: "b1", category: "")])
        #expect(BannerInfo.ask(center.added[0].content.userInfo) == Self.ask)
        #expect(BannerInfo.work(center.added[0].content.userInfo) == "sr-nw0001")
    }

    /// The test notification, a refusal's, and any other naming no session carry nothing.
    @Test func aBannerNamingNoSessionCarriesNothing() async {
        await poster().post(Notice(title: "Not answered", subtitle: nil, body: "Answered already", work: nil))

        #expect(center.added[0].content.userInfo.isEmpty)
    }

    /// An ask that waits on Lee no more: every banner of it still delivered goes, found by the ask and session it
    /// carries, and no other, a like id in another session's among them.
    @Test func clearingAnAskRemovesItsDeliveredBannersAlone() async {
        center.delivered = [
            "a1": Self.ask, "a2": Self.ask, "a3": NoticeAsk(id: "k1", session: "sr-nw0002"),
            "a4": NoticeAsk(id: "k2", session: "sr-nw0001"),
        ]

        await poster().clear(ask: "k1", session: "sr-nw0001")

        #expect(center.steps == [.delivered, .remove(["a1", "a2"])])
    }

    @Test func clearingAnAskWithNoBannerDeliveredRemovesNothing() async {
        center.delivered = ["a4": NoticeAsk(id: "k2", session: "sr-nw0001")]

        await poster().clear(ask: "k1", session: "sr-nw0001")

        #expect(center.steps == [.delivered])
    }
}
