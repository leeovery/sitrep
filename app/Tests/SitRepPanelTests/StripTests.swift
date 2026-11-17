import CoreGraphics
@testable import SitRepPanel
import SitRepPanelTestSupport
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct StripTests {
    /// The strip sorts nothing itself: its marks take the board's order as core gives it, its asks newest first, not
    /// the order the prototype's timelines were recorded in, which the lab sorts its sessions to (`StripLab.core`).
    @Test func itsMarksAreInTheBoardsOrderAsCoreGivesItSortingNothingThemselves() {
        let board = ["s3", "s2", "s1", "s4", "s5", "s6", "s7", "s8"].map { id in
            StripLab.prototype.first { $0.id == id }!
        }
        let input = StripInput(time: 0, pointer: nil, stage: StripLab.stage, reducesMotion: false)

        let strip = Strip(
            feel: .lees, length: .full, maxLength: .full, sessions: board, measure: StripLab.measure, input
        )

        #expect(strip.display == ["s3", "s2", "s1", "s4", "s5", "s6", "s7", "s8"])
    }

    @Test func aMarkIsEvery30FromUnderTheTopEndWithTheHairline21AndAHalfUnderNeedsYou() {
        let lab = StripLab()

        let ys = lab.model.layout.places.map(\.y)

        #expect(ys == [80, 110, 140, 170, 200, 230, 273, 303])
        #expect(lab.model.layout.hairs[.working] == 251.5)
        #expect(lab.frame.hairlines[0].y == 251.5 && lab.frame.hairlines[0].alpha == 1)
        expectEvery(lab.frame.marks) { $0.centre.x == 18 && $0.scale == 1 && $0.alpha == 1 }
    }

    @Test func aMarksLettersAreTheProjectsTwoCapitalsElseItsFirstTwo() {
        let letters = ["VanArsdel", "BlueYonder", "Woodgrove", "trey", "Adventure Works"].map {
            Session(id: "", project: $0, kind: .turn, title: "", sub: "", since: 0).letters
        }

        #expect(letters == ["VA", "BY", "Wo", "tr", "AW"])
    }

    @Test func aMarksRingCarriesItsState() {
        let lab = StripLab()

        let looks = lab.frame.marks.map(\.look)

        #expect(looks == [.needs, .needs, .needs, .away, .turn, .turn, .working, .working])
    }

    @Test func thePointerCrossingTheStripWithinTheDwellOpensNothing() {
        var lab = StripLab(pointer: CGPoint(x: 200, y: 200))
        lab.settle()

        lab.pointer = CGPoint(x: 18, y: 200)
        lab.wait(100)
        lab.pointer = CGPoint(x: 200, y: 200)
        lab.settle()

        #expect(lab.model.tabs.isEmpty)
    }

    /// The pointer coming onto a mark, resting through the reach, the dwell and the pour, moving out onto its tab and
    /// off: the ring lifts once, easing in over 110ms, stays lifted while the mark or its tab has the pointer, and
    /// eases back once, never flickering in between; a needs you and a working mark alike.
    @Test(arguments: ["s1", "s7"])
    func aMarksRingLiftsOnceUnderThePointerAndSettlesBackOnceAfter(_ id: String) {
        var lab = StripLab(pointer: CGPoint(x: 300, y: 600))
        lab.settle()
        let y = lab.model.yOf(.session(id))
        var seen: [(t: Double, lifted: Bool, lift: Double)] = []
        func frames(_ n: Int, moving dx: Double = 0) {
            for _ in 0 ..< n {
                lab.pointer?.x += dx
                lab.step()
                let mark = lab.frame.marks.first { $0.key == .session(id) }!
                seen.append((lab.model.t, mark.isLifted, mark.lift))
            }
        }

        lab.pointer = CGPoint(x: 120, y: y)
        frames(27, moving: -4)
        frames(30)
        frames(30, moving: 4)
        lab.pointer = nil
        frames(120)

        let on = seen.firstIndex { $0.lifted }!, off = seen.lastIndex { $0.lifted }! + 1
        expectEvery(seen[on ..< off]) { $0.lifted }
        #expect(!seen[..<on].contains { $0.lifted || $0.lift > 0 })
        expectEvery(seen[off...]) { !$0.lifted }
        let rising = seen[on ..< off].map(\.lift), falling = seen[(off - 1)...].map(\.lift)
        expectEvery(zip(rising, rising.dropFirst())) { $0 <= $1 }
        expectEvery(zip(falling, falling.dropFirst())) { $0 >= $1 }
        #expect(seen[on + 1].lift > 0 && seen[on + 1].lift < 0.5)
        let full = seen[on...].first { $0.lift > 0.9 }!
        #expect(full.t - seen[on].t <= StripTuning.liftFade)
        #expect(rising.last! > 0.999 && falling.last! < 0.001)
    }

    @Test func restingOnAMarkTheEdgeReaches3TowardItThenAfter120msItsRowPoursOut() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 200))

        lab.wait(110)
        #expect(lab.live?.phase == .reach)
        #expect(abs(lab.live!.w.x - 3) < 0.2)

        lab.wait(20)
        #expect(lab.live?.phase == .open)
    }

    @Test func aTabIsItsRowsWidthAndFiftyTwoDeepFlaredTenIntoTheStrip() {
        var lab = StripLab()

        lab.open("s5")

        let tab = lab.frame.tabs[0], drawn = tab.outline.boundingBoxOfPath
        #expect(abs(drawn.minX - 35) < 1e-9)
        #expect(abs(drawn.maxX - (36 + 321)) < 1e-2)
        #expect(abs(drawn.minY - (200 - 26 - 10)) < 1e-2)
        #expect(abs(drawn.maxY - (200 + 26 + 10)) < 1e-2)
        #expect(tab.radius == 16)
        #expect(abs(tab.clip.width - 321) < 1e-2 && abs(tab.clip.minY - 174) < 1e-2 && abs(tab.clip.height - 52) < 1e-2)
    }

    @Test(arguments: [(100.0, 240.0), (300, 316), (400, 360)])
    func aTabIsAsWideAsItsRowNeedsFrom240To360(natural: Double, width: Double) {
        let measure = StripMeasure.uniform(natural)
        let input = StripInput(time: 0, pointer: nil, stage: StripLab.stage)
        let strip = Strip(
            length: .grows, maxLength: .full, along: Tuning.notchAt, sessions: StripLab.prototype, measure: measure,
            input
        )

        #expect(strip.buildWords(.session("s5")).W == width)
    }

    @Test func pouringTheWordsComeInFrom55PercentOfTheDepthTo95() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 200))
        var seen: [(depth: Double, alpha: Double)] = []

        lab.wait(600) { lab in
            if let words = lab.frame.tabs.first?.words.first {
                seen.append((lab.live!.w.x / 321, words.alpha))
            }
            return false
        }

        expectEvery(seen.filter { $0.depth <= 0.55 }) { $0.alpha == 0 }
        #expect(seen.contains { $0.depth > 0.55 && $0.depth < 0.95 && $0.alpha > 0 && $0.alpha < 1 })
        #expect(seen.last!.alpha == 1)
    }

    @Test func onceATabIsOutTheNextMarkTakesNoWaitTheOneTabGlidesThere() {
        var lab = StripLab()
        lab.open("s5")
        let tab = lab.live!

        lab.pointer = lab.on("s6")
        lab.step()

        #expect(lab.live === tab)
        #expect(tab.key == .session("s6"))
        #expect(tab.y.target == 230)
        #expect(lab.model.tabs.count == 1)
    }

    @Test func leavingSlowlyTheTabWaits300msThenItsWordsGoIn60msAndTheBlack30msLater() {
        var lab = StripLab()
        lab.open("s5")

        let left = lab.leave(by: 1)
        lab.wait(1000) { $0.live == nil }

        #expect(abs(lab.model.t - left - 300) < 17)
        let closing = lab.model.tabs[0], closed = lab.model.t
        lab.step()
        #expect(abs(closing.w.x - 321) < 1e-2)
        #expect(abs(lab.frame.tabs[0].words[0].alpha - (1 - (lab.model.t - closed) / 60)) < 1e-9)
        lab.step()
        lab.step()
        #expect(closing.w.x < 320)
        lab.step()
        #expect(lab.frame.tabs[0].words.isEmpty)
    }

    @Test func leavingFastTheGraceIsAFifth() {
        var lab = StripLab()
        lab.open("s5")

        let left = lab.leave(by: 40)
        lab.wait(1000) { $0.live == nil }

        #expect(abs(lab.model.t - left - 60) < 17)
    }

    @Test func drawingBackItDentsTheStripByThreeAtMostAndThenItGoes() {
        var lab = StripLab()
        lab.open("s5")
        var deepest = 0.0

        lab.pointer = CGPoint(x: 600, y: 400)
        lab.model.clickElsewhere()
        lab.wait(1500) { lab in
            deepest = min(deepest, lab.model.tabs.first?.g?.w ?? 0)
            return lab.model.tabs.isEmpty
        }

        #expect(deepest < -1 && deepest >= -3)
        #expect(lab.model.tabs.isEmpty)
    }

    @Test func aNewNeedsYouMovesInAtOnceEvenUnderThePointerAfterTheNeedsYouAWindowHolds() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 600))
        lab.settle()

        lab.newAsk(StripLab.ask)
        lab.settle()

        #expect(lab.model.display == ["s1", "s2", "s3", "s9", "s4", "s5", "s6", "s7", "s8"])
        #expect(lab.model.layout.places.map(\.y) == [80, 110, 140, 170, 200, 230, 260, 303, 333])
    }

    @Test func aNewAwayAskMovesInAfterTheAwayOnes() {
        let lab = StripLab()
        var away = StripLab.ask
        away.away = true

        lab.newAsk(away)

        #expect(lab.model.display.prefix(5) == ["s1", "s2", "s3", "s4", "s9"])
    }

    @Test func noSwellsAtAllLeaveANewMarksRingUnflashed() {
        var feel = StripFeel.lees
        feel.swells = -1
        var lab = StripLab(feel: feel)

        lab.newAsk(StripLab.ask)
        lab.wait(1000)

        #expect(lab.model.mark(.session("s9"))!.flashes.isEmpty)
        #expect(lab.frame.marks.first { $0.key == .session("s9") }!.flash == 0)
    }

    @Test func aNewMarksRingFlashesTwice450msApartAndItIsWashedForTwoSeconds() {
        var lab = StripLab()
        lab.newAsk(StripLab.ask)
        lab.wait(1000) { $0.model.mark(.session("s9"))!.arrived > -1e8 }
        let arrived = lab.model.t
        var flash: [(t: Double, level: Double)] = [], washed: [(t: Double, level: Double)] = []

        lab.wait(2200) { lab in
            let mark = lab.frame.marks.first { $0.key == .session("s9") }!
            flash.append((lab.model.t - arrived, mark.flash))
            washed.append((lab.model.t - arrived, mark.wash))
            return false
        }

        let peaks = zip(flash.dropFirst(), zip(flash, flash.dropFirst(2))).filter { here, around in
            here.level > around.0.level && here.level >= around.1.level
        }.map(\.0.t)
        #expect(peaks.count == 2)
        #expect(abs(peaks[0] - 70) < 17 && abs(peaks[1] - 520) < 17)
        expectEvery(washed.filter { $0.t < 1500 }) { $0.level == 1 }
        expectEvery(washed.filter { $0.t >= 2000 }) { $0.level == 0 }
    }

    /// A change to the order within a group, the first session asking again and so the newest ask, waits until the
    /// pointer has been off the strip a second.
    @Test func aChangeWaitsUntilThePointerHasBeenOffTheStripASecond() {
        var lab = StripLab()
        lab.open("s6")
        var askedAgain = StripLab.prototype[0]
        askedAgain.lines[0].title = "Approve the third floor plan"
        askedAgain.lines[0].since = 0

        lab.change(askedAgain)
        lab.wait(1500)
        #expect(lab.model.display.first == "s1")

        lab.pointer = CGPoint(x: 600, y: 230)
        lab.step()
        let left = lab.model.t
        lab.wait(2000) { $0.model.display.first != "s1" }

        #expect(abs(lab.model.t - left - 1000) < 17)
        #expect(lab.model.display.prefix(4) == ["s2", "s3", "s1", "s4"])
    }

    @Test func aTabOutWhileTheMarksSlideStaysWithItsMarkThenGlidesToTheMarkUnderThePointer() {
        var lab = StripLab()
        lab.open("s6")
        let tab = lab.live!

        lab.newAsk(StripLab.ask)
        let mark = lab.model.mark(.session("s6"))!
        var apart = 0.0
        lab.wait(1000) { lab in
            apart = max(apart, abs(tab.y.x - mark.y.x))
            return !lab.model.freeze
        }

        #expect(tab.key == .session("s6"))
        #expect(apart < 1e-9)
        #expect(abs(mark.y.x - 260) < 0.5)
        lab.step()
        #expect(tab.key == .session("s5"))
    }

    /// Its tab says no window holds it, and a click on the tab or on the mark carries its session on (stage 8).
    @Test func anAwayMarksTabSaysNoWindowHoldsItAndItAndTheMarkTakeAClick() {
        var lab = StripLab()
        lab.open("s4")

        guard case let .row(session) = lab.frame.tabs[0].words.last?.content else {
            Issue.record("no row")
            return
        }
        #expect(session.sub == "No window holds it. Carry it on in Claude.")
        #expect(lab.model.click(at: CGPoint(x: lab.frame.tabs[0].clip.midX, y: 170)).session?.id == "s4")
        #expect(lab.model.jumping != nil)

        let marked = StripLab()

        #expect(marked.model.click(at: CGPoint(x: 18, y: 170)).session?.id == "s4")
        #expect(marked.model.jumping != nil)
    }

    @Test func aClickOnAMarkBeforeItsTabIsOutPressesTheRingIn450msThenNoTabWhileThePointerStays() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 230))
        lab.wait(50)

        lab.model.click(at: lab.pointer!)
        lab.wait(400)

        let mark = lab.frame.marks.first { $0.key == .session("s6") }!
        #expect(mark.isJumping && abs(mark.scale - 0.88) < 1e-3)

        lab.wait(1000)
        #expect(lab.model.jumping == nil)
        #expect(lab.model.tabs.isEmpty)
        #expect(abs(lab.model.mark(.session("s6"))!.sc.x - 1) < 1e-3)

        lab.pointer = lab.on("s7")
        lab.wait(400)
        #expect(lab.live?.phase == .open)
    }

    @Test func aClickOnAnOpenTabPressesItInSpinsAndDrawsItBack() {
        var lab = StripLab()
        lab.open("s7")

        lab.model.click(at: CGPoint(x: 100, y: 273))
        lab.wait(200)

        #expect(lab.frame.tabs[0].words.last!.isPressed)
        #expect(abs(lab.live!.press.x - 4) < 0.1)
        lab.wait(300)
        expectEvery(lab.model.tabs) { $0.phase == .closing }
    }

    @Test func tooManyTheLastPlaceIsTheCountAndNeedsYouNeverFolds() {
        var lab = StripLab()

        lab.add(StripLab.tooMany)
        lab.settle()

        let count = lab.frame.marks.last!
        #expect(count.look == .count && count.text == "+15")
        #expect(count.centre.y == 543)
        #expect(lab.model.layout.places.prefix(4).map(\.id) == ["s1", "s2", "s3", "s4"])
    }

    @Test func aClickOnTheCountOpensItsTabAtOnceAndARowOnItJumps() {
        var lab = StripLab()
        lab.add(StripLab.tooMany)
        lab.settle()

        lab.pointer = CGPoint(x: 18, y: 543)
        lab.step()
        lab.model.click(at: lab.pointer!)
        lab.step()
        #expect(lab.live?.key == .count(.working) && lab.live?.phase == .open)
        #expect(lab.model.jumping == nil)

        lab.settle()
        let tab = lab.frame.tabs[0], first = tab.box.minY + StripTuning.rowsPad + 20
        #expect(tab.row(at: CGPoint(x: 100, y: first)) == lab.model.layout.rest(of: .working)[0])
        lab.model.click(at: CGPoint(x: 100, y: first))
        lab.step()
        #expect(lab.frame.tabs[0].words.last!.pressedRow == lab.model.layout.rest(of: .working)[0])
    }

    /// Pressed and let go on a row of an open count's tab, past the strip: the press is the tab's, and it jumps.
    @Test func aPressLetGoOnAnOpenTabsRowJumps() throws {
        var lab = StripLab()
        lab.add(StripLab.tooMany)
        lab.open(.count(.working))
        let tab = lab.frame.tabs[0], row = CGPoint(x: 100, y: tab.box.minY + StripTuning.rowsPad + 20)
        let first = try #require(lab.model.layout.rest(of: .working).first.flatMap(lab.model.session))

        lab.model.press(at: row)

        #expect(lab.model.release(at: row) == .jump(first))
    }

    @Test func underReducedMotionThereIsNoReachTheMarksSnapAndATabFadesIn() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 200), reducesMotion: true)

        lab.wait(100)
        #expect(lab.live!.w.x == 0)

        lab.wait(40)
        #expect(lab.live!.phase == .open)
        #expect(lab.live!.w.x == 321)
        #expect(lab.live!.alpha.x < 1)
        lab.settle()
        #expect(abs(lab.live!.alpha.x - 1) < 1e-2)

        lab.pointer = CGPoint(x: 600, y: 200)
        lab.newAsk(StripLab.ask)
        lab.step()
        #expect(lab.model.mark(.session("s5"))!.y.x == 230)
    }

    @Test func aClickPassesThroughButOnTheStripAndAnOpenTab() {
        var lab = StripLab()

        #expect(lab.frame.hits(CGPoint(x: 10, y: 400)))
        #expect(!lab.frame.hits(CGPoint(x: 10, y: 20)))
        #expect(!lab.frame.hits(CGPoint(x: 100, y: 200)))

        lab.open("s5")

        #expect(lab.frame.hits(CGPoint(x: 100, y: 200)))
        #expect(!lab.frame.hits(CGPoint(x: 400, y: 200)))
    }

    /// A working mark's tab poured and drawn back, the pointer gone: its ring's lift settles with everything else, and
    /// nothing moves, its arcs turning on in the views alone.
    @Test func afterAHoverTheLiftSettlesAndTheFramesStop() {
        var lab = StripLab()
        lab.open("s7")

        lab.pointer = nil
        let settled = lab.settle()

        #expect(settled)
        expectEvery(lab.model.marks) { $0.lift.isAtRest && $0.lift.x == 0 }
        #expect(!lab.frame.wakes(pointer: nil))
    }

    /// Off the strip, a move wakes nothing until it comes onto the strip.
    @Test func withThePointerAwayOnlyAMoveOntoTheStripWakesFrames() {
        var lab = StripLab(pointer: CGPoint(x: 600, y: 400))
        let settled = lab.settle()

        #expect(settled)
        #expect(!lab.frame.wakes(pointer: lab.pointer))
        #expect(lab.frame.wakes(pointer: CGPoint(x: 10, y: 400)))
    }

    /// A pointer resting on a tab poured out and still moves nothing: no frames run until it moves, and then any move
    /// wakes them, since only the model can tell it has left.
    @Test func aStillPointerOnAStillTabWantsNoFramesAndAnyMoveWakesThem() {
        var lab = StripLab()
        lab.open("s5")
        lab.pointer = CGPoint(x: 120, y: lab.model.yOf(.session("s5")))
        let settled = lab.settle()

        #expect(settled)
        #expect(lab.live?.phase == .open)
        #expect(lab.frame.wakes(pointer: CGPoint(x: 600, y: 40)))
    }

    /// Left on a mark it just jumped from, no tab opens: a still pointer there moves nothing, and any move wakes them.
    @Test func aStillPointerOnTheStripWithNoTabWantsNoFrames() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 230))
        lab.wait(50)
        lab.model.click(at: lab.pointer!)
        let settled = lab.settle()

        #expect(settled)
        #expect(lab.model.tabs.isEmpty && lab.frame.isOver)
        #expect(lab.frame.wakes(pointer: CGPoint(x: 600, y: 400)))
    }
}
