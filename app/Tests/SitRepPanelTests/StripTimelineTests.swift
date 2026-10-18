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

        let played = lab.play(StripRecorded.arrive, marks: ["s4", "s5", "s9"], [(0, { $0.model.newAsk(StripLab.ask) })])

        expectMatches(played, StripRecorded.arrive)
        #expect(abs(lab.model.mark(.session("s9"))!.arrived - start - StripRecorded.arrived) < 1e-6)
    }

    @Test func aChangeShownInPlaceReSortsASettleAfterAsThePrototypes() {
        expectPlays(
            StripRecorded.settle, marks: ["s1", "s2", "s5", "s8"], [(0, { $0.model.change(StripLab.answered) })]
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

        let played = lab.play(StripRecorded.many, marks: ["s6", "s8", "s20"], [(0, { $0.model.add(StripLab.tooMany) })])

        expectMatches(played, StripRecorded.many)
        #expect(lab.model.display == StripRecorded.manyOrder)
    }

    /// Eight new asks, sixteen marks, all that fit: the last, Turnstile's, on the last place, its tab's bottom fitting
    /// into the bottom end's S.
    @Test func theLastMarksTabFitsIntoTheBottomEndAsThePrototypes() {
        var lab = StripLab()

        let played = lab.play(
            StripRecorded.last, marks: ["s4", "s8", "s9", "s16"],
            [(0, { lab in StripLab.asks.forEach(lab.model.newAsk) })]
        )

        expectMatches(played, StripRecorded.last)
    }

    /// Too many: the last mark over the count, its tab short of the bottom end, then on to the count's, as tall as
    /// the strip holds, fitting into both ends.
    @Test func theCountsTabFitsIntoBothEndsAsThePrototypes() {
        var lab = StripLab()

        let played = lab.play(
            StripRecorded.bottom, marks: ["s6", "s9"],
            [(0, { $0.model.add(StripLab.tooMany) })]
        )

        expectMatches(played, StripRecorded.bottom)
    }

    @Test func theNewMarkGrowsOnceTheMarkBelowHasSlid45PercentOfItsStep() {
        var lab = StripLab()
        let from = lab.model.yOf(.session("s4"))
        lab.model.newAsk(StripLab.ask)
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
