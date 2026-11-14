import CoreGraphics
@testable import SitRepPanel
import Testing

/// The strip against its prototype, recorded at Lee's settings a frame at a time: the same frames, with the pointer
/// where the prototype had it and the same calls between them, played into the model give the same strip.
struct StripTimelineTests {
    typealias Act = (at: Double, act: (inout StripLab) -> Void)

    /// The pointer resting on Fumi's mark: the edge reaches, the dwell, the pour; then on to Goosemates's, the tab
    /// gliding; then off the page, the grace and the draw back.
    @Test func aTabPoursGlidesAndDrawsBackAsThePrototypes() {
        expectPlays(StripRecorded.hover)
    }

    /// The pointer resting on SitRep's, the first mark: its tab's top fits into the top end's S as it pours, and
    /// leaves it again as it draws back, the S never moving.
    @Test func theFirstMarksTabFitsIntoTheTopEndAsThePrototypes() {
        expectPlays(StripRecorded.fit)
    }

    @Test func aNewNeedsYouSlidesInAndArrivesWhenThePrototypesDoes() {
        var lab = StripLab()
        let start = lab.model.t

        let played = lab.play(StripRecorded.arrive, marks: ["s4", "s5", "s9"], [(0, { $0.newAsk(StripLab.ask) })])

        expectMatches(played, StripRecorded.arrive)
        #expect(abs(lab.model.mark(.session("s9"))!.arrived - start - StripRecorded.arrived) < 1e-6)
    }

    @Test func aChangeShownInPlaceReSortsASettleAfterAsThePrototypes() {
        expectPlays(
            StripRecorded.settle, marks: ["s1", "s2", "s5", "s8"], [(0, { $0.change(StripLab.answered) })]
        )
    }

    @Test func aClickOnAMarkInsideTheDwellJumpsAsThePrototypes() {
        expectPlays(StripRecorded.jump, marks: ["s6"], [(50, { $0.model.click(at: $0.pointer!) })])
    }

    @Test func aClickOnAnOpenTabJumpsAsThePrototypes() {
        expectPlays(StripRecorded.tabJump, [(600, { lab in
            let tab = lab.frame.tabs.first { $0.isLive }!
            lab.model.click(at: CGPoint(x: tab.clip.midX, y: tab.clip.midY))
        })])
    }

    @Test func tooManyFoldsTheRestIntoTheCountAndItsTabPoursAsThePrototypes() {
        var lab = StripLab()

        let played = lab.play(StripRecorded.many, marks: ["s6", "s8", "s20"], [(0, { $0.add(StripLab.tooMany) })])

        expectMatches(played, StripRecorded.many)
        #expect(lab.model.display == StripRecorded.manyOrder)
    }

    /// Eight new asks, sixteen marks, all that fit: the last, Turnstile's, on the last place, its tab's bottom fitting
    /// into the bottom end's S.
    @Test func theLastMarksTabFitsIntoTheBottomEndAsThePrototypes() {
        var lab = StripLab()

        let played = lab.play(
            StripRecorded.last, marks: ["s4", "s8", "s9", "s16"],
            [(0, { lab in StripLab.asks.forEach(lab.newAsk) })]
        )

        expectMatches(played, StripRecorded.last)
    }

    /// Too many: the last mark over the count, its tab short of the bottom end, then on to the count's, as tall as
    /// the strip holds, fitting into both ends.
    @Test func theCountsTabFitsIntoBothEndsAsThePrototypes() {
        var lab = StripLab()

        let played = lab.play(
            StripRecorded.bottom, marks: ["s6", "s9"],
            [(0, { $0.add(StripLab.tooMany) })]
        )

        expectMatches(played, StripRecorded.bottom)
    }

    /// Grows: two working sessions end and the strip shrinks, the ends following the marks in; then a new ask, and it
    /// grows, the ends leading the marks out.
    @Test func atGrowsTheStripShrinksAndGrowsWithItsMarksAsThePrototypes() {
        var lab = StripLab(length: .grows)

        let played = lab.play(StripRecorded.grows, marks: ["s4", "s5", "s7", "s8", "s9"], [
            (0, { $0.remove(["s7"]) }), (0, { $0.remove(["s8"]) }),
            (1300, { $0.newAsk(StripLab.ask) }),
        ])

        expectMatches(played, StripRecorded.grows)
    }

    /// Max 6, five new asks: needs you's places already full, its two stopped folded into its count, each new ask
    /// lands in the count, the four asks showing never moving, and the two working stay in the grey one.
    @Test func atMaxSixNineAsksFoldIntoTheirOwnCountAsThePrototypes() {
        var lab = StripLab(length: .grows, maxMarks: 6)

        let played = lab.play(
            StripRecorded.maxSix, marks: ["s3", "s4", "s5", "s9", "s10", "s13"], Self.asks(0 ..< 5, at: 0)
        )

        expectMatches(played, StripRecorded.maxSix)
        #expect(lab.model.layout.restNeeds == StripRecorded.maxSixFolded.asks)
        #expect(lab.model.layout.rest == StripRecorded.maxSixFolded.rest)
    }

    @Test func aNewAskPastItsRoomLandsInTheCountWhichFlashesAsThePrototypes() {
        var lab = StripLab(length: .grows, maxMarks: 6)
        let start = lab.model.t

        let played = lab.play(
            StripRecorded.lands, marks: ["s4", "s9", "s13", "s14"],
            Self.asks(0 ..< 5, at: 0) + Self.asks(5 ..< 6, at: 1000)
        )

        expectMatches(played, StripRecorded.lands)
        #expect(abs(lab.model.moreNeeds!.arrived - start - StripRecorded.landed) < 1e-6)
    }

