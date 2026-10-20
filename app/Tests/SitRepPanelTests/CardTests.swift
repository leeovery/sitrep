import CoreGraphics
@testable import SitRepPanel
import Testing

struct CardTests {
    @Test func withNothingNeedingLeeTheNotchRestsSevenDeepAndSeventySixLong() {
        let lab = CardLab()

        #expect(lab.shape.w == 7)
        #expect(lab.shape.h == 76)
        let drawn = lab.frame.outline.boundingBoxOfPath
        #expect(abs(drawn.maxX - 7) < 1e-9)
        #expect(abs(drawn.minY - (lab.notchY - 38)) < 1e-9)
        #expect(abs(drawn.maxY - (lab.notchY + 38)) < 1e-9)
    }

    @Test func withSomethingNeedingLeeTheNotchRestsFifteenDeepAndAHundredAndTwentyFourLong() {
        let lab = CardLab(needsLee: true)

        #expect(lab.shape.w == 15)
        #expect(lab.shape.h == 124)
        #expect(abs(lab.frame.outline.boundingBoxOfPath.maxX - 15) < 1e-9)
    }

    @Test(arguments: [(7.0, 6.0), (11, 8), (15, 10), (37.5, 17), (60, 24), (372, 24)])
    func itsOuterCornersRoundWithItsDepth(depth: Double, radius: Double) {
        #expect(abs(cornerAt(depth) - radius) < 1e-12)
    }

    @Test func itsCornersRoundNoFurtherThanItsDepthOrHalfItsLength() {
        #expect(CardGeometry(w: 4, h: 76, near: 491, on: screen).r == 4)
        #expect(CardGeometry(w: 60, h: 30, near: 491, on: screen).r == 15)
    }

    @Test func itMeetsTheEdgeSquareAndRoundsOnlyItsOuterCorners() {
        let lab = CardLab(needsLee: true)
        let outline = lab.frame.outline, top = lab.notchY - 62, bottom = lab.notchY + 62

        #expect(outline.contains(CGPoint(x: 0.25, y: top + 0.25)))
        #expect(outline.contains(CGPoint(x: 0.25, y: bottom - 0.25)))
        #expect(!outline.contains(CGPoint(x: 14.75, y: top + 0.25)))
        #expect(!outline.contains(CGPoint(x: 14.75, y: bottom - 0.25)))
        #expect(outline.contains(CGPoint(x: 14.75, y: lab.notchY)))
    }

    @Test func aNotchAtRestWithThePointerElsewhereHasNothingMoving() {
        var lab = CardLab(needsLee: true)
        lab.wait(100)

        #expect(!lab.frame.isMoving)
        #expect(lab.frame.light.level == 1)
    }

    @Test func thePointerOutsideTheFieldDoesNotNudgeIt() {
        var lab = CardLab(needsLee: true, pointer: CGPoint(x: 49, y: 491))
        lab.settle()

        #expect(lab.shape.w == 15)
    }

    @Test func inTheFieldTheNotchEasesOutTowardThePointerMoreAsTheGapCloses() {
        var lab = CardLab(needsLee: true, pointer: CGPoint(x: 45, y: 491))
        lab.settle()
        let far = lab.shape.w

        lab.pointer = CGPoint(x: 35, y: lab.notchY)
        lab.settle()
        let near = lab.shape.w

        #expect(far > 15)
        #expect(near > far + 1)
        #expect(near < 15 + 8)
    }

    @Test func theNudgeIsAllTheWayOutAsThePointerTouchesTheNotch() {
        var lab = CardLab(needsLee: true, pointer: CGPoint(x: 48, y: 491))

        let touched = lab.move(to: CGPoint(x: 0, y: lab.notchY), speed: 0.02) { $0.model.contact.touching }

        #expect(touched)
        #expect(lab.model.S.n.target == 8)
    }

    @Test(arguments: [(0.0, 1.0), (90, 1), (155, 0.5), (220, 0)])
    func theNudgeIsWholeWithin90OfTheNotchsCentreFadingToNothingAt220(along: Double, share: Double) {
        var lab = CardLab(needsLee: true, pointer: CGPoint(x: 27, y: 491 + along))
        lab.step()

        #expect(abs(lab.model.nudgeShare() - share) < 1e-12)
    }

