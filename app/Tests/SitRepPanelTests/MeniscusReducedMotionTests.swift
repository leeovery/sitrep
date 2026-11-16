import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// Meniscus under reduced motion, as its prototype has it: no pull toward the pointer, nothing springs, and each
/// change of shape cross-fades.
@Suite(.backstop)
struct MeniscusReducedMotionTests {
    @Test func thePointerNearingTheNotchDrawsNoTongueAndOpensNothing() {
        var lab = Lab(pointer: CGPoint(x: 200, y: 491), reducesMotion: true)
        var tongue = 0.0

        let opened = lab.move(to: CGPoint(x: 20, y: lab.notchY), speed: 0.05) { lab in
            tongue = max(tongue, lab.model.S.ba.x)
            return lab.phase != .closed
        }
        lab.wait(500)

        #expect(!opened && lab.phase == .closed)
        #expect(tongue == 0)
        #expect(lab.shape.w == 7)
    }

    @Test func touchingTheNotchStillOpensIt() {
        var lab = Lab(reducesMotion: true)

        lab.openByTouch()

        #expect(lab.phase == .open)
    }

    @Test func openingItCrossFadesStraightToThePanelAndItsRowsFadeInTogether() {
        var lab = Lab(reducesMotion: true)
        let notch = lab.frame.outline

        lab.model.open()
        lab.step()

        #expect(lab.shape.w == Tuning.panelDepth && lab.shape.h == 480 + 36)
        #expect(lab.frame.fading?.outline == notch)
        #expect(abs(lab.frame.outlineAlpha - Lab.frameMS / 100) < 1e-9)
        #expect(abs(lab.frame.fading!.alpha - (1 - Lab.frameMS / 160)) < 1e-9)
        let rows = lab.frame.panel!
        #expect(abs(rows.head.alpha - Lab.frameMS / 120) < 1e-9)
        #expect(rows.items.allSatisfy { $0 == rows.head && $0.rise == 0 })

        lab.wait(160)
        #expect(lab.frame.fading == nil && lab.frame.outlineAlpha == 1)
        #expect(lab.phase == .open)
    }

    @Test func aClickElsewhereCrossFadesItBackToTheNotch() {
        var lab = Lab(pointer: CGPoint(x: 200, y: 491), reducesMotion: true)
        lab.model.open()
        lab.settle()
        let panel = lab.frame.outline

        lab.model.clickElsewhere()
        lab.step()

        #expect(lab.shape.w == 7 && lab.shape.h == 76)
        #expect(lab.frame.fading?.outline == panel)
        let closed = lab.wait(200) { $0.phase == .closed }
        #expect(closed)
    }

    @Test func leavingTheOpenPanelNothingClingsAndItClosesAfterTheGraceAsACrossFade() {
        var lab = Lab(reducesMotion: true)
        lab.openByTouch()
        lab.move(to: CGPoint(x: 200, y: lab.notchY), speed: 0.3)
        var tongue = 0.0

        let left = lab.move(to: CGPoint(x: 450, y: lab.notchY), speed: 0.05) { lab in
            tongue = max(tongue, lab.model.S.ba.x)
            return lab.phase != .open
        }

        #expect(left && lab.phase == .closing)
        #expect(!lab.model.cling.attached && lab.model.snap == nil)
        #expect(tongue == 0)
        #expect(lab.shape.w == 7 && lab.frame.fading != nil)
    }

    @Test func aNewAskCrossFadesTheNotchToNeedsYouWithNoSwell() {
        var lab = Lab(reducesMotion: true)
        let rest = lab.frame.outline

        lab.needsLee = true
        lab.step()

        #expect(lab.shape.w == 15 && lab.shape.h == 124)
        #expect(lab.frame.fading?.outline == rest)
        var deepest = 0.0
        lab.wait(1500) { lab in
            deepest = max(deepest, lab.shape.w)
            return false
        }
        #expect(deepest == 15)
    }

    @Test func reducedMotionTakesHoldOnTheNextFrame() {
        var lab = Lab()
        lab.wait(100)

        lab.reducesMotion = true
        lab.step()
        lab.model.open()
        lab.step()

        #expect(lab.shape.w == Tuning.panelDepth)
        #expect(lab.frame.fading != nil)
    }
}
