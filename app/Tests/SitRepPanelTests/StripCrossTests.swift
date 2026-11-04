import CoreGraphics
@testable import SitRepPanel
import Testing

/// The strip as the view meets it between frames and across edges: a drag let go past the screen's middle crosses as
/// the prototype's `moveEdge` does, a re-grab meanwhile is refused, a hidden drag goes back, frames after a pause
/// measure no false speed, and a board after a long idle still flashes in full.
struct StripCrossTests {
    /// The strip at Grows, the pointer on Fumi's mark, a press there carried past the screen's middle and let go.
    private static func droppedAcross(reducesMotion: Bool = false) -> StripLab {
        var lab = StripLab(length: .grows, reducesMotion: reducesMotion)
        lab.pointer = lab.on("s5")
        lab.step()
        lab.model.press(at: lab.pointer!)
        lab.pointer!.x = StripLab.stage.width / 2 + 1
        lab.step()
        lab.model.release(at: lab.pointer!)
        return lab
    }

    /// The prototype's `moveEdge`: drained over 170ms, its marks out in 90, swapped at 200, grown back over 320, its
    /// marks back over 260, taking the pointer again at 520.
    @Test func aDropAcrossDrainsSwapsAndGrowsOutOfTheOtherEdge() {
        var lab = Self.droppedAcross()
        let from = lab.model.t
        var swaps: [Double] = []

        #expect(lab.model.sw.target == 0 && lab.model.mvis.target == 0)
        lab.wait(1000) { lab in
            if lab.frame.swapsEdge {
                swaps.append(lab.model.t - from)
            }
            return false
        }

        #expect(swaps.count == 1 && abs(swaps[0] - 200) < 17)
        #expect(!lab.model.crossing)
        #expect(lab.model.sw.target == StripTuning.width && lab.model.mvis.target == 1)
    }

    /// It swaps drained to a hair; drained all the way, there is no strip to draw, and nothing on it takes the pointer.
    @Test func drainedItSwapsAndDrainedAllTheWayThereIsNoStrip() {
        var lab = Self.droppedAcross()
        var atSwap: Double?

        lab.wait(400) { lab in
            if lab.frame.swapsEdge {
                atSwap = lab.model.sw.x
            }
            return atSwap != nil
        }
        lab.model.sw.snap(0)
        lab.step()

        #expect(atSwap.map { $0 < 2 } == true)
        #expect(lab.frame.strip.isEmpty)
        #expect(!lab.model.inStrip(Vec(18, lab.model.yOf(.session("s5")))))
    }

    @Test func underReducedMotionItSwapsAtOnceItsOldBlackFading() {
        var lab = Self.droppedAcross(reducesMotion: true)

        lab.step()

        #expect(lab.frame.swapsEdge)
        #expect(lab.model.sw.x == StripTuning.width)
        #expect(lab.frame.fading != nil)
    }

    /// A press just after a drop across, while it crosses, is refused, and its mouse-up, though it comes once the strip
    /// is across, clicks nothing: the edge never flips under a live drag.
    @Test func aReGrabWhileItCrossesIsRefused() {
        var lab = Self.droppedAcross()
        lab.wait(100)
        let mark = CGPoint(x: 18, y: lab.model.yOf(.session("s5")))

        lab.model.press(at: mark)
        lab.step()

        #expect(!lab.frame.isHeld && !lab.model.isDragging)
        #expect(lab.model.click(at: mark) == nil)

        lab.wait(600)

        #expect(!lab.model.crossing)
        #expect(lab.model.release(at: mark) == .nothing)
    }

    /// Growing back out of the other edge, 200 to 520ms on, the strip takes the pointer's place again, but not yet a
    /// press: a re-grab then would flip it under a live drag.
    @Test func aPressAsItGrowsBackIsRefusedToo() {
        var lab = Self.droppedAcross()
        lab.wait(350)
        let mark = CGPoint(x: 18, y: lab.model.yOf(.session("s5")))

        #expect(lab.model.crossing && lab.model.inStrip(Vec(mark.x, mark.y)))
        lab.model.press(at: mark)

        #expect(lab.model.press == nil && !lab.model.pressesTab)
    }