    @Test func noNudgeUnderReducedMotionOrAtNudgeZero() {
        var still = CardFeel.lees
        still.nudge = 0
        var reduced = CardLab(needsLee: true, pointer: CGPoint(x: 30, y: 491), reducesMotion: true)
        var none = CardLab(feel: still, needsLee: true, pointer: CGPoint(x: 30, y: 491))

        reduced.settle()
        none.settle()

        #expect(reduced.shape.w == 15)
        #expect(none.shape.w == 15)
    }

    @Test func theNudgeGoesIntoTheSlideAsItOpens() {
        var lab = CardLab(needsLee: true, pointer: CGPoint(x: 30, y: 491))
        lab.settle()
        let nudged = lab.shape.w

        lab.model.open()

        #expect(lab.model.S.n.x == 0)
        #expect(lab.model.S.w.x == nudged)
    }

    @Test func touchingTheNotchOpensItAfter150ms() {
        var lab = CardLab()
        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        lab.step()
        let touched = lab.now

        let opened = lab.wait(300) { $0.phase != .closed }

        #expect(opened)
        #expect(lab.now - touched >= 150)
        #expect(lab.now - touched < 150 + CardLab.frameMS)
    }

    @Test func aFastTouchOpensItAtOnce() {
        var lab = CardLab(pointer: CGPoint(x: 150, y: 491))

        let opened = lab.move(to: CGPoint(x: 2, y: lab.notchY), speed: 2) { $0.phase != .closed }

        #expect(opened)
        #expect(lab.pointer!.x == 2)
    }

    @Test func aPassOverTheNotchDoesNotOpenIt() {
        var lab = CardLab()
        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        lab.step()
        lab.pointer = CGPoint(x: 60, y: lab.notchY)

        let opened = lab.wait(500) { $0.phase != .closed }

        #expect(!opened)
    }

    @Test func theOpenCardIsTheContentsLengthCentredOnTheNotch() {
        var lab = CardLab()
        lab.openByTouch()
        lab.settle()

        #expect(abs(lab.shape.w - 372) < 0.01)
        #expect(abs(lab.shape.h - 480) < 0.01)
        #expect(abs(lab.shape.cy - lab.notchY) < 0.01)
        #expect(lab.shape.r == 24)
        #expect(lab.frame.panel!.frame == CGRect(x: 0, y: lab.notchY - 240, width: 372, height: 480))
    }

    @Test func itsLengthIsItsRowsUpToTheVisibleFrameLess40EachEnd() {
        var lab = CardLab(content: Content(headHeight: 26, entries: Array(repeating: Content.css.entries[0], count: 30)))
        lab.openByTouch()
        lab.settle()

        #expect(abs(lab.shape.h - (982 - 24 - 80)) < 0.01)
        #expect(abs(lab.shape.top - (24 + 40)) < 0.01)
    }

    /// Springing a little past the band's length, it stays on the band's middle rather than jumping to the screen's.
    @Test func pastTheBandsLengthItStaysOnTheBandsMiddle() {
        let middle = (24 + 40 + 982 - 40) / 2.0

        #expect(screen.centre(878, near: 491) == middle)
        #expect(screen.centre(879, near: 491) == middle)
    }

    @Test func asRowsComeAndGoWhileItIsOpenItsLengthFollowsThem() {
        var lab = CardLab()
        lab.openByTouch()
        lab.settle()

        lab.content = Content(headHeight: 26, entries: Content.css.entries + Content.css.entries.prefix(2))
        lab.settle()

        #expect(abs(lab.shape.h - (480 + 118)) < 0.01)
    }

    @Test func theLightIsDimmedWhileThePanelIsOut() {
        var lab = CardLab(needsLee: true)
        lab.openByTouch()
        lab.settle()

        #expect(lab.frame.light.level == 0)
    }

    @Test func leavingTheOpenPanelSlowlyClosesItAfterTheGraceOf300ms() {
        var lab = CardLab()
        lab.openByTouch()
        lab.move(to: CGPoint(x: 200, y: lab.notchY), speed: 0.3)
        lab.settle()

        let graced = lab.leave(to: CGPoint(x: 600, y: lab.notchY), speed: 0.05)

        #expect(abs(graced - 300) < CardLab.frameMS)
    }

