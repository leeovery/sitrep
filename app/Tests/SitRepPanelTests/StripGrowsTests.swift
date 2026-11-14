import CoreGraphics
@testable import SitRepPanel
import Testing

/// Length, Grows, and what comes with it: the strip as long as its marks need, centred where the notch sits, its
/// places allotted, needs you folding into its own count past its room, and with nothing running the notch at rest.
struct StripGrowsTests {
    /// The prototype's `allot`, on the recording's screen, which holds 16 places at Full: Max, asks, others, and the
    /// asks shown, folded into needs you's orange count, the others shown and folded into the grey one.
    @Test(arguments: [
        (5.0, 9, 4, 3, 6, 0, 4), (6, 9, 4, 4, 5, 0, 4), (5, 4, 9, 4, 0, 0, 9), (5, 5, 0, 5, 0, 0, 0),
        (5, 6, 0, 4, 2, 0, 0), (5, 4, 1, 4, 0, 1, 0), (5, 5, 1, 3, 2, 1, 0), (5, 4, 2, 4, 0, 0, 2),
        (5, 1, 9, 1, 0, 3, 6), (5, 9, 1, 3, 6, 1, 0), (6, 6, 4, 4, 2, 0, 4), (0, 20, 4, 14, 6, 0, 4),
        (0, 15, 4, 15, 0, 0, 4), (0, 24, 0, 15, 9, 0, 0), (0, 3, 30, 3, 0, 12, 18),
    ])
    func thePlacesGoAsThePrototypeAllotsThem(
        _ max: Double, _ asks: Int, _ others: Int, _ shownAsks: Int, _ orange: Int, _ shownOthers: Int, _ grey: Int
    ) {
        let lab = StripLab(sessions: Self.sessions(asks: asks, others: others), length: .grows, maxMarks: max == 0 ? nil : Int(max))
        let layout = lab.model.layout

        #expect(layout.places.filter { $0.id.hasPrefix("a") }.count == shownAsks)
        #expect(layout.moreNeeds?.n ?? 0 == orange)
        #expect(layout.places.filter { $0.id.hasPrefix("w") }.count == shownOthers)
        #expect(layout.more?.n ?? 0 == grey)
        let counts = [layout.moreNeeds, layout.more].compactMap(\.self).count
        #expect(layout.places.count + counts == min(asks + others, max == 0 ? 16 : Int(max)))
    }

    /// Needs you's count sits at the end of its group, over the hairline; the grey one in the last place.
    @Test func needsYousCountSitsOverTheHairlineAndTheGreyOneLast() {
        let lab = StripLab(sessions: Self.sessions(asks: 9, others: 4), length: .grows, maxMarks: 6)
        let layout = lab.model.layout

        #expect(layout.moreNeeds!.y < layout.hair! && layout.hair! < layout.more!.y)
        #expect(layout.places.allSatisfy { $0.y < layout.moreNeeds!.y })
    }

    @Test func atGrowsTheStripIsAsLongAsItsMarksNeedCentred42PercentDown() {
        let lab = StripLab(length: .grows)
        let layout = lab.model.layout

        // four asks and two stopped, the hairline, two working, and the two ends with Room inside each
        let marks = 5 * 30 + 2 * 21.5 + 1 * 30.0, ends = 2 * (28 + 2 + 12 + 12.0)
        #expect(layout.length == marks + ends)
        #expect(abs(layout.top + layout.length / 2 - 0.42 * 626) < 1e-9)
        #expect(lab.model.yt.x == layout.top && lab.model.yb.x == layout.bottom)
        #expect(abs(lab.frame.strip.boundingBoxOfPath.minY - layout.top) < 1e-4)
    }

    /// As long as its places run, it is held inside the screen, under the menu bar and over the bottom end.
    @Test func everyPlaceTakenTheStripIsHeldUnderTheMenuBar() {
        let lab = StripLab(sessions: Self.sessions(asks: 0, others: 30), length: .grows)
        let layout = lab.model.layout

        #expect(layout.top == 26 && layout.length == 15 * 30 + 2 * 54)
        #expect(layout.bottom <= 626 - 26)
    }

    /// Lead: the ends spring quicker than the marks' slide as the strip grows, slower as it shrinks.
    @Test func theEndsLeadAGrowAndFollowAShrink() {
        var lab = StripLab(length: .grows)
        func ends(growing: Bool) -> Spring {
            var spring = Spring(0)
            spring.springTo(1, StripFeel.lees.ends(growing: growing))
            return spring
        }

        lab.remove(["s7", "s8"])
        #expect(lab.model.yt.k == ends(growing: false).k && lab.model.yb.k == ends(growing: false).k)

        lab.settle()
        lab.newAsk(StripLab.ask)
        #expect(lab.model.yt.k == ends(growing: true).k && lab.model.yb.k == ends(growing: true).k)
        #expect(ends(growing: true).k > lab.model.mark(.session("s5"))!.y.k)
    }

