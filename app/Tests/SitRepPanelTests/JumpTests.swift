import CoreGraphics
@testable import SitRepPanel
import Testing

/// A click on a row, Meniscus and the card alike (DESIGN, "The panel"): the row presses in and spins until the jump
/// answers, for 450ms at most, and then the panel drains. Only an open or opening panel takes the click, one jump at
/// a time, and nothing else closes the panel while the row is pressed in.
struct JumpTests {
    @Test func aClickedRowIsPressedInUntilThePanelDrainsAt450() {
        pressesInAndDrainsAt450(Lab())
        pressesInAndDrainsAt450(CardLab())
    }

    @Test func aJumpThatAnswersSoonerDrainsThePanelThen() {
        drainsAsTheJumpAnswers(Lab())
        drainsAsTheJumpAnswers(CardLab())
    }

    @Test func anAnswerAfterTheDrainChangesNothing() {
        answerAfterTheDrain(Lab())
        answerAfterTheDrain(CardLab())
    }

    @Test func aClosingPanelTakesNoClick() {
        closingTakesNoClick(Lab())
        closingTakesNoClick(CardLab())
    }

    @Test func aClosedPanelTakesNoClick() {
        var lab = Lab(), card = CardLab()

        #expect(!lab.model.clickRow(0))
        #expect(!card.model.clickRow(0))
        lab.step()
        card.step()
        #expect(lab.model.jumping == nil && card.model.jumping == nil)
    }

    /// DESIGN's rule for the open panel holds while a row is pressed in: a click elsewhere closes it at once.
    @Test func aClickElsewhereClosesThePanelWhileARowIsPressedIn() {
        var lab = Lab(), card = CardLab()
        lab.openByTouch()
        card.openByTouch()
        lab.model.clickRow(0)
        card.model.clickRow(0)

        lab.model.clickElsewhere()
        card.model.clickElsewhere()

        #expect(lab.phase == .closing && card.phase == .closing)
    }

    @Test func oneJumpAtATime() {
        oneAtATime(Lab())
        oneAtATime(CardLab())
    }

    @Test func aRowFoldingAwayTakesNoClick() {
        foldingTakesNoClick(Lab())
        foldingTakesNoClick(CardLab())
    }

    @Test(arguments: [false, true])
    func thePointerLeavingWhileTheRowIsPressedInLeavesThePanelOutUntilItDrains(reducingMotion: Bool) {
        holdsAsThePointerLeaves(Lab(reducesMotion: reducingMotion))
        holdsAsThePointerLeaves(CardLab(reducesMotion: reducingMotion))
    }

    /// After a jump's press, the panel out again is not still jumping.
    @Test func reopenedTheNotchTakesAClickAgain() {
        var lab = Lab()
        lab.openByTouch()
        lab.model.clickRow(0)
        lab.wait(Tuning.jumpFor + 20)
        lab.pointer = CGPoint(x: 600, y: lab.notchY)
        let closed = lab.settle()
        #expect(closed)
        #expect(lab.phase == .closed)

        lab.openByTouch()

        #expect(lab.phase == .open)
        #expect(lab.model.clickRow(0))
    }

    @Test func eachItemsFadeIsPaintedOverItsLanding() {
        var lab = Lab()
        lab.openByTouch()
        lab.wait(500)

        lab.content.entries[3].alpha = 0.5
        lab.step()

        #expect(lab.frame.panel?.items[3].alpha == 0.5)
        #expect(lab.frame.panel?.items[2].alpha == 1)
    }

    private func pressesInAndDrainsAt450<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.openByTouch()

        let took = lab.model.clickRow(0)
        lab.step()

        #expect(took)
        #expect(lab.frame.panel?.pressed == "s1")
        let early = lab.wait(Tuning.jumpFor - 2 * NotchLab<M>.frameMS) { $0.phase != .open }
        #expect(!early)
        #expect(lab.frame.panel?.pressed == "s1")
        let drained = lab.wait(3 * NotchLab<M>.frameMS) { $0.phase == .closing }
        #expect(drained)
        #expect(lab.frame.panel?.pressed == "s1")
        let settled = lab.settle()
        #expect(settled)
        #expect(lab.phase == .closed)
        #expect(lab.model.jumping == nil)
    }

    private func drainsAsTheJumpAnswers<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.openByTouch()
        lab.model.clickRow(0)
        lab.wait(100)
        #expect(lab.phase == .open)

        lab.model.jumpAnswered()

        #expect(lab.phase == .closing)
    }

    private func answerAfterTheDrain<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.openByTouch()
        lab.model.clickRow(0)
        lab.wait(Tuning.jumpFor + 20)
        #expect(lab.phase == .closing)

        lab.model.jumpAnswered()
        lab.pointer = CGPoint(x: 600, y: lab.notchY)
        let settled = lab.settle()

        #expect(settled)
        #expect(lab.phase == .closed)
    }

    private func closingTakesNoClick<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.openByTouch()
        lab.model.clickElsewhere()
        #expect(lab.phase == .closing)

        let took = lab.model.clickRow(0)
        lab.step()

        #expect(!took)
        #expect(lab.model.jumping == nil)
        #expect(lab.frame.panel?.pressed == nil)
    }

    private func oneAtATime<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.openByTouch()

        let first = lab.model.clickRow(0), second = lab.model.clickRow(1)

        #expect(first)
        #expect(!second)
        #expect(lab.model.jumping == "s1")
    }

    private func foldingTakesNoClick<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.openByTouch()
        lab.content.entries[0].isGoing = true
        lab.step()

        let took = lab.model.clickRow(0)

        #expect(!took)
        #expect(lab.model.clickRow(1))
    }

    private func holdsAsThePointerLeaves<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.openByTouch()
        lab.model.clickRow(0)
        let drainsAt = lab.now + Tuning.jumpFor

        let closed = lab.move(to: CGPoint(x: 700, y: lab.notchY), speed: 3) { $0.phase != .open }
        let early = lab.wait(drainsAt - 2 * NotchLab<M>.frameMS - lab.now) { $0.phase != .open }

        #expect(!closed && !early)
        let drained = lab.wait(3 * NotchLab<M>.frameMS) { $0.phase == .closing }
        #expect(drained)
        let settled = lab.settle()
        #expect(settled)
        #expect(lab.phase == .closed)
    }
}