    @Test func leavingItFastClosesItAfterAGraceOf60ms() {
        var lab = CardLab()
        lab.openByTouch()
        lab.move(to: CGPoint(x: 200, y: lab.notchY), speed: 0.3)
        lab.settle()

        let graced = lab.leave(to: CGPoint(x: 700, y: lab.notchY), speed: 3)

        #expect(abs(graced - 60) < CardLab.frameMS)
    }

    @Test func aPointerBackOnThePanelInItsGraceKeepsItOpen() {
        var lab = CardLab()
        lab.openByTouch()
        lab.move(to: CGPoint(x: 200, y: lab.notchY), speed: 0.3)
        lab.move(to: CGPoint(x: 500, y: lab.notchY), speed: 0.3) { $0.model.timers.has(.grace) }

        lab.move(to: CGPoint(x: 200, y: lab.notchY), speed: 2)

        let closed = lab.wait(600) { $0.phase != .open }
        #expect(!closed)
    }

    @Test func aClickElsewhereClosesTheOpenPanelAtOnce() {
        var lab = CardLab()
        lab.openByTouch()

        lab.model.clickElsewhere()

        #expect(lab.phase == .closing)
        let settled = lab.settle()
        #expect(settled)
        #expect(lab.phase == .closed)
        #expect(lab.model.S.w.x == 7)
        #expect(abs(lab.shape.h - 76) < 0.01)
    }

    @Test func aClickOnARowThatJumpsClosesThePanelAndOneNoWindowShowsDoesNothing() {
        var lab = CardLab()
        lab.openByTouch()

        lab.model.clickRow(lab.model.items.count - 1)
        #expect(lab.phase == .open)

        lab.model.clickRow(0)
        let drained = lab.wait(Tuning.jumpFor + CardLab.frameMS) { $0.phase == .closing }
        #expect(drained)
    }

    @Test(arguments: [-1, 8, 99])
    func aClickOutsideTheRowsDoesNothing(_ index: Int) {
        var lab = CardLab()
        lab.openByTouch()

        lab.model.clickRow(index)

        #expect(lab.phase == .open)
    }

    @Test func noSwellsAtAllPushNothingAndTheNotchSettlesAtNeedsYou() {
        var feel = CardFeel.lees
        feel.swells = -1
        var lab = CardLab(feel: feel)

        lab.needsLee = true
        lab.wait(1000)

        #expect(lab.frame.light.lastAsk == nil)
        let settled = lab.settle()
        #expect(settled)
        #expect(abs(lab.shape.w - 15) < 0.01 && abs(lab.shape.h - 124) < 0.01)
    }

    @Test func aPointerLeftOnTheNotchAsThePanelClosesDoesNotReopenItUntilItLeaves() {
        var lab = CardLab()
        lab.openByTouch()

        lab.model.clickElsewhere()
        lab.settle()
        let reopenedInPlace = lab.wait(600) { $0.phase != .closed }
        #expect(!reopenedInPlace)

        lab.pointer = CGPoint(x: 100, y: lab.notchY)
        lab.step()
        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        let reopened = lab.wait(600) { $0.phase != .closed }
        #expect(reopened)
    }

    @Test(arguments: [1, 2, 3])
    func aNewAskPushesTheNotchOutToSwellAsManyTimesAsSwellsSays450msApartFlashingTheLightWithEach(swells: Int) {
        var feel = CardFeel.lees
        feel.swells = swells
        var lab = CardLab(feel: feel, needsLee: true)
        lab.model.newAsk()

        var peaks: [(t: Double, w: Double)] = [], flashes: [Double] = []
        var longest = 0.0, last = lab.shape.w, rising = false
        lab.wait(2500) { lab in
            let w = lab.shape.w
            if rising, w < last {
                peaks.append((lab.model.t, last))
            }
            rising = w > last
            last = w
            longest = max(longest, lab.shape.h)
            if let ask = lab.frame.light.lastAsk, ask != flashes.last {
                flashes.append(ask)
            }
            return false
        }

        let pushes = peaks.filter { $0.w > 20 }
        #expect(pushes.count == swells)
        #expect(pushes.allSatisfy { abs($0.w - 25) < 1 })
        #expect(zip(flashes, flashes.dropFirst()).allSatisfy { abs($1 - $0 - 450) < CardLab.frameMS })
        #expect(flashes.count == swells)
        #expect(longest == 124)
        let settled = lab.settle()
        #expect(settled)
        #expect(abs(lab.shape.w - 15) < 0.01)
    }

