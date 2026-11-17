@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The caption a jump leaves, as the prototypes show it: where it jumped, 90ms into the drain once the jump has
/// jumped; in over 160ms dropping 4 into place, held, and out from 1350, gone by 1600.
@Suite(.backstop)
struct JumpCaptionTests {
    @Test func itSaysWhichProjectsWindowItJumpedTo() {
        #expect(JumpCaption(to: "Trey Research").text == "Jumped to Trey Research's window")
    }

    /// A window opened for a session no window shows says so, as does one asked for a moment ago that no terminal
    /// shows it in yet, as it landed first: a later answer changes nothing.
    @Test(arguments: [
        (JumpCaption.Landing.jumped, "Jumped to Trey Research's window"), (.opened, "Opened a window for Trey Research"),
        (.opening, "A window for Trey Research is opening"),
    ])
    func itSaysHowTheJumpLanded(landing: JumpCaption.Landing, text: String) {
        var caption = JumpCaption(to: "Trey Research")

        caption.landed(landing, at: 1000)
        caption.landed(.jumped, at: 1100)
        #expect(caption.text == text)
        #expect(caption.showsAt == nil)
        caption.drained(at: 1000)
        #expect(caption.showsAt == 1090)
    }

    @Test func itShows90msIntoTheDrainOnceTheJumpHasJumped() {
        var caption = JumpCaption(to: "Trey Research")
        #expect(caption.showsAt == nil)

        caption.jumped(at: 1050)
        #expect(caption.showsAt == nil)
        caption.drained(at: 1000)

        #expect(caption.showsAt == 1090)
    }

    @Test func aJumpAnsweringAfterThatShowsItAsItAnswers() {
        var caption = JumpCaption(to: "Trey Research")

        caption.drained(at: 1000)
        caption.jumped(at: 1500)

        #expect(caption.showsAt == 1500)
    }

    @Test func theDrainCountsFromWhenItBegan() {
        var caption = JumpCaption(to: "Trey Research")

        caption.drained(at: 1000)
        caption.drained(at: 1200)
        caption.jumped(at: 1000)

        #expect(caption.showsAt == 1090)
    }

    @Test func itShowsWhenItsMomentComesAndNeverOnceItHasPassed() {
        var caption = JumpCaption(to: "Trey Research")
        #expect(caption.showsIn(at: 1000) == nil)

        caption.drained(at: 1000)
        caption.jumped(at: 1010)

        #expect(caption.showsIn(at: 1010) == 80)
        #expect(caption.showsIn(at: 1090) == 0)
        #expect(caption.showsIn(at: 1140) == 0)
        #expect(caption.showsIn(at: 1141) == nil)
        #expect(caption.showsIn(at: 1090 + 60_000) == nil)
    }

    /// A caption plays whole over a clear pill, or held until its jump ends only coming in; over a pill already part
    /// opaque, coming in or going, from the moment its coming in is as opaque, so it never jumps; over one whole, from
    /// its hold, where held it plays nothing.
    @Test func aCaptionComesInFromThePillsOpacity() {
        #expect(JumpCaption.part(holding: false, from: 0) == 0 ... 1600)
        #expect(JumpCaption.part(holding: true, from: 0) == 0 ... 160)
        #expect(JumpCaption.part(holding: false, from: 1) == 160 ... 1600)
        #expect(JumpCaption.part(holding: true, from: 1) == 160 ... 160)

        let half = JumpCaption.part(holding: false, from: 0.5).lowerBound

        #expect(abs(JumpCaption.look(half).alpha - 0.5) < 1e-9)
    }

    /// A held caption goes from the opacity it has: whole, from the caption's own going; cut short coming in, from as
    /// far into the going as matches it, so it never flashes whole first.
    @Test func aHeldCaptionGoesFromItsOpacity() {
        #expect(JumpCaption.going(from: 1) == 1350 ... 1600)
        #expect(JumpCaption.going(from: 0) == 1600 ... 1600)

        let half = JumpCaption.going(from: 0.5).lowerBound

        #expect(abs(JumpCaption.look(half).alpha - 0.5) < 1e-9)
    }

    @Test func itFadesInDroppingIntoPlaceHoldsAndRisesAsItFades() {
        #expect(JumpCaption.look(0) == (0, 4))
        #expect(JumpCaption.look(80).alpha == 1 - 0.125)
        #expect(JumpCaption.look(160) == (1, 0))
        #expect(JumpCaption.look(1350) == (1, 0))
        #expect(JumpCaption.look(1475) == (0.5, 2))
        #expect(JumpCaption.look(1600) == (0, 4))
        #expect(JumpCaption.length == 1600)
    }
}
