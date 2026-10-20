import CoreGraphics
@testable import SitRepPanel
import Testing

/// The strip over the board as `watch` prints it: its marks are core's rows in core's order, and it decides only how a
/// change moves; a click names the session it jumps to and spins until the jump answers; a drag says where it left the
/// strip.
struct StripBoardTests {
    private static let minute = 60_000.0

    /// The prototype's rule would put a new ask after every needs you a window holds; core's order decides instead.
    @Test func aNewNeedsYouMovesInAtOnceUnderTheRowCoreHasAboveIt() {
        let lab = StripLab()
        var ask = StripLab.ask
        ask.since = -30 * Self.minute

        lab.newAsk(ask)

        #expect(lab.model.display.prefix(5) == ["s1", "s9", "s2", "s3", "s4"])
        #expect(lab.model.mark(.session("s9"))!.sc.x < 1)
    }

    @Test func aNeedsYouNewOnTheLineFlashesTwice() {
        var lab = StripLab()

        lab.newAsk(StripLab.ask)
        lab.wait(1000) { $0.model.mark(.session("s9"))!.arrived > -1e8 }

        #expect(lab.model.mark(.session("s9"))!.flashes.count == 2)
    }

    /// As on a run's first line, or a resumed one: what needs Lee with nothing new comes in as the marks re-sort, and
    /// nothing flashes.
    @Test func aNeedsYouWithNothingNewComesInUnflashedAsTheMarksReSort() {
        var lab = StripLab()

        lab.add([StripLab.ask])
        lab.settle()

        let mark = lab.model.mark(.session("s9"))!
        #expect(lab.model.display == StripLab.core(StripLab.prototype + [StripLab.ask]).map(\.id))
        #expect(mark.flashes.isEmpty && mark.arrived < 0)
        #expect(lab.frame.marks.allSatisfy { $0.flash == 0 && $0.wash == 0 })
    }

    /// Core puts DocMan's working row after Turnstile's: it shows in place, then the strip takes core's order, where
    /// the panel's old sort, longest running first, would have kept DocMan's first.
    @Test func aChangeShowsInPlaceThenTheMarksTakeCoresOrder() {
        var lab = StripLab()
        var docMan = StripLab.prototype[6]
        docMan.title = "Reading the reports"
        let board = Array(StripLab.prototype.prefix(6)) + [StripLab.prototype[7], docMan]

        lab.model.show(board, new: [])
        lab.step()
        #expect(lab.model.display.suffix(2) == ["s7", "s8"])
        #expect(lab.model.session("s7")?.title == "Reading the reports")

        lab.wait(1500)

        #expect(lab.model.display == board.map(\.id))
    }

    /// A row changed with its tab out: the tab eases to its new words' measure, rather than squeezing them into the
    /// old. A count's tab keeps its size as its rows change, as the prototype's recording has it.
    @Test func aTabOutTakesItsChangedRowsMeasure() throws {
        var lab = StripLab()
        lab.open("s5")
        let was = try #require(lab.live).w.x
        var fumi = StripLab.prototype[4]
        fumi.title = "Sketched"

        lab.change(fumi)
        lab.settle()

        #expect(was > StripTuning.tabMin)
        #expect(abs(try #require(lab.live).w.x - StripTuning.tabMin) < 0.5)
    }

    @Test func aRowGoneFadesWhereItIsAndTheRestCloseUp() {
        var lab = StripLab()
        let y = lab.model.layout.y(of: "s6")

        lab.remove(["s5"])
        lab.step()

        let gone = lab.model.mark(.session("s5"))!
        #expect(!lab.model.display.contains("s5"))
        #expect(gone.removing && gone.op.target == 0)
        #expect(lab.model.layout.y(of: "s6")! < y!)
    }

    @Test func theSameBoardAgainMovesNothing() {
        var lab = StripLab()
        lab.settle()

        lab.model.show(lab.model.sessions, new: [])
        lab.step()

        #expect(!lab.frame.isMoving)
    }

