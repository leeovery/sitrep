import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The drag, as the prototypes have it, Meniscus and the card alike: the notch lifts off the edge over 140ms, 2
/// deeper and shadowed, follows the drag along the edge on a 50ms spring, and sets down over 220. Let go across the
/// screen's middle, it drains into this edge in 150ms, swaps edges at 160 and grows out of the other over 300.
@Suite(.backstop)
struct CarryTests {
    @Test func aDragLiftsTheNotchOver140AndItSetsDownOver220() {
        lifts(Lab())
        lifts(CardLab())
    }

    @Test func liftedTheNotchStandsTwoFurtherOut() {
        var lab = Lab(), card = CardLab()
        lab.model.carry()
        card.model.carry()
        lab.wait(1000)
        card.wait(1000)

        #expect(abs(lab.frame.outline.boundingBox.maxX - (NotchShape.rest.w + 2)) < 0.01)
        #expect(abs(card.frame.outline.boundingBox.maxX - (NotchShape.rest.w + 2)) < 0.01)
    }

    @Test func theNotchFollowsTheDragOnA50msSpring() {
        follows(Lab())
        follows(CardLab())
    }

    @Test func aDraggedNotchStaysInsideTheBand() {
        let lab = Lab(), card = CardLab()
        lab.model.carry()
        card.model.carry()

        lab.model.carried(to: 0)
        card.model.carried(to: 0)

        #expect(lab.notchY == screen.keep(0, half: NotchShape(MeniscusFeel.lees.swell).h / 2))
        #expect(card.notchY == screen.keep(0, half: NotchShape.needs.h / 2))
    }

    @Test func carriedTheNotchNeverOpensUnderThePointerNorOnceSetDownUnderIt() {
        staysClosed(Lab())
        staysClosed(CardLab())
    }

    @Test func aDragClosesTheOpenPanel() {
        var lab = Lab(), card = CardLab()
        lab.openByTouch()
        card.openByTouch()

        lab.model.carry()
        card.model.carry()

        #expect(lab.phase == .closing && card.phase == .closing)
    }

    @Test func letGoAcrossItDrainsSwapsEdgesAt160AndGrowsBackOver300() {
        crosses(Lab())
        crosses(CardLab())
    }

    @Test func underReducedMotionItSwapsEdgesAtOnce() {
        crossesAtOnce(Lab(reducesMotion: true))
        crossesAtOnce(CardLab(reducesMotion: true))
    }

    @Test func letGoAcrossWithThePanelOutItCrossesOnceThePanelIsIn() {
        crossesOnceIn(Lab())
        crossesOnceIn(CardLab())
    }

    @Test func letGoAcrossNoPressCarriesItUntilItIsHomeOnTheOtherEdge() {
        refusesCarryWhileCrossing(Lab())
        refusesCarryWhileCrossing(CardLab())
        refusesCarryWhileCrossing(Lab(reducesMotion: true))
        refusesCarryWhileCrossing(CardLab(reducesMotion: true))
    }

    @Test func letGoAcrossWithThePanelOutNoPressCarriesItUntilItIsHome() {
        refusesCarryWhileCrossing(Lab(), panelOut: true)
        refusesCarryWhileCrossing(CardLab(), panelOut: true)
    }

    @Test func letGoAlongTheEdgeAPressCarriesItAgainAtOnce() {
        let lab = Lab(), card = CardLab()
        lab.model.carry()
        card.model.carry()

        lab.model.drop(across: false)
        card.model.drop(across: false)

        #expect(lab.model.mayCarry && card.model.mayCarry)
    }

    @Test func letGoAlongTheEdgeItStaysOnIt() {
        var lab = Lab()
        lab.model.carry()

        lab.model.drop(across: false)
        let swapped = lab.wait(1000) { $0.frame.swapsEdge }

        #expect(!swapped)
        let settled = lab.settle()
        #expect(settled)
    }

    /// The drag's place saved and read back as the screen's, a hair off, is where the notch already is: it carries on
    /// there on its spring, with no jump.
    @Test func theScreenSayingWhereTheDragLeftItMovesNothing() {
        follows(on: Lab())
        follows(on: CardLab())
    }

    private func lifts<M: NotchModel>(_ lab: NotchLab<M>, sourceLocation: SourceLocation = #_sourceLocation) {
        var lab = lab

        lab.model.carry()
        lab.wait(140)
        #expect(abs(lab.frame.lift - 0.95) < 0.02, sourceLocation: sourceLocation)

        lab.model.drop(across: false)
        lab.wait(220)
        #expect(abs(lab.frame.lift - 0.05) < 0.02, sourceLocation: sourceLocation)
        let settled = lab.settle()
        #expect(settled, sourceLocation: sourceLocation)
        #expect(lab.frame.lift < 1e-3, sourceLocation: sourceLocation)
    }

