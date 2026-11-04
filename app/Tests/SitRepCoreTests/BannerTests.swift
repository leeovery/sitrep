@testable import SitRepCore
import Testing

struct BannerTests {
    @Test func aFailedJumpShowsTheCLIsWordsAndJumpsNowhere() {
        let banner = Banner.unjumped("Fumi is not on screen: no Ghostty window shows it.")

        #expect(banner == Banner(title: "SitRep could not jump", subtitle: nil, body: "Fumi is not on screen: no Ghostty window shows it.", work: nil))
    }

    @Test func aJumpGivenNoAnswerInTimeSaysTheMacIsTooBusy() {
        #expect(Banner.tooBusy == Banner(
            title: "SitRep could not jump", subtitle: nil, body: "The Mac is too busy to jump.", work: nil
        ))
    }

    /// A failed jump posts a banner, refused or given no answer in time; one that jumped posts none, nor one a later
    /// click stopped, as that one goes on.
    @Test func onlyAFailedJumpPostsABanner() {
        #expect(JumpAnswer.refused("Fumi is not on screen.").banner == .unjumped("Fumi is not on screen."))
        #expect(JumpAnswer.unanswered.banner == .tooBusy)
        #expect(JumpAnswer.jumped.banner == nil)
        #expect(JumpAnswer.stopped.banner == nil)
    }
}
