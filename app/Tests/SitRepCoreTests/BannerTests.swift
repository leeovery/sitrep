@testable import SitRepCore
import Testing

struct BannerTests {
    @Test func aFailedJumpShowsTheCLIsWordsAndJumpsNowhere() {
        let banner = Banner.unjumped("Fumi is not on screen: no Ghostty window shows it.")

        #expect(banner == Banner(title: "SitRep could not jump", subtitle: nil, body: "Fumi is not on screen: no Ghostty window shows it.", work: nil))
    }
}
