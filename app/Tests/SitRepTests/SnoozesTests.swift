import Foundation
@testable import SitRep
import SitRepCore
import SitRepPanel
import SitRepTestSupport
import Testing

/// Lee's snoozes from a row's menu and the asks panel's Snooze ▾, as `Snoozes` takes them: a time come already
/// snoozes nothing, a banner saying so.
@MainActor
@Suite(.backstop)
struct SnoozesTests {
    /// The banners posted, in order.
    private final class Posted {
        var banners: [Banner] = []
    }

    /// Tonight on a menu opened before 18:00 and chosen after: the time its item showed has come, so the banner says
    /// so in the pane's words, at once, with nothing asked of the CLI first.
    @Test func aTimeComeAlreadyPostsTheBannerAndSnoozesNothing() {
        let posted = Posted()
        let snoozes = Snoozes(plugin: Plugin(), post: { posted.banners.append($0) })
        let until = Date().addingTimeInterval(-30)

        snoozes.snoozeRow("sr-4t2kq8", showing: ["k1"], until)

        let words = WakeTime.words(until, at: Date(), in: WakeTime.calendar)

        #expect(posted.banners == [.unsnoozed("\(words) has come already.")])
    }

    /// So with one ask snoozed from the asks panel's Snooze ▾.
    @Test func anAsksTimeComeAlreadyPostsTheBannerAndSnoozesNothing() {
        let posted = Posted()
        let snoozes = Snoozes(plugin: Plugin(), post: { posted.banners.append($0) })
        let until = Date().addingTimeInterval(-30)

        snoozes.snoozeAsk("sr-4t2kq8", ask: "k1", until)

        let words = WakeTime.words(until, at: Date(), in: WakeTime.calendar)

        #expect(posted.banners == [.unsnoozed("\(words) has come already.")])
    }
}