    /// An ask landing in the count leaves every mark showing where it is: only the count takes it.
    @Test(arguments: [1, 3])
    func noMarkShowingMovesWhenAnAskFolds(_ before: Int) {
        var lab = StripLab(length: .grows, maxMarks: 6)
        StripLab.asks.prefix(before).forEach(lab.newAsk)
        lab.settle()
        let shown = Dictionary(uniqueKeysWithValues: lab.model.layout.places.map { ($0.id, $0.y) })
        let top = lab.model.yt.x, bottom = lab.model.yb.x

        lab.newAsk(StripLab.asks[before])
        var still = true
        lab.wait(2500) { lab in
            for (id, y) in shown where lab.model.layout.y(of: id) != nil {
                still = still && lab.model.mark(.session(id))!.y.x == y
            }
            return false
        }

        #expect(still)
        #expect(lab.model.layout.restNeeds.contains(StripLab.asks[before].id))
        #expect(lab.model.yt.x == top && lab.model.yb.x == bottom)
    }

    /// A new ask that lands in the count: its ring flashes twice, 450ms apart, and it is washed orange for two
    /// seconds, as a new mark is.
    @Test func theCountFlashesTwice450ApartAndIsWashedAsANewMarkIs() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        StripLab.asks.prefix(5).forEach(lab.newAsk)
        lab.settle()
        let landed = lab.model.t

        lab.newAsk(StripLab.asks[5])
        var seen: [(t: Double, flash: Double, wash: Double)] = []
        lab.wait(2200) { lab in
            let count = lab.frame.marks.first { $0.key == .moreNeeds }!
            seen.append((lab.model.t - landed, count.flash, count.wash))
            return false
        }

