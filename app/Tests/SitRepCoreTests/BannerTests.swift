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

    /// A failed jump posts a banner, refused or given no answer in time; one that jumped or opened a window posts none,
    /// nor one with a window still to open, one opening already, or one a later click stopped, as that one goes on.
    @Test func onlyAFailedJumpPostsABanner() {
        #expect(JumpAnswer.refused("Fumi is not on screen.").banner == .unjumped("Fumi is not on screen."))
        #expect(JumpAnswer.unanswered.banner == .tooBusy)
        for answer in [JumpAnswer.jumped, .openable, .opened, .opening, .stopped] {
            #expect(answer.banner == nil)
        }
    }

    /// A window brought forward with a word for Lee, SitRep starting nothing there, says why.
    @Test func aJumpLandingWithAWordPostsItAsStartingNothing() {
        #expect(
            JumpAnswer.jumpedSaying("Fumi is suspended in this window: type fg to bring it back.").banner
                == Banner(
                    title: "SitRep started nothing", subtitle: nil,
                    body: "Fumi is suspended in this window: type fg to bring it back.", work: nil
                )
        )
    }

    /// A window that could not be opened says so, with why.
    @Test func aWindowNotOpenedPostsABannerSayingSoWithWhy() {
        #expect(
            JumpAnswer.unopened("Set an open command.").banner
                == Banner(title: "SitRep could not open a window", subtitle: nil, body: "Set an open command.", work: nil)
        )
    }
}
