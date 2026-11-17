import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct MeniscusTests {
    @Test func withNothingNeedingLeeTheNotchRestsSevenDeepAndSeventySixLong() {
        let lab = Lab()

        #expect(lab.shape.w == 7)
        #expect(lab.shape.h == 76)
        let drawn = lab.frame.outline.boundingBoxOfPath
        #expect(abs(drawn.maxX - 7) < 1e-9)
        #expect(abs(drawn.minY - (lab.notchY - 38)) < 1e-9)
        #expect(abs(drawn.maxY - (lab.notchY + 38)) < 1e-9)
    }

    @Test func withSomethingNeedingLeeTheNotchRestsFifteenDeepAndAHundredAndTwentyFourLong() {
        let lab = Lab(needsLee: true)

        #expect(lab.shape.w == 15)
        #expect(lab.shape.h == 124)
        #expect(abs(lab.frame.outline.boundingBoxOfPath.maxX - 15) < 1e-9)
    }

    @Test func aNotchAtRestWithThePointerElsewhereHasNothingMoving() {
        var lab = Lab(needsLee: true)
        lab.wait(100)

        #expect(!lab.frame.isMoving)
        #expect(lab.frame.light.level == 1)
    }

    @Test func theNotchsHomeKeepsItsDeepestSwellInsideTheBand() {
        let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 30)
        let notch = Meniscus(Input(time: 0, pointer: nil, needsLee: false, stage: stage, content: .css))

        // Swell's 25 deep is 184 long
        #expect(notch.notchY == 24 + 40 + 184 / 2)
    }

    @Test func aClickOnTheBlackOrTheNotchsHitAreaIsThePanelsAndAnywhereElsePassesThrough() {
        let lab = Lab()

        #expect(lab.frame.hits(CGPoint(x: 3, y: lab.notchY)))
        #expect(lab.frame.hits(CGPoint(x: 11, y: lab.notchY)))
        #expect(!lab.frame.hits(CGPoint(x: 30, y: lab.notchY)))
        #expect(!lab.frame.hits(CGPoint(x: 3, y: lab.notchY - 60)))
    }

    @Test func aSlowApproachStraightAtTheNotchOpensItAsTheGapClosesToReach() {
        var lab = Lab(pointer: CGPoint(x: 200, y: 491))

        let opened = lab.move(to: CGPoint(x: 0, y: lab.notchY), speed: 0.05) { $0.phase != .closed }

        #expect(opened)
        #expect(lab.phase == .opening)
        #expect(lab.model.attract.gap < 10)
        #expect(lab.model.attract.gap > 8)
        #expect(lab.pointer!.x > 12)
    }

    @Test func aSweepAlongTheEdgePastTheNotchDoesNotOpenItThoughStoppingThereWould() {
        var lab = Lab(pointer: CGPoint(x: 16, y: 491 - 260))

        let openedPassing = lab.move(to: CGPoint(x: 16, y: lab.notchY + 260), speed: 0.4) { $0.phase != .closed }
        #expect(!openedPassing)

        lab.move(to: CGPoint(x: 16, y: lab.notchY), speed: 2)
        let openedStopped = lab.wait(600) { $0.phase != .closed }
        #expect(openedStopped)
    }

    @Test func touchingTheNotchOpensItAfter150ms() {
        var lab = Lab()
        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        lab.step()
        let touched = lab.now

        let opened = lab.wait(300) { $0.phase != .closed }
        #expect(opened)
        #expect(lab.now - touched >= 150)
        #expect(lab.now - touched < 150 + Lab.frameMS)
    }

    @Test func aFastTouchOpensTheNotchAtOnce() {
        var lab = Lab(pointer: CGPoint(x: 150, y: 491))

        let opened = lab.move(to: CGPoint(x: 2, y: lab.notchY), speed: 2) { $0.phase != .closed }
        #expect(opened)
        #expect(lab.pointer!.x == 2)
    }

    @Test func aPassOverTheNotchDoesNotOpenIt() {
        var lab = Lab()
        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        lab.step()
        lab.pointer = CGPoint(x: 60, y: lab.notchY)

        let opened = lab.wait(500) { $0.phase != .closed }
        #expect(!opened)
    }

    @Test func theRowsLandFromTheTopTwentyFiveMillisecondsApart() {
        var lab = Lab()
        lab.model.open()
        let opened = lab.model.t

        lab.wait(300)

        let since = lab.model.t - opened
        let panel = lab.frame.panel!
        #expect(panel.head.alpha == easeOut(min(1, (since - 160) / 90)))
        for (i, place) in lab.model.revealOrder.enumerated() {
            #expect(panel.items[i].alpha == easeOut(clamp((since - 160 - 25 * Double(place)) / 90, 0, 1)))
        }
        #expect(lab.model.revealOrder == [1, 2, 3, 3, 4, 5, 6, 7])
    }

    @Test func theLightIsDimmedWhileThePanelIsOut() {
        var lab = Lab(needsLee: true)
        lab.openByTouch()

        #expect(lab.frame.light.level == 0)
    }

    @Test func theOpenPanelIsTheContentsHeightAndTheFlaresCentredOnTheNotch() {
        var lab = Lab()
        lab.openByTouch()
        lab.settle()

        #expect(abs(lab.shape.w - 372) < 0.01)
        #expect(abs(lab.shape.h - (480 + 36)) < 0.01)
        #expect(abs(lab.shape.cy - lab.notchY) < 0.01)
        #expect(abs(lab.frame.panel!.frame.minY - (lab.notchY - 240)) < 0.01)
    }

    @Test func leavingSlowlyThroughTheFrontHoldsThePointerThenBreaksAfterHanging60msAtHold() {
        var lab = Lab()
        lab.openByTouch()
        lab.move(to: CGPoint(x: 200, y: lab.notchY), speed: 0.3)
        #expect(lab.model.cling.attached)

        var held: [Double] = []
        var hungAt: Double?
        let broke = lab.move(to: CGPoint(x: 450, y: lab.notchY), speed: 0.05) { lab in
            let out = lab.pointer!.x - 372
            if out > 5, out < 25 {
                held.append(lab.model.S.ba.x - (out + 3))
            }
            if hungAt == nil, lab.model.cling.hang != nil {
                hungAt = lab.now
            }
            return lab.phase == .closing
        }

        #expect(broke)
        #expect(held.count >= 20)
        expectEvery(held) { abs($0) < 1 }
        #expect(lab.now - hungAt! >= 60)
        #expect(lab.now - hungAt! < 60 + Lab.frameMS)
        #expect(lab.model.snap != nil)
    }

    @Test func afterABreakThePanelCollapsesBackToTheRestingNotchAndEverythingComesToRest() {
        var lab = Lab()
        lab.breakSlowlyThroughTheFront()

        let settled = lab.settle()
        #expect(settled)

        #expect(lab.phase == .closed)
        expectEvery(MeniscusSprings.all) { lab.model.S[keyPath: $0].isAtRest }
        #expect(abs(lab.shape.w - 7) < 0.01)
        #expect(abs(lab.shape.h - 76) < 0.01)
        #expect(abs(lab.shape.cy - lab.notchY) < 0.01)
        #expect(lab.model.ends == nil && lab.model.snap == nil && !lab.model.ringing)
    }

    @Test func afterABreakThePanelHoldsStillWhileTheEdgeSpringsBackThroughItsLineAndCollapsesAsItDents() {
        var lab = Lab()
        lab.breakSlowlyThroughTheFront()

        var line: Double?, collapse: Double?, deepest = (at: 0.0, depth: 0.0), rowsHeld = true
        lab.wait(400) { lab in
            let ba = lab.model.S.ba.x
            if line == nil, ba <= 0 {
                line = lab.now
            }
            if collapse == nil, lab.shape.w < 372 - 0.01 {
                collapse = lab.now
            }
            if collapse == nil, lab.frame.panel!.items.contains(where: { $0.alpha < 1 }) {
                rowsHeld = false
            }
            if ba < deepest.depth {
                deepest = (lab.now, ba)
            }
            return false
        }

        #expect(line! <= collapse!)
        #expect(collapse! < deepest.at)
        #expect(deepest.depth < -8)
        #expect(rowsHeld)
    }

    @Test func leavingBackOverTheNotchSlowlyClosesAfterTheGraceOf300ms() {
        var lab = Lab()
        lab.openByTouch()
        let top = lab.notchY - 258
        lab.move(to: CGPoint(x: 3, y: top + 27), speed: 0.3)

        let graced = lab.leaveOverTheTopFlare(to: CGPoint(x: 3, y: top - 20), speed: 0.02)

        #expect(abs(graced - 300) < Lab.frameMS)
    }

    @Test func leavingBackOverTheNotchFastClosesAfterAGraceOf60ms() {
        var lab = Lab()
        lab.openByTouch()
        let top = lab.notchY - 258
        lab.move(to: CGPoint(x: 3, y: top + 120), speed: 0.3)

        let graced = lab.leaveOverTheTopFlare(to: CGPoint(x: 3, y: top - 60), speed: 2)

        #expect(abs(graced - 60) < Lab.frameMS)
    }

    @Test func aPointerBackOnThePanelInItsGraceKeepsItOpen() {
        var lab = Lab()
        lab.openByTouch()
        let top = lab.notchY - 258
        lab.move(to: CGPoint(x: 3, y: top + 27), speed: 0.3)
        lab.move(to: CGPoint(x: 3, y: top - 20), speed: 0.3) { $0.model.timers.has(.grace) }

        lab.move(to: CGPoint(x: 100, y: lab.notchY), speed: 2)

        let closed = lab.wait(600) { $0.phase != .open }
        #expect(!closed)
    }

    @Test func aClickElsewhereClosesTheOpenPanelAtOnce() {
        var lab = Lab()
        lab.openByTouch()

        lab.model.clickElsewhere()

        #expect(lab.phase == .closing)
        let settled = lab.settle()
        #expect(settled)
        #expect(lab.phase == .closed)
    }

    @Test func aClickOnARowThatJumpsDrainsThePanelOnceItHasPressedIn() {
        var lab = Lab()
        lab.openByTouch()

        lab.model.clickRow(0)
        let drained = lab.wait(Tuning.jumpFor + Lab.frameMS) { $0.phase == .closing }

        #expect(drained)
    }

    @Test func aClickOnARowNoWindowShowsDoesNothing() {
        var lab = Lab()
        lab.openByTouch()

        lab.model.clickRow(lab.model.items.count - 1)

        #expect(lab.phase == .open)
    }

    @Test(arguments: [-1, 8, 99])
    func aClickOutsideTheRowsDoesNothing(_ index: Int) {
        var lab = Lab()
        lab.openByTouch()

        lab.model.clickRow(index)

        #expect(lab.phase == .open)
    }

    @Test func aPointerLeftOnTheNotchAsThePanelClosesDoesNotReopenItUntilItLeaves() {
        var lab = Lab()
        lab.openByTouch()

        lab.model.clickElsewhere()
        let settled = lab.settle()
        #expect(settled)
        #expect(lab.phase == .closed)

        lab.pointer = CGPoint(x: 100, y: lab.notchY)
        lab.step()
        lab.pointer = CGPoint(x: 3, y: lab.notchY)
        let reopened = lab.wait(600) { $0.phase != .closed }
        #expect(reopened)
    }

    @Test func aNewAskSwellsTheNotchToSwellsDepthAndItSettlesBack() {
        var feel = MeniscusFeel.lees
        feel.swells = 1
        var lab = Lab(feel: feel, needsLee: true)
        lab.model.newAsk()
        let asked = lab.model.t

        var widest = 0.0, longest = 0.0
        lab.wait(2000) { lab in
            widest = max(widest, lab.shape.w)
            longest = max(longest, lab.shape.h)
            return false
        }

        #expect(abs(widest - 25) < 1)
        #expect(abs(longest - 184) < 8)
        #expect(lab.frame.light.lastAsk == asked)
        let settled = lab.settle()
        #expect(settled)
        #expect(abs(lab.shape.w - 15) < 0.01)
        #expect(abs(lab.shape.h - 124) < 0.01)
    }

    @Test(arguments: [1, 2, 3])
    func aNewAskSwellsTheNotchAsManyTimesAsSwellsSaysFlashingTheLightWithEach(swells: Int) {
        var feel = MeniscusFeel.lees
        feel.swells = swells
        var lab = Lab(feel: feel, needsLee: true)
        lab.model.newAsk()

        var peaks = 0, flashes: Set<Double> = [], swollen = false
        lab.wait(2500) { lab in
            if lab.shape.w > 20, !swollen {
                peaks += 1
            }
            swollen = lab.shape.w > 20
            if let ask = lab.frame.light.lastAsk {
                flashes.insert(ask)
            }
            return false
        }

        #expect(peaks == swells)
        #expect(flashes.count == swells)
        let settled = lab.settle()
        #expect(settled)
        #expect(abs(lab.shape.w - 15) < 0.01)
    }

    @Test func noSwellsAtAllTakeTheNotchStraightTo15DeepWithNoOverSwell() {
        var feel = MeniscusFeel.lees
        feel.swells = -1
        var lab = Lab(feel: feel)
        lab.needsLee = true

        var widest = 0.0
        lab.wait(1000) { lab in
            widest = max(widest, lab.shape.w)
            return false
        }

        #expect(widest <= 15 + 1e-9)
        let settled = lab.settle()
        #expect(settled)
        #expect(abs(lab.shape.w - 15) < 0.01 && abs(lab.shape.h - 124) < 0.01)
    }

    @Test func theSwellsAfterTheFirstStopOnceThePanelOpens() {
        var lab = Lab(needsLee: true)
        lab.model.newAsk()
        lab.model.open()

        var flashes: Set<Double> = []
        lab.wait(1500) { lab in
            if let ask = lab.frame.light.lastAsk {
                flashes.insert(ask)
            }
            return false
        }

        #expect(flashes.count == 1)
    }

    @Test func somethingComingToNeedLeeIsANewAskAndItsAnswerTakesTheNotchBackToRest() {
        var lab = Lab()
        lab.needsLee = true
        lab.step()
        #expect(lab.frame.light.lastAsk != nil)
        lab.settle()
        #expect(abs(lab.shape.w - 15) < 0.01)
        #expect(lab.frame.light.level == 1)

        lab.needsLee = false
        lab.settle()

        #expect(abs(lab.shape.w - 7) < 0.01)
        #expect(lab.frame.light.level == 0)
    }
}

extension Lab {
    /// Opened by a touch, the pointer into the panel and out through the front slowly, until the edge lets it go.
    mutating func breakSlowlyThroughTheFront() {
        openByTouch()
        move(to: CGPoint(x: 200, y: notchY), speed: 0.3)
        move(to: CGPoint(x: 450, y: notchY), speed: 0.05) { $0.phase == .closing }
    }

    /// The pointer on out over the top flare: how long the grace ran, from the pointer going over it to the close.
    mutating func leaveOverTheTopFlare(to target: CGPoint, speed: Double) -> Double {
        var gracedAt: Double?
        move(to: target, speed: speed) { lab in
            gracedAt = lab.model.timers.has(.grace) ? gracedAt ?? lab.now : nil
            return gracedAt != nil
        }
        wait(1000) { $0.phase != .open }
        return now - gracedAt!
    }
}