    /// The push is aimed on a look-ahead a millisecond at a time, as the prototype's is: frames that far apart peak
    /// right at Swell, and the display's, at 60 or 120 a second, a point or less short of it.
    @Test(arguments: [15.0, 22, 30])
    func eachPushPeaksAtSwell(swell: Double) {
        var feel = CardFeel.lees
        feel.swell = swell
        feel.swells = 1
        var lab = CardLab(feel: feel, needsLee: true)
        lab.model.newAsk()

        var widest = 0.0
        let asked = lab.now
        while lab.now < asked + 1000 {
            lab.step(at: lab.now + 1)
            widest = max(widest, lab.shape.w)
        }

        #expect(abs(widest - swell) < 1e-3)
    }

    @Test func theSwellsStopOnceThePanelOpensAndAnAskWithItOutFlashesTheLightAlone() {
        var lab = CardLab(needsLee: true, pointer: CGPoint(x: 200, y: 491))
        lab.model.newAsk()
        lab.step()
        lab.model.open()

        var flashes: Set<Double> = []
        lab.wait(1500) { lab in
            if let ask = lab.frame.light.lastAsk {
                flashes.insert(ask)
            }
            return false
        }
        #expect(flashes.count == 1)

        let asked = lab.model.t
        lab.model.newAsk()
        lab.step()
        #expect(lab.frame.light.lastAsk == asked)
        #expect(lab.phase == .open)
    }

    @Test func somethingComingToNeedLeeIsANewAskAndItsAnswerTakesTheNotchBackToRest() {
        var lab = CardLab()
        lab.needsLee = true
        lab.wait(100)
        #expect(lab.frame.light.lastAsk != nil)
        lab.settle()
        #expect(abs(lab.shape.w - 15) < 0.01)
        #expect(abs(lab.shape.h - 124) < 0.01)
        #expect(lab.frame.light.level == 1)

        lab.needsLee = false
        lab.settle()

        #expect(abs(lab.shape.w - 7) < 0.01)
        #expect(abs(lab.shape.h - 76) < 0.01)
        #expect(lab.frame.light.level == 0)
    }

    @Test func underReducedMotionItCrossFadesToThePanelAndItsRowsFadeInTogether() {
        var lab = CardLab(needsLee: true, reducesMotion: true)
        let notch = lab.frame.outline

        lab.model.open()
        lab.step()

        #expect(lab.phase == .open)
        #expect(lab.shape.w == 372 && lab.shape.h == 480)
        #expect(lab.frame.fading?.outline == notch)
        #expect(abs(lab.frame.outlineAlpha - CardLab.frameMS / 100) < 1e-9)
        #expect(abs(lab.frame.fading!.alpha - (1 - CardLab.frameMS / 160)) < 1e-9)
        let rows = lab.frame.panel!
        #expect(abs(rows.head.alpha - CardLab.frameMS / 120) < 1e-9)
        #expect(rows.items.allSatisfy { $0 == rows.head && $0.rise == 0 })

        lab.wait(160)
        #expect(lab.frame.fading == nil)
        #expect(lab.frame.outlineAlpha == 1)
    }

    @Test func underReducedMotionItCrossFadesBackToTheNotch() {
        var lab = CardLab(needsLee: true, pointer: CGPoint(x: 200, y: 491), reducesMotion: true)
        lab.model.open()
        lab.settle()
        let panel = lab.frame.outline

        lab.model.clickElsewhere()
        lab.step()

        #expect(lab.shape.w == 15 && lab.shape.h == 124)
        #expect(lab.frame.fading?.outline == panel)
        let closed = lab.wait(200) { $0.phase == .closed }
        #expect(closed)
        lab.settle()
        #expect(abs(lab.frame.light.level - 1) < 1e-3)
    }
}

extension CardLab {
    /// The pointer off the open panel: how long the grace ran, from the pointer going off it to the close.
    mutating func leave(to target: CGPoint, speed: Double) -> Double {
        var gracedAt: Double?
        move(to: target, speed: speed) { lab in
            gracedAt = lab.model.timers.has(.grace) ? gracedAt ?? lab.now : nil
            return gracedAt != nil
        }
        wait(1000) { $0.phase != .open }
        return now - gracedAt!
    }
}