    private func follows<M: NotchModel>(_ lab: NotchLab<M>, sourceLocation: SourceLocation = #_sourceLocation) {
        var lab = lab
        let from = lab.notchY

        lab.model.carry()
        lab.model.carried(to: from - 200)
        #expect(lab.notchY == from - 200, sourceLocation: sourceLocation)
        lab.wait(50)

        #expect(abs(lab.frame.light.centre.y - (from - 200 * 0.95)) < 4, sourceLocation: sourceLocation)
        let settled = lab.settle()
        #expect(settled, sourceLocation: sourceLocation)
        #expect(abs(lab.frame.light.centre.y - (from - 200)) < 0.01, sourceLocation: sourceLocation)
    }

    private func staysClosed<M: NotchModel>(_ lab: NotchLab<M>, sourceLocation: SourceLocation = #_sourceLocation) {
        var lab = lab
        lab.model.carry()

        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        let opened = lab.wait(1000) { $0.phase != .closed }
        lab.model.drop(across: false)
        let openedOnceDown = lab.wait(1000) { $0.phase != .closed }

        #expect(!opened && !openedOnceDown, sourceLocation: sourceLocation)
    }

    private func crosses<M: NotchModel>(_ lab: NotchLab<M>, sourceLocation: SourceLocation = #_sourceLocation) {
        var lab = lab
        lab.model.carry()
        lab.model.drop(across: true)
        let dropped = lab.now

        let drained = lab.wait(155) { $0.frame.outline.boundingBox.maxX <= 0.5 }
        #expect(drained, sourceLocation: sourceLocation)
        let swapped = lab.wait(200) { $0.frame.swapsEdge }
        #expect(swapped, sourceLocation: sourceLocation)
        #expect(lab.now - dropped >= 160, sourceLocation: sourceLocation)
        #expect(lab.now - dropped < 160 + NotchLab<M>.frameMS + 1, sourceLocation: sourceLocation)
        let again = lab.wait(1000) { $0.frame.swapsEdge }
        #expect(!again, sourceLocation: sourceLocation)
        let settled = lab.settle()
        #expect(settled, sourceLocation: sourceLocation)
        #expect(abs(lab.frame.outline.boundingBox.maxX - NotchShape.rest.w) < 0.5, sourceLocation: sourceLocation)
    }

    /// From the drop across, every frame refuses a press, up to the one it is home on the other edge; then one takes.
    private func refusesCarryWhileCrossing<M: NotchModel>(
        _ lab: NotchLab<M>, panelOut: Bool = false, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var lab = lab
        if panelOut {
            lab.openByTouch()
            lab.pointer = CGPoint(x: 600, y: lab.notchY)
        }
        #expect(lab.model.mayCarry, sourceLocation: sourceLocation)
        lab.model.carry()

        lab.model.drop(across: true)
        #expect(!lab.model.mayCarry, sourceLocation: sourceLocation)

        let dropped = lab.now
        var swapped: Double?
        let home = lab.wait(3000) { lab in
            if swapped == nil, lab.frame.swapsEdge {
                swapped = lab.now
            }
            return lab.model.mayCarry
        }

        #expect(home, sourceLocation: sourceLocation)
        #expect(
            swapped.map { lab.now - $0 >= (lab.model.reducesMotion ? 140 : 240) } == true,
            sourceLocation: sourceLocation
        )
        #expect(lab.now - dropped < 3000, sourceLocation: sourceLocation)
    }

    private func crossesAtOnce<M: NotchModel>(_ lab: NotchLab<M>, sourceLocation: SourceLocation = #_sourceLocation) {
        var lab = lab
        lab.model.carry()
        lab.wait(200)

        lab.model.drop(across: true)
        lab.step()

        #expect(lab.frame.swapsEdge, sourceLocation: sourceLocation)
        let settled = lab.settle(within: 300)
        #expect(settled, sourceLocation: sourceLocation)
    }

    private func crossesOnceIn<M: NotchModel>(_ lab: NotchLab<M>, sourceLocation: SourceLocation = #_sourceLocation) {
        var lab = lab
        lab.openByTouch()
        lab.model.carry()
        lab.pointer = CGPoint(x: 600, y: lab.notchY)

        lab.model.drop(across: true)
        let swapped = lab.wait(2000) { $0.frame.swapsEdge }

        #expect(swapped, sourceLocation: sourceLocation)
        #expect(lab.phase == .closed, sourceLocation: sourceLocation)
    }

    private func follows<M: NotchModel>(on lab: NotchLab<M>, sourceLocation: SourceLocation = #_sourceLocation) {
        var lab = lab
        lab.model.carry()
        lab.model.carried(to: 300)
        lab.wait(20)

        lab.model.drop(across: false)
        lab.stage.notchY = 300 / screen.height * screen.height
        lab.step()

        #expect(lab.notchY == 300, sourceLocation: sourceLocation)
        #expect(abs(lab.frame.light.centre.y - 300) > 1, sourceLocation: sourceLocation)
        let settled = lab.settle()
        #expect(settled, sourceLocation: sourceLocation)
        #expect(abs(lab.frame.light.centre.y - 300) < 0.01, sourceLocation: sourceLocation)
    }
}
