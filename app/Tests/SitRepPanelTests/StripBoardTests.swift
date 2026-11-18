import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The strip over the board as `watch` prints it: its marks are core's rows in core's order, and it decides only how a
/// change moves; a click names the session it jumps to and spins until the jump answers; a drag says where it left the
/// strip.
@Suite(.backstop)
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

    /// At launch, or whenever the strip goes from empty to several rows, each mark takes its final place at once, the
    /// rest of the update counted, and grows in there: none slides from a place the marks still to come would change.
    @Test func marksComingInTogetherEachTakeTheirFinalPlaceAtOnce() {
        var lab = StripLab(sessions: [], length: .grows)

        lab.add(StripLab.prototype)

        let places = lab.model.layout.places
        #expect(places.count == StripLab.prototype.count)
        expectEvery(places) { lab.model.mark(.session($0.id))?.y.x == $0.y }
        lab.settle()
        #expect(lab.model.layout.places.map(\.y) == places.map(\.y))
        expectEvery(places) { abs(lab.model.mark(.session($0.id))!.y.x - $0.y) < 0.01 }
    }

    /// An arrival placed out of the panel's order, a new ask landing in the count while an older away ask shows, waits
    /// for the re-sort as any order within a group does: held while the pointer rests on the strip, and a settle after
    /// it leaves, the strip takes the panel's order, the ask in the place the away one had.
    @Test func anArrivalOutOfThePanelsOrderTakesItAtTheSettle() throws {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.pointer = lab.on("s1")
        lab.wait(400)
        let fourth = try #require(lab.model.layout.y(of: "s4"))

        lab.newAsk(StripLab.ask)
        lab.wait(2000)
        #expect(lab.model.layout.rest(of: .needsYou) == ["s9", "s5", "s6"])

        lab.pointer = nil
        lab.wait(StripFeel.lees.settle + 100)

        #expect(lab.model.display == StripLab.core(lab.model.sessions).map(\.markID))
        #expect(lab.model.layout.rest(of: .needsYou) == ["s4", "s5", "s6"])
        #expect(lab.model.layout.y(of: "s9") == fourth)
    }

    /// The marks are the rows in the panel's order as it comes, and Needs you's, its asks and then its stopped, are all
    /// over the one hairline; working and on its own work under it (14 November 2026).
    @Test func needsYouItsAsksThenItsStoppedIsAllOverTheHairlineWorkingUnderIt() throws {
        let order = ["s3", "s2", "s1", "s4", "s5", "s6", "s7", "s8", "s9"]
        let waiting = Session(id: "s9", project: "Litware", kind: .onItsWork, title: "Waiting on", sub: "Litware", since: 0)
        let sessions = try order.map { id in try #require((StripLab.prototype + [waiting]).first { $0.id == id }) }
        let input = StripInput(time: 1000, pointer: nil, stage: StripLab.stage, reducesMotion: false)
        let strip = Strip(
            feel: .lees, length: .full, maxLength: .full, sessions: sessions, measure: StripLab.measure, input
        )
        let ys = try order.map { id in try #require(strip.layout.y(of: id)) }
        let hair = try #require(strip.layout.hairs[.working])

        #expect(strip.display == order)
        #expect(ys == ys.sorted())
        expectEvery(ys.prefix(6)) { $0 < hair }
        expectEvery(ys.suffix(3)) { $0 > hair }
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
        #expect(lab.model.slot["s7"] == .needsYou)
        #expect(lab.wait(1000) { $0.model.mark(.session("s7"))!.arrived > -1e8 })
        #expect(lab.model.mark(.session("s7"))!.flashes.count == 2)
    }

    /// A stopped session coming to ask changes group, its stopped for its asks: it moves up among the asks at once,
    /// under the ask the panel's order has above it, and its ring flashes twice (Lee, 14 November 2026; until then it
    /// flashed where it was and moved at the re-sort).
    @Test func aStoppedMarkComingToAskMovesAmongTheAsksAtOnceFlashing() throws {
        var lab = StripLab()
        var asking = try #require(lab.model.session("s5"))
        asking.kind = .needs
        asking.lines[0].title = "Approve the plan"
        asking.lines[0].since = -30 * Self.minute

        lab.arrive(asking)

        #expect(lab.model.display.prefix(3) == ["s1", "s5", "s2"])
        #expect(lab.wait(1000) { $0.model.mark(.session("s5"))!.arrived > -1e8 })
        #expect(lab.model.mark(.session("s5"))!.flashes.count == 2)
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

    /// An ask whose session comes to its turn moves among the stopped at once; asked again, it moves back among the
    /// asks at once, flashing.
    @Test func aMarkAtItsTurnThenAskedAgainMovesEachTimeAtOnce() throws {
        var lab = StripLab()
        var turned = try #require(lab.model.session("s2"))
        turned.kind = .turn
        lab.change(turned)
        #expect(lab.model.display == StripLab.core(lab.model.sessions).map(\.id))
        #expect(lab.model.display.firstIndex(of: "s2")! > lab.model.display.firstIndex(of: "s4")!)
        turned.kind = .needs

        lab.arrive(turned)

        #expect(lab.model.display == StripLab.core(StripLab.prototype).map(\.id))
        #expect(lab.wait(1000) { $0.model.mark(.session("s2"))!.arrived > -1e8 })
    }

    /// As on any run's first line: what needs Lee with nothing new comes in at its place at once, and nothing flashes.
    @Test func aNeedsYouWithNothingNewComesInAtItsPlaceUnflashed() {
        var lab = StripLab()

        lab.add([StripLab.ask])

        #expect(lab.model.display == StripLab.core(StripLab.prototype + [StripLab.ask]).map(\.id))
        lab.settle()
        let mark = lab.model.mark(.session("s9"))!
        #expect(mark.flashes.isEmpty && mark.arrived < 0)
        expectEvery(lab.frame.marks) { $0.flash == 0 && $0.wash == 0 }
    }

    /// Core puts s7's working row after s8's: it shows in place, then the strip takes core's order, where
    /// the panel's old sort, longest running first, would have kept s7's first.
    @Test func aChangeShowsInPlaceThenTheMarksTakeCoresOrder() {
        var lab = StripLab()
        var blueYonder = StripLab.prototype[6]
        blueYonder.lines[0].title = "Reading the reports"
        let board = Array(StripLab.prototype.prefix(6)) + [StripLab.prototype[7], blueYonder]

        lab.model.show(board, new: [])
        lab.step()
        #expect(lab.model.display.suffix(2) == ["s7", "s8"])
        #expect(lab.model.session("s7")?.title == "Reading the reports")

        lab.wait(1500)

        #expect(lab.model.display == board.map(\.id))
    }

    /// A row changed with its tab out: the tab eases to its new words' measure, rather than squeezing them into the
    /// old. (A count's tab keeps its size as its rows change, as the prototype's recording pins:
    /// `StripTimelineTests.anAnswerInTheCountTakesItOutAtOnceAsThePrototypes`.)
    @Test func aTabOutTakesItsChangedRowsMeasure() throws {
        var lab = StripLab()
        lab.open("s5")
        let was = try #require(lab.live).w.x
        var s5 = StripLab.prototype[4]
        s5.lines[0].title = "Sketched"

        lab.change(s5)
        lab.settle()

        #expect(was > StripTuning.tabMin)
        #expect(abs(try #require(lab.live).w.x - StripTuning.tabMin) < 0.5)
    }

    /// Under reduced motion the tab takes its new size at once, its outline cross-fading from the old, as a glide's
    /// does, rather than jumping.
    @Test func underReducedMotionATabTakingItsNewMeasureCrossFades() throws {
        var lab = StripLab(reducesMotion: true)
        lab.open("s5")
        var s5 = StripLab.prototype[4]
        s5.lines[0].title = "Sketched"

        lab.change(s5)
        lab.step()

        #expect(lab.frame.fading != nil)
        #expect(try #require(lab.live).alpha.x < 1)
    }

    @Test func aRowGoneFadesWhereItIsAndTheRestCloseUp() {
        var lab = StripLab()
        let y = lab.model.layout.y(of: "s6")

        lab.remove(["s5"])
        lab.step()

        let gone = lab.model.marks.first { $0.key == .session("s5") }!
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
        #expect(jumps.session?.id == "s6")
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

        #expect(jumps.session?.id == "s5")
        #expect(lab.model.jumping == nil && lab.live == nil)
    }

    /// A click on needs you's count, or where a mark folded into it would be, names no session: it opens the count.
    @Test func aCountNamesNoSessionNorDoesAMarkFoldedIntoIt() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        StripLab.asks.prefix(2).forEach(lab.newAsk)
        lab.settle()

        #expect(lab.model.click(at: lab.on("s10")) == .nothing)
        #expect(lab.model.click(at: lab.on(.count(.needsYou))) == .nothing)
        #expect(lab.live?.key == .count(.needsYou))
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
