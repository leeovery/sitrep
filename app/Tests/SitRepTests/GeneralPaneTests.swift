import AppKit
import Foundation
@testable import SitRep
import SitRepLines
import Testing

/// Settings' General: Startup and Ghostty, and no longer "Your turn folds after", retired with "N earlier" on 4 November
/// 2026, as the card shows every your-turn row (board J).
@MainActor
struct GeneralPaneTests {
    @Test func itOffersNoFoldPeriod() async throws {
        let settings = await Hosted.settings(defaults: MemoryDefaults())
        let hosted = Hosted(Hosted.content(.general, settings), size: CGSize(width: 744, height: 620))

        #expect(hosted.all(NSPopUpButton.self).isEmpty)
        #expect(hosted.all(NSSwitch.self).count == 1)
    }
}
