@testable import SitRepCore
import Testing

struct BannerTests {
    private static let fumi = OnScreen(id: "sr-047c7y", project: "Fumi", name: "Management window discussion")
    private static let switchboard = OnScreen(id: "sr-y4d0qj", project: "Switchboard", name: "Milestone 7 stages 4 to 14")

    @Test func theTestBannerNamesTheFirstWorkOnScreenAndJumpsToIt() {
        let banner = Banner.test(.works([Self.fumi, Self.switchboard]))

        #expect(banner.title == "Management window discussion")
        #expect(banner.subtitle == "Fumi")
        #expect(banner.work == "sr-047c7y")
    }

    @Test func withNoWorkOnScreenTheTestBannerJumpsNowhere() {
        let banner = Banner.test(.works([]))

        #expect(banner.work == nil)
        #expect(banner.body == "A test banner. No session is on screen, so it jumps nowhere.")
    }

    @Test func aListThatFailedGivesATestBannerWithItsWordsAndNoJump() {
        let banner = Banner.test(.failed("sitrep list did not answer within 10 seconds."))

        #expect(banner.work == nil)
        #expect(banner.body == "A test banner, with no session to jump to: sitrep list did not answer within 10 seconds.")
    }

    @Test func aFailedJumpShowsTheCLIsWordsAndJumpsNowhere() {
        let banner = Banner.unjumped("Fumi is not on screen: no Ghostty window shows it.")

        #expect(banner == Banner(title: "SitRep could not jump", subtitle: nil, body: "Fumi is not on screen: no Ghostty window shows it.", work: nil))
    }
}