    /// Hidden mid-drag, its mouse-up perhaps never to come: the strip goes back where it was, and nothing comes of the
    /// press.
    @Test func aPressGivenUpPutsTheStripBackAndClicksNothing() {
        var lab = StripLab(length: .grows)
        let top = lab.model.layout.top
        lab.pointer = lab.on("s5")
        lab.step()
        lab.model.press(at: lab.pointer!)
        lab.pointer!.y += 50
        lab.step()

        lab.model.cancelPress()

        #expect(!lab.model.isDragging && lab.model.press == nil)
        #expect(abs(lab.model.layout.top - top) < 1e-9)
        #expect(lab.model.release(at: lab.pointer!) == .nothing)
    }

    /// Frames that slept never saw the pointer move meanwhile: their first is measured from nothing, not from where
    /// the pointer rested minutes before.
    @Test func framesWokenAfterASleepMeasureNoSpeedFromBeforeIt() {
        var lab = StripLab(pointer: CGPoint(x: 600, y: 400))
        lab.settle()
        lab.now += 600_000
        lab.pointer = CGPoint(x: 100, y: 400)

        lab.step()

        #expect(lab.model.pointerSpeed() == 0)
    }

    /// Frames idle for ten minutes, then a board brings a new ask: its ring still flashes twice in full, and it is
    /// washed for the whole of its hold.
    @Test func aBoardAfterALongIdleStillFlashesInFull() {
        var lab = StripLab()
        lab.settle()
        lab.now += 600_000
        lab.step()

        lab.newAsk(StripLab.ask)
        var flash: [Double] = [], washed: [Double] = []
        lab.wait(2200) { lab in
            let mark = lab.frame.marks.first { $0.key == .session("s9") }!
            flash.append(mark.flash)
            if mark.wash > 0 {
                washed.append(mark.wash)
            }
            return false
        }

        let peaks = zip(flash.dropFirst(), zip(flash, flash.dropFirst(2))).filter { here, around in
            here > around.0 && here >= around.1
        }.map(\.0)
        #expect(peaks.count == 2 && peaks.allSatisfy { $0 > 0.9 })
        #expect(washed.prefix(80).allSatisfy { $0 == 1 })
    }

    /// A new ask's row changing within its flash keeps its mark, its flash and its wash.
    @Test func aRowChangingMidFlashKeepsItsFlash() {
        var lab = StripLab()
        lab.newAsk(StripLab.ask)
        lab.wait(1000) { $0.model.mark(.session("s9"))!.arrived > -1e8 }
        let mark = lab.model.mark(.session("s9"))!, arrived = mark.arrived
        var reworded = StripLab.ask
        reworded.lines[0].title = "Choose the diff budget, again"

        lab.change(reworded)
        lab.wait(400)

        #expect(lab.model.mark(.session("s9")) === mark)
        #expect(mark.arrived == arrived && mark.flashes.count == 2)
        #expect(lab.frame.marks.first { $0.key == .session("s9") }!.wash == 1)
    }

    /// A pointer parked on a tab, then flicked far off in one move: that move wakes the frames, and the strip
    /// settles, its tab drawn back.
    @Test func aFlickAwayFromAParkedPointerStillSettlesTheStrip() {
        var lab = StripLab()
        lab.open("s5")
        let settled = lab.settle()
        let away = CGPoint(x: 900, y: 40)

        #expect(settled && lab.frame.pointer != nil)
        #expect(lab.frame.wakes(pointer: away))

        lab.pointer = away
        let drawnBack = lab.settle()

        #expect(drawnBack && lab.model.tabs.isEmpty)
    }
}