        #expect(lab.model.moreNeeds!.flashes == [landed, landed + 450])
        let peaks = seen.indices.dropFirst().dropLast().filter {
            seen[$0].flash > seen[$0 - 1].flash && seen[$0].flash >= seen[$0 + 1].flash
        }
        #expect(peaks.map { (seen[$0].t / 10).rounded() * 10 } == [70, 520])
        #expect(seen.filter { $0.t < 1500 }.allSatisfy { $0.wash == 1 })
        #expect(seen.last!.wash == 0)
    }

    /// An answer to an ask in the count changes its row in place; the re-sort waits a settle after the pointer leaves,
    /// and then the other ask that landed there takes the place the away one had, and the count holds the end of
    /// needs you's order, the away ask and the stopped.
    @Test func anAnswerInTheCountShowsInPlaceAndReSortsASettleAfterThePointerLeaves() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        StripLab.asks.prefix(2).forEach(lab.newAsk)
        lab.settle()
        let fourth = lab.model.layout.y(of: "s4")
        #expect(lab.model.layout.restNeeds == ["s9", "s10", "s5", "s6"])
        lab.open(.moreNeeds)

        lab.change(StripLab.answered(ask: "s9"))
        lab.wait(200)
        guard case let .rows(rows) = lab.live!.current!.content else {
            Issue.record("the count's tab holds rows")
            return
        }
        #expect(rows.map(\.lines[0].title) == [
            "Sizing the diffs", "Allow Bash ", "The management window is sketched",
            "Waiting for the next round of feedback",
        ])
        #expect(lab.model.layout.restNeeds == ["s9", "s10", "s5", "s6"])

        let left = lab.leave(by: 40)
        lab.wait(900)
        #expect(lab.model.layout.restNeeds.contains("s9"))
        lab.wait(400)

        #expect(lab.model.t - left > 1000)
        #expect(lab.model.layout.restNeeds == ["s4", "s5", "s6"])
        #expect(lab.model.layout.y(of: "s10") == fourth)
        #expect(lab.model.layout.rest.contains("s9"))
    }

    /// The prototype's fix: an ask folding into its count while it is still growing in stays out of sight there.
    @Test func aMarkThatFoldsWhileItIsGrowingInStaysHidden() {
        var lab = StripLab(sessions: Array(StripLab.prototype.prefix(4)), length: .grows, maxMarks: 5)

        lab.newAsk(StripLab.ask)
        #expect(lab.model.mark(.session("s9"))!.gap != nil)
        lab.add([Session(id: "w0", project: "Kit", kind: .working, title: "", sub: "", since: 0)])
        #expect(lab.model.layout.restNeeds == ["s9", "s4"])
        lab.settle()

        let mark = lab.model.mark(.session("s9"))!
        #expect(mark.op.x == 0 && mark.sc.x == 1 && mark.arrived < 0)
    }

    /// The count's tab, taller than a short strip holds, scrolls its rows, as far as they run.
    @Test func theCountsRowsScrollOnAShortStrip() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        StripLab.asks.prefix(5).forEach(lab.newAsk)
        lab.settle()
        lab.open(.moreNeeds)
        let tab = lab.frame.tabs.first { $0.isLive }!, words = tab.words.last!
        let low = CGPoint(x: tab.clip.midX, y: tab.box.minY + 170)
        #expect(words.frame.height == 215)
        #expect(tab.row(at: low) == "s12")

        lab.model.scroll(by: 200, at: low)
        lab.step()

        let scrolled = lab.frame.tabs.first { $0.isLive }!
        #expect(scrolled.words.last!.scroll == 7 * 43 + 6 * 2 + 16 - 215)
        #expect(scrolled.row(at: low) == "s6")
    }

    /// An away row in the count's tab jumps as any row does, its session carried on (stage 8).
    @Test func anAwayRowInTheCountsTabJumps() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        lab.add(Array(StripLab.asks.prefix(2)))
        lab.settle()
        lab.open(.moreNeeds)
        let tab = lab.frame.tabs.first { $0.isLive }!
        let away = CGPoint(x: tab.clip.midX, y: tab.box.minY + tab.words.last!.frame.minY + 8 + 45 + 20)
        #expect(tab.row(at: away) == "s4")

        #expect(lab.model.click(at: away)?.id == "s4")
        #expect(lab.model.jumping != nil)
    }

    /// Nothing running: the strip draws back into the notch at rest, 7 deep and 76 long, centred where it was, its
    /// marks gone; its tab says nothing is running and takes no click; and the frames stop.
    @Test func withNothingRunningItIsTheNotchAtRestWhoseTabSaysSo() {
        var lab = StripLab(length: .grows)
        lab.remove(StripLab.prototype.map(\.id))
        lab.settle()

        let box = lab.frame.strip.boundingBoxOfPath
        #expect(lab.model.drawnIn.x == 1 && lab.frame.marks.isEmpty)
        // at rest, as the springs take it, within a thousandth of a point
        #expect(abs(box.maxX - 7) < 1e-4 && abs(box.height - 76) < 1e-2 && abs(box.midY - 0.42 * 626) < 1e-2)
        #expect(!lab.frame.isMoving && !lab.frame.wakes(pointer: nil))

        lab.pointer = CGPoint(x: 4, y: lab.model.yOf(.empty))
        lab.wait(1000) { $0.live?.phase == .open }
        lab.settle()
        #expect(lab.live?.key == .empty && lab.live?.current?.content == .idle)
        let tab = lab.frame.tabs.first { $0.isLive }!
        lab.model.click(at: CGPoint(x: tab.clip.midX, y: tab.clip.midY))
        #expect(lab.model.jumping == nil)
    }

    /// The notch at rest answers the pointer 12 out from the edge and 4 past its ends.
    @Test func theNotchAtRestAnswersThePointerALittleFurtherOut() {
        var lab = StripLab(length: .grows)
        lab.remove(StripLab.prototype.map(\.id))
        lab.settle()
        let top = lab.model.yt.x

        #expect(lab.model.inStrip(Vec(12, top - 4)))
        #expect(!lab.model.inStrip(Vec(12.5, top)))
        #expect(!lab.model.inStrip(Vec(4, top - 4.5)))
    }

    /// Once the ends have settled, at Grows as at Full, nothing moves and the frames stop.
    @Test func theFramesStopOnceGrowsHasSettled() {
        var lab = StripLab(length: .grows)
        lab.remove(["s7", "s8"])
        lab.wait(100)
        #expect(lab.frame.isMoving)

        let shrunk = lab.settle()
        #expect(shrunk)
        #expect([lab.model.yt, lab.model.yb, lab.model.drawnIn].allSatisfy { $0.isAtRest })
        #expect(!lab.frame.isMoving && !lab.frame.wakes(pointer: nil))

        lab.newAsk(StripLab.ask)
        let grown = lab.settle()
        #expect(grown)
        #expect(!lab.frame.isMoving && !lab.frame.wakes(pointer: nil))
    }

    /// A press on the strip dragged along the edge carries it there, the tab drawn back, and no click comes of it; at
    /// Full it runs the screen's height and goes nowhere along it.
    @Test func aDragCarriesTheStripAlongTheEdgeAtGrowsOnly() {
        var lab = StripLab(length: .grows)
        let top = lab.model.layout.top
        lab.open("s5")
        lab.model.press(at: lab.pointer!)
        #expect(lab.frame.isHeld == false)
        lab.step()
        #expect(lab.frame.isHeld && lab.frame.hits(CGPoint(x: 900, y: 10)))

        lab.pointer!.y += 3
        lab.step()
        #expect(lab.model.layout.top == top && lab.live?.phase == .open)
        lab.pointer!.y += 47
        lab.step()
        #expect(abs(lab.model.layout.top - (top + 50)) < 1e-9 && lab.live == nil)
        lab.model.release(at: lab.pointer!)
        lab.settle()

        #expect(lab.model.jumping == nil && lab.model.tabs.isEmpty)
        #expect(abs(lab.model.yt.x - (top + 50)) < 1e-9)

        var full = StripLab()
        full.pointer = full.on("s5")
        full.step()
        full.model.press(at: full.pointer!)
        full.pointer!.y += 50
        full.step()
        #expect(full.model.layout.top == 26 && full.model.yt.target == 26)
        #expect(full.model.release(at: full.pointer!) == .dropped(along: nil, across: false))
    }

    /// Under reduced motion the strip takes its new length at once, its old shape fading out over it.
    @Test func underReducedMotionTheStripTakesItsLengthAtOnceAndCrossFades() {
        var lab = StripLab(length: .grows, reducesMotion: true)

        lab.remove(["s7", "s8"])
        lab.step()

        #expect(lab.model.yt.x == lab.model.layout.top && lab.model.yb.x == lab.model.layout.bottom)
        #expect(lab.frame.fading != nil)

        lab.remove(StripLab.prototype.map(\.id))
        lab.step()
        #expect(lab.model.drawnIn.x == 1)
    }

    /// Length and Max change the shape at once: any tab goes, and the ends and the marks go to their new places.
    @Test func lengthAndMaxChangeTheShapeAtOnce() {
        var lab = StripLab(length: .grows)
        lab.open("s5")

        lab.model.length = .full
        #expect(lab.model.tabs.isEmpty)
        lab.pointer = nil
        lab.settle()
        #expect(lab.model.yt.x == 26 && lab.model.yb.x == 600)

        lab.model.length = .grows
        lab.model.maxLength = StripLab.maxLength(marks: 5)
        lab.settle()
        #expect(lab.model.layout.places.count == 3)
        #expect(lab.model.layout.moreNeeds?.n == 3 && lab.model.layout.more?.n == 2)
    }

    /// On the recording's screen, 626 tall, Max's slider runs to 16 marks, Full, hairline or not; a Room of 0 holds
    /// more.
    @Test func maxsSliderRunsToAsManyMarksAsTheScreenHolds() {
        var roomless = StripFeel.lees
        roomless.room = 0
        let taller = StripInput(time: 0, pointer: nil, stage: StripStage(width: 1512, height: 982, menu: 37))
        let model = StripLab().model

        #expect(model.fullPlaces(hairline: false) == StripLab.longest)
        #expect(model.fullPlaces(hairline: true) == StripLab.longest)
        #expect(StripLab(feel: roomless).model.fullPlaces(hairline: false) == 17)
        let strip = Strip(
            length: .grows, maxLength: .full, along: Tuning.notchAt, sessions: [], measure: StripLab.measure, taller
        )
        #expect(strip.fullPlaces(hairline: false) == 28)
    }

    /// On a screen where the hairline costs the full strip a place, Max's slider runs to what holds with it: its top is
    /// Full, and the step below is one place fewer.
    @Test(arguments: [(1.0, 15), (0.9, 14), (0.0, 5)])
    func withTheHairlineMaxsSliderRunsToWhatHoldsWithIt(_ share: Double, _ places: Int) {
        let stage = StripStage(width: 1076, height: 615, menu: 26)
        let input = StripInput(time: 0, pointer: nil, stage: stage)
        let strip = Strip(
            length: .grows, maxLength: StripMax(share: share), along: Tuning.notchAt,
            sessions: Self.sessions(asks: 9, others: 9),
            measure: StripLab.measure, input
        )

        #expect(strip.fullPlaces(hairline: false) == 16 && strip.fullPlaces(hairline: true) == 15)
        #expect(strip.allot(needs: 9, others: 9).places == places)
    }

    /// Asks numbered a0, a1 and so on, oldest first, and working sessions w0, w1.
    private static func sessions(asks: Int, others: Int) -> [Session] {
        (0 ..< asks).map {
            Session(id: "a\($0)", project: "Ask", kind: .needs, title: "", sub: "", since: Double($0))
        } + (0 ..< others).map {
            Session(id: "w\($0)", project: "Work", kind: .working, title: "", sub: "", since: Double($0))
        }
    }
}