    /// Needs you's count's tab: its rows the asks landed in it, then the stopped folded there.
    @Test func needsYousCountsTabPoursWhatItHoldsAsRowsAsThePrototypes() {
        var lab = StripLab(length: .grows, maxMarks: 6)

        let played = lab.play(StripRecorded.countTab, marks: ["s4", "s9"], Self.asks(0 ..< 5, at: 0))

        expectMatches(played, StripRecorded.countTab)
    }

    /// Max 6 and two new asks, landing in needs you's count beside its stopped: an answer to the first there changes
    /// its row in place; a settle after the pointer leaves, the marks re-sort, the answered one going into the grey
    /// count.
    @Test func anAnswerOutOfTheCountReSortsOnceThePointerHasLeftAsThePrototypes() {
        var lab = StripLab(length: .grows, maxMarks: 6)

        let played = lab.play(
            StripRecorded.answerOut, marks: ["s4", "s5", "s9", "s10"],
            Self.asks(0 ..< 2, at: 0) + [(1700, { $0.change(StripLab.answered(ask: "s9")) })]
        )

        expectMatches(played, StripRecorded.answerOut)
    }

    /// Nothing running: the strip draws back into the notch at rest; hovered, its tab says so; a new ask grows it back
    /// out.
    @Test func withNothingRunningTheStripDrawsBackIntoTheNotchAtRestAsThePrototypes() {
        var lab = StripLab(length: .grows)

        let played = lab.play(StripRecorded.empty, marks: ["s1", "s8", "s9"], [
            (0, { $0.remove(StripLab.prototype.map(\.id)) }), (3000, { $0.newAsk(StripLab.ask) }),
        ])

        expectMatches(played, StripRecorded.empty)
    }

    /// A turn ends: DocMan's mark leaves its place under the hairline and grows into needs you before the stopped, at
    /// once, the marks between sliding down and the hairline with them.
    @Test func aSessionStoppingMovesIntoNeedsYouAtOnceAsThePrototypes() {
        var lab = StripLab(length: .grows)

        let played = lab.play(
            StripRecorded.stops, marks: ["s5", "s6", "s7", "s8"], [(0, { $0.stop(StripLab.stopped) })]
        )

        expectMatches(played, StripRecorded.stops)
    }

    /// Max 6, five new asks, then a turn ends: DocMan's lands in needs you's count, the marks showing never moving,
    /// and the grey count, left holding one, goes as Turnstile's mark comes out of it.
    @Test func aSessionStoppingPastItsRoomLandsInTheCountAsThePrototypes() {
        var lab = StripLab(length: .grows, maxMarks: 6)

        let played = lab.play(
            StripRecorded.stopsLand, marks: ["s4", "s7", "s8", "s9"],
            Self.asks(0 ..< 5, at: 0) + [(1000, { $0.stop(StripLab.stopped) })]
        )

        expectMatches(played, StripRecorded.stopsLand)
        #expect(lab.model.layout.restNeeds.first == "s7")
    }

    /// Max 7: a turn ends and DocMan's lands in needs you's new count beside Goosemates's; a new ask takes its place,
    /// pushing Fumi's stopped mark, the last showing, into the count, the marks between sliding down; a second, with
    /// no stopped mark showing, lands in the count.
    @Test func aNewAskOnAFullStripPushesTheLastStoppedMarkIntoTheCountAsThePrototypes() {
        var lab = StripLab(length: .grows, maxMarks: 7)

        let played = lab.play(StripRecorded.displace, marks: ["s4", "s5", "s9", "s10"], [
            (0, { $0.stop(StripLab.stopped) }), (900, { $0.newAsk(StripLab.asks[0]) }),
            (1800, { $0.newAsk(StripLab.asks[1]) }),
        ])

        expectMatches(played, StripRecorded.displace)
        #expect(lab.model.layout.restNeeds == ["s10", "s5", "s7", "s6"])
    }

    @Test func aPressCarriedAlongTheEdgeDragsTheStripAsThePrototypes() {
        var lab = StripLab(length: .grows)

        let played = lab.play(StripRecorded.drag, marks: ["s1", "s5", "s8"], [
            (60, { $0.model.press(at: $0.pointer!) }), (400, { $0.model.release(at: $0.pointer!) }),
        ])

        expectMatches(played, StripRecorded.drag)
        #expect(lab.model.jumping == nil)
    }

    /// The prototype's new asks in its order, all at once.
    private static func asks(_ range: Range<Int>, at time: Double) -> [Act] {
        StripLab.asks[range].map { ask in (time, { $0.newAsk(ask) }) }
    }

    @Test func theNewMarkGrowsOnceTheMarkBelowHasSlid45PercentOfItsStep() {
        var lab = StripLab()
        let from = lab.model.yOf(.session("s4"))
        lab.newAsk(StripLab.ask)
        var slid: [Double] = []

        lab.wait(1000) { lab in
            slid.append((lab.model.mark(.session("s4"))!.y.x - from) / StripTuning.pitch)
            return lab.model.mark(.session("s9"))!.arrived > -1e8
        }

        #expect(slid.last! >= 0.45)
        #expect(slid.dropLast().allSatisfy { $0 < 0.45 })
        #expect(lab.model.mark(.session("s9"))!.sc.target == 1)
    }

    private func expectPlays(_ recorded: [StripRecorded], marks ids: [String] = [], _ actions: [Act] = []) {
        var lab = StripLab()
        expectMatches(lab.play(recorded, marks: ids, actions), recorded)
    }

    private func expectMatches(_ played: [StripPlayed], _ recorded: [StripRecorded]) {
        #expect(played.count == recorded.count)
        for (frame, r) in zip(played, recorded) {
            #expect(frame.matches(r), "at \(r.t)ms, off by \(frame.error(against: r))")
        }
    }
}
