import CoreGraphics
@testable import SitRepPanel
import Testing

/// The drag, as the prototypes have it, Meniscus and the card alike: the notch lifts off the edge over 140ms, 2
/// deeper and shadowed, follows the drag along the edge on a 50ms spring, and sets down over 220. Let go across the
/// screen's middle, it drains into this edge in 150ms, swaps edges at 160 and grows out of the other over 300.
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

    private func lifts<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab

        lab.model.carry()
        lab.wait(140)
        #expect(abs(lab.frame.lift - 0.95) < 0.02)

        lab.model.drop(across: false)
        lab.wait(220)
        #expect(abs(lab.frame.lift - 0.05) < 0.02)
        let settled = lab.settle()
        #expect(settled)
        #expect(lab.frame.lift < 1e-3)
    }

    private func follows<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        let from = lab.notchY

        lab.model.carry()
        lab.model.carried(to: from - 200)
        #expect(lab.notchY == from - 200)
        lab.wait(50)

        #expect(abs(lab.frame.light.centre.y - (from - 200 * 0.95)) < 4)
        let settled = lab.settle()
        #expect(settled)
        #expect(abs(lab.frame.light.centre.y - (from - 200)) < 0.01)
    }

    private func staysClosed<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.model.carry()

        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        let opened = lab.wait(1000) { $0.phase != .closed }
        lab.model.drop(across: false)
        let openedOnceDown = lab.wait(1000) { $0.phase != .closed }

        #expect(!opened && !openedOnceDown)
    }

    private func crosses<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.model.carry()
        lab.model.drop(across: true)
        let dropped = lab.now

        let drained = lab.wait(155) { $0.frame.outline.boundingBox.maxX <= 0.5 }
        #expect(drained)
        let swapped = lab.wait(200) { $0.frame.swapsEdge }
        #expect(swapped)
        #expect(lab.now - dropped >= 160)
        #expect(lab.now - dropped < 160 + NotchLab<M>.frameMS + 1)
        let again = lab.wait(1000) { $0.frame.swapsEdge }
        #expect(!again)
        let settled = lab.settle()
        #expect(settled)
        #expect(abs(lab.frame.outline.boundingBox.maxX - NotchShape.rest.w) < 0.5)
    }

    private func crossesAtOnce<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.model.carry()
        lab.wait(200)

        lab.model.drop(across: true)
        lab.step()

        #expect(lab.frame.swapsEdge)
        let settled = lab.settle(within: 300)
        #expect(settled)
    }

    private func crossesOnceIn<M: NotchModel>(_ lab: NotchLab<M>) {
        var lab = lab
        lab.openByTouch()
        lab.model.carry()
        lab.pointer = CGPoint(x: 600, y: lab.notchY)

        lab.model.drop(across: true)
        let swapped = lab.wait(2000) { $0.frame.swapsEdge }

        #expect(swapped)
        #expect(lab.phase == .closed)
    }

    private func follows<M: NotchModel>(on lab: NotchLab<M>) {
        var lab = lab
        lab.model.carry()
        lab.model.carried(to: 300)
        lab.wait(20)

        lab.model.drop(across: false)
        lab.stage.notchY = 300 / screen.height * screen.height
        lab.step()

        #expect(lab.notchY == 300)
        #expect(abs(lab.frame.light.centre.y - 300) > 1)
        let settled = lab.settle()
        #expect(settled)
        #expect(abs(lab.frame.light.centre.y - 300) < 0.01)
    }
}