    @Test func aClickOnAMarkNamesItsSessionAndItsSpinEndsAsTheJumpAnswers() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 243))
        lab.wait(50)

        let jumps = lab.model.click(at: lab.pointer!)
        lab.wait(100)
        #expect(jumps?.id == "s6")
        #expect(lab.frame.isJumping)

        lab.model.jumpAnswered()
        lab.step()

        #expect(!lab.frame.isJumping && lab.model.jumping == nil)
        #expect(lab.model.mark(.session("s6"))!.sc.target == 1)
    }

    @Test func aClickOnATabNamesItsSessionAndItsTabDrawsBackAsTheJumpAnswers() {
        var lab = StripLab()
        lab.open("s5")
        let tab = lab.frame.tabs.first { $0.isLive }!

        let jumps = lab.model.click(at: CGPoint(x: tab.clip.midX, y: tab.clip.midY))
        lab.wait(50)
        lab.model.jumpAnswered()
        lab.step()

        #expect(jumps?.id == "s5")
        #expect(lab.model.jumping == nil && lab.live == nil)
    }

    @Test func anAwayMarkAndACountNameNoSession() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        StripLab.asks.prefix(2).forEach(lab.newAsk)
        lab.settle()

        #expect(lab.model.click(at: lab.on("s4")) == nil)
        #expect(lab.model.click(at: lab.on(.moreNeeds)) == nil)
        #expect(lab.live?.key == .moreNeeds)
    }

    @Test func aReleaseThatIsNoDragIsAClick() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 243))
        lab.wait(50)

        lab.model.press(at: lab.pointer!)
        lab.step()

        #expect(lab.model.release(at: lab.pointer!) == .jump(StripLab.prototype[5]))
    }

    /// At Grows the drag says how far down the screen it left the strip's centre, which the notch takes too.
    @Test func aDragAtGrowsSaysWhereAlongTheEdgeItLeftTheStrip() {
        var lab = StripLab(length: .grows)
        lab.pointer = lab.on("s5")
        lab.step()
        let centre = lab.model.layout.top + lab.model.layout.length / 2

        lab.model.press(at: lab.pointer!)
        lab.pointer!.y += 50
        lab.step()

        let dropped = lab.model.release(at: lab.pointer!)
        #expect(dropped == .dropped(along: (centre + 50) / StripLab.stage.height, across: false))
    }

    /// Past the screen's middle, at either length, letting go is for the other edge.
    @Test(arguments: [StripLength.grows, .full])
    func aDragLetGoPastTheMiddleIsForTheOtherEdge(_ length: StripLength) {
        var lab = StripLab(length: length)
        lab.pointer = lab.on("s5")
        lab.step()

        lab.model.press(at: lab.pointer!)
        lab.pointer!.x = StripLab.stage.width / 2 + 1
        lab.step()
        #expect(lab.model.isDragging && lab.model.isAcross)

        guard case let .dropped(_, across) = lab.model.release(at: lab.pointer!) else {
            Issue.record("no drop")
            return
        }
        #expect(across)
        #expect(!lab.model.isDragging)
    }

    /// Lee's place for the notch is the strip's centre at Grows, as the settings change it and on another screen.
    @Test func atGrowsTheStripCentresWhereAlongPutsIt() {
        var lab = StripLab(sessions: Array(StripLab.prototype.prefix(3)), length: .grows)

        lab.model.along = 0.6
        lab.settle()
        #expect(abs(lab.model.layout.top + lab.model.layout.length / 2 - 0.6 * 626) < 1e-9)

        let taller = StripStage(width: 1076, height: 900, menu: 26)
        _ = lab.model.frame(StripInput(time: lab.now + 16, pointer: nil, stage: taller))
        #expect(abs(lab.model.centre - 0.6 * 900) < 1e-9)
    }
}
