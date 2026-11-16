@testable import SitRepCore
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct BannerTests {
    @Test func aFailedJumpShowsTheCLIsWordsAndJumpsNowhere() {
        let banner = Banner.unjumped("Wingtip is not on screen: no Ghostty window shows it.")

        #expect(banner == Banner(title: "SitRep could not jump", subtitle: nil, body: "Wingtip is not on screen: no Ghostty window shows it.", work: nil))
    }

    @Test func aJumpGivenNoAnswerInTimeSaysTheMacIsTooBusy() {
        #expect(Banner.tooBusy == Banner(
            title: "SitRep could not jump", subtitle: nil, body: "The Mac is too busy to jump.", work: nil
        ))
    }

    /// A failed jump posts a banner, refused or given no answer in time; one that jumped or opened a window posts none,
    /// nor one with a window still to open, one opening already, or one a later click stopped, as that one goes on.
    @Test func onlyAFailedJumpPostsABanner() {
        #expect(JumpAnswer.refused("Wingtip is not on screen.").banner == .unjumped("Wingtip is not on screen."))
        #expect(JumpAnswer.unanswered.banner == .tooBusy)
        for answer in [JumpAnswer.jumped, .openable, .opened, .opening, .stopped] {
            #expect(answer.banner == nil)
        }
    }

    /// A window brought forward with a word for Lee, SitRep starting nothing there, says why.
    @Test func aJumpLandingWithAWordPostsItAsStartingNothing() {
        let said = "Wingtip is suspended in this window: type fg to bring it back."
        let answer = JumpAnswer.jumpedSaying(said)

        #expect(answer.banner == Banner(title: "SitRep started nothing", subtitle: nil, body: said, work: nil))
        #expect(!answer.handsBack)
    }

    /// A window that could not be opened says so, with why.
    @Test func aWindowNotOpenedPostsABannerSayingSoWithWhy() {
        let why = "SitRep opens a window only in a Ghostty already running. Open Ghostty, then click Wingtip again."

        #expect(
            JumpAnswer.unopened(why).banner
                == Banner(title: "SitRep could not open a window", subtitle: nil, body: why, work: nil)
        )
    }
}
