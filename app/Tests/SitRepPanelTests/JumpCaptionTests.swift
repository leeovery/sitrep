@testable import SitRepPanel
import Testing

/// The caption a jump leaves, as the prototypes show it: where it jumped, 90ms into the drain once the jump has
/// jumped; in over 160ms dropping 4 into place, held, and out from 1350, gone by 1600.
struct JumpCaptionTests {
    @Test func itSaysWhichProjectsWindowItJumpedTo() {
        #expect(JumpCaption(to: "SitRep").text == "Jumped to SitRep's window")
    }

    @Test func itShows90msIntoTheDrainOnceTheJumpHasJumped() {
        var caption = JumpCaption(to: "SitRep")
        #expect(caption.showsAt == nil)

        caption.jumped(at: 1050)
        #expect(caption.showsAt == nil)
        caption.drained(at: 1000)

        #expect(caption.showsAt == 1090)
    }

    @Test func aJumpAnsweringAfterThatShowsItAsItAnswers() {
        var caption = JumpCaption(to: "SitRep")

        caption.drained(at: 1000)
        caption.jumped(at: 1500)

        #expect(caption.showsAt == 1500)
    }

    @Test func theDrainCountsFromWhenItBegan() {
        var caption = JumpCaption(to: "SitRep")

        caption.drained(at: 1000)
        caption.drained(at: 1200)
        caption.jumped(at: 1000)

        #expect(caption.showsAt == 1090)
    }

    @Test func itShowsWhenItsMomentComesAndNeverOnceItHasPassed() {
        var caption = JumpCaption(to: "SitRep")
        #expect(caption.showsIn(at: 1000) == nil)

        caption.drained(at: 1000)
        caption.jumped(at: 1010)

        #expect(caption.showsIn(at: 1010) == 80)
        #expect(caption.showsIn(at: 1090) == 0)
        #expect(caption.showsIn(at: 1140) == 0)
        #expect(caption.showsIn(at: 1141) == nil)
        #expect(caption.showsIn(at: 1090 + 60_000) == nil)
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
