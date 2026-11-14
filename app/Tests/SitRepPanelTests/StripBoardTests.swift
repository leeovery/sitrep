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
        ask.lines[0].since = -30 * Self.minute

        lab.newAsk(ask)

        #expect(lab.model.display.prefix(5) == ["s1", "s9", "s2", "s3", "s4"])
        #expect(lab.model.mark(.session("s9"))!.sc.x < 1)
    }

    /// The marks are the rows in the panel's order as it comes, and Needs you's, its asks and then its stopped, are all
    /// over the one hairline; working and on its own work under it (14 November 2026).
    @Test func needsYouItsAsksThenItsStoppedIsAllOverTheHairlineWorkingUnderIt() throws {
        let order = ["s3", "s2", "s1", "s4", "s5", "s6", "s7", "s8", "s9"]
        let waiting = Session(id: "s9", project: "Kit", kind: .onItsWork, title: "Waiting on", sub: "Kit", since: 0)
        let sessions = try order.map { id in try #require((StripLab.prototype + [waiting]).first { $0.id == id }) }
        let input = StripInput(time: 1000, pointer: nil, stage: StripLab.stage, reducesMotion: false)
        let strip = Strip(
            feel: .lees, length: .full, maxLength: .full, sessions: sessions, measure: StripLab.measure, input
        )
        let ys = try order.map { id in try #require(strip.layout.y(of: id)) }
        let hair = try #require(strip.layout.hair)

        #expect(strip.display == order)
        #expect(ys == ys.sorted())
        #expect(ys.prefix(6).allSatisfy { $0 < hair })
        #expect(ys.suffix(3).allSatisfy { $0 > hair })
    }

    @Test func aNeedsYouNewOnTheLineFlashesTwice() {
        var lab = StripLab()

        lab.newAsk(StripLab.ask)
        lab.wait(1000) { $0.model.mark(.session("s9"))!.arrived > -1e8 }

        #expect(lab.model.mark(.session("s9"))!.flashes.count == 2)
    }

    /// A session on the strip coming to need Lee from working arrives as a new needs you does: it moves into needs you
    /// at once, under the needs you the panel's order has above it, and its ring flashes twice.
    @Test func aWorkingMarkComingToNeedLeeMovesInAtOnceAndFlashesTwice() throws {
        var lab = StripLab()
        var asking = try #require(lab.model.session("s7"))
        asking.kind = .needs
        asking.lines[0].title = "Approve the plan"
        asking.lines[0].since = -30 * Self.minute

        lab.arrive(asking)

        #expect(lab.model.display.prefix(5) == ["s1", "s7", "s2", "s3", "s4"])
        #expect(lab.model.needsSlot.contains("s7"))
        #expect(lab.wait(1000) { $0.model.mark(.session("s7"))!.arrived > -1e8 })
        #expect(lab.model.mark(.session("s7"))!.flashes.count == 2)
    }

    /// A stopped session, already in Needs you, coming to ask flashes where it is, and moves up among the asks at the
    /// re-sort, as any change in Needs you does.
    @Test func aStoppedMarkComingToAskFlashesWhereItIsAndMovesAtTheReSort() throws {
        var lab = StripLab()
        var asking = try #require(lab.model.session("s5"))
        asking.kind = .needs
        asking.lines[0].title = "Approve the plan"
        asking.lines[0].since = -30 * Self.minute

        lab.arrive(asking)

        #expect(lab.model.display == StripLab.core(StripLab.prototype).map(\.id))
        #expect(lab.wait(1000) { $0.model.mark(.session("s5"))!.arrived > -1e8 })
        #expect(lab.model.mark(.session("s5"))!.flashes.count == 2)

        lab.wait(1500)

        #expect(lab.model.display.prefix(3) == ["s1", "s5", "s2"])
    }

    /// A needs you gaining a line new on the board stays where it is, and its ring flashes twice.
    @Test func aNeedsYouGainingALineFlashesTwiceWhereItIs() throws {
        var lab = StripLab()
        var asked = try #require(lab.model.session("s2"))
        asked.lines.append(Session.Line(title: "Pick the cache's size", since: 0))

        lab.arrive(asked)

        #expect(lab.model.display == StripLab.core(StripLab.prototype).map(\.id))
        #expect(lab.wait(1000) { $0.model.mark(.session("s2"))!.arrived > -1e8 })
        #expect(lab.model.mark(.session("s2"))!.flashes.count == 2)
    }

    /// A mark answered, still on the needs you side until the marks re-sort, that gains a new ask flashes where it is.
    @Test func anAnsweredMarkAskedAgainBeforeTheReSortFlashesWhereItIs() throws {
        var lab = StripLab()
        var answered = try #require(lab.model.session("s2"))
        answered.kind = .turn
        lab.change(answered)
        answered.kind = .needs

        lab.arrive(answered)

        #expect(lab.model.display == StripLab.core(StripLab.prototype).map(\.id))
        #expect(lab.wait(1000) { $0.model.mark(.session("s2"))!.arrived > -1e8 })
    }

    /// As on any run's first line: what needs Lee with nothing new comes in as the marks re-sort, and
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
        docMan.lines[0].title = "Reading the reports"
        let board = Array(StripLab.prototype.prefix(6)) + [StripLab.prototype[7], docMan]

        lab.model.show(board, new: [])
        lab.step()
        #expect(lab.model.display.suffix(2) == ["s7", "s8"])
        #expect(lab.model.session("s7")?.title == "Reading the reports")

        lab.wait(1500)

        #expect(lab.model.display == board.map(\.id))
    }

    /// A row changed with its tab out: the tab eases to its new words' measure, rather than squeezing them into the
    /// old. (A count's tab keeps its size as its rows change, as the prototype's recording pins:
    /// `StripTimelineTests.anAnswerOutOfTheCountReSortsOnceThePointerHasLeftAsThePrototypes`.)
    @Test func aTabOutTakesItsChangedRowsMeasure() throws {
        var lab = StripLab()
        lab.open("s5")
        let was = try #require(lab.live).w.x
        var fumi = StripLab.prototype[4]
        fumi.lines[0].title = "Sketched"

        lab.change(fumi)
        lab.settle()

        #expect(was > StripTuning.tabMin)
        #expect(abs(try #require(lab.live).w.x - StripTuning.tabMin) < 0.5)
    }

    /// Under reduced motion the tab takes its new size at once, its outline cross-fading from the old, as a glide's
    /// does, rather than jumping.
    @Test func underReducedMotionATabTakingItsNewMeasureCrossFades() throws {
        var lab = StripLab(reducesMotion: true)
        lab.open("s5")
        var fumi = StripLab.prototype[4]
        fumi.lines[0].title = "Sketched"

        lab.change(fumi)
        lab.step()

        #expect(lab.frame.fading != nil)
        #expect(try #require(lab.live).alpha.x < 1)
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
        var lab = StripLab(pointer: CGPoint(x: 18, y: 230))
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

    /// A click on needs you's count, or where a mark folded into it would be, names no session: it opens the count.
    @Test func aCountNamesNoSessionNorDoesAMarkFoldedIntoIt() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        StripLab.asks.prefix(2).forEach(lab.newAsk)
        lab.settle()

        #expect(lab.model.click(at: lab.on("s9")) == nil)
        #expect(lab.model.click(at: lab.on(.moreNeeds)) == nil)
        #expect(lab.live?.key == .moreNeeds)
    }

    @Test func aReleaseThatIsNoDragIsAClick() {
        var lab = StripLab(pointer: CGPoint(x: 18, y: 230))
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
