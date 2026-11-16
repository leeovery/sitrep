import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// What the app asks of either notch beyond its prototype's: coming to need Lee with nothing new, as on `watch`'s
/// first board, and being carried by a drag.
@Suite(.backstop)
struct NotchNeedsTests {
    @Test func meniscusComesToNeedLeeQuietlyAt15By124WithTheLightOnAndNoSwellOrFlash() {
        var lab = Lab()

        lab.model.needsLeeQuietly()
        lab.needsLee = true
        var widest = 0.0
        lab.wait(1000) { lab in
            widest = max(widest, lab.shape.w)
            return false
        }
        lab.settle()

        #expect(widest <= 15 + 1e-9)
        #expect(abs(lab.shape.w - 15) < 0.01 && abs(lab.shape.h - 124) < 0.01)
        #expect(lab.frame.light.level > 0.999)
        #expect(lab.frame.light.lastAsk == nil)
    }

    @Test func theCardComesToNeedLeeQuietlyAt15By124WithTheLightOnAndNoPushOrFlash() {
        var lab = CardLab()

        lab.model.needsLeeQuietly()
        lab.needsLee = true
        var deepest = 0.0
        lab.wait(1000) { lab in
            deepest = max(deepest, lab.shape.w)
            return false
        }
        lab.settle()

        #expect(deepest <= 15 + 1e-9)
        #expect(abs(lab.shape.w - 15) < 0.01 && abs(lab.shape.h - 124) < 0.01)
        #expect(lab.frame.light.level > 0.999)
        #expect(lab.frame.light.lastAsk == nil)
    }

    @Test func aSwellUnderWayIsLeftToPlayOut() {
        var lab = Lab()
        lab.model.newAsk()
        lab.needsLee = true
        lab.step()

        lab.model.needsLeeQuietly()
        var widest = 0.0
        lab.wait(1000) { lab in
            widest = max(widest, lab.shape.w)
            return false
        }

        #expect(widest > 20)
    }

    @Test func carriedMeniscusClosesAndStaysClosedUnderThePointer() {
        var lab = Lab(needsLee: true)
        lab.openByTouch()

        lab.model.carry()
        lab.settle()

        #expect(lab.phase == .closed)
    }

    @Test func carriedTheCardClosesAndStaysClosedUnderThePointer() {
        var lab = CardLab(needsLee: true)
        lab.openByTouch()

        lab.model.carry()
        lab.settle()

        #expect(lab.phase == .closed)
    }

    @Test func aClosedNotchCarriedBeforeItOpensDoesNotOpenUnderThePointer() {
        var lab = Lab(needsLee: true)
        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        lab.step()

        lab.model.carry()
        lab.wait(1000)

        #expect(lab.phase == .closed)
    }
}
