import CoreGraphics
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The card's open and close against the prototype's, recorded at Lee's settings a frame at a time: the same frames
/// played into the model give the same card.
@Suite(.backstop)
struct CardTimelineTests {
    @Test func theOpenFollowsThePrototypesFrameForFrame() {
        var lab = CardLab.recorded()

        let played = lab.play(Recorded.opening) { $0.model.open() }

        #expect(played.count == Recorded.opening.count)
        for (recorded, frame) in zip(Recorded.opening, played) {
            #expect(frame.matches(recorded), "at \(recorded.t)ms")
        }
    }

    @Test func theCloseFollowsThePrototypesFrameForFrame() {
        var lab = CardLab.recorded()
        lab.play(Recorded.opening) { $0.model.open() }

        let played = lab.play(Recorded.closing) { $0.model.close() }

        #expect(played.count == Recorded.closing.count)
        for (recorded, frame) in zip(Recorded.closing, played) {
            #expect(frame.matches(recorded), "at \(recorded.t)ms")
        }
    }

    @Test func openingTheDepthSlidesOutAtTheNotchsLengthAndLagIntoTheSlideTheLengthGrowsBothWaysFromItsCentre() {
        var lab = CardLab.recorded()

        let played = lab.play(Recorded.opening) { $0.model.open() }

        let lag = 30 / 0.93
        expectEvery(played.filter { $0.t < lag }) { $0.h == 124 && $0.w > 15 }
        expectEvery(played.filter { $0.t > lag }) { $0.h > 124 }
        expectEvery(played) { abs($0.shape.cy - lab.notchY) < 1e-9 }
    }

    @Test func openingItReaches372DeepAtAbout100msRuns12PastAndIsStillByAbout240ms() {
        var lab = CardLab.recorded()

        let played = lab.play(Recorded.opening) { $0.model.open() }

        let there = played.first { $0.w >= 372 }!
        #expect(there.t > 100 && there.t < 110)
        #expect(abs(played.map(\.w).max()! - 384.1) < 0.1)
        let still = played.first { abs($0.w - 372) < 0.5 && abs($0.h - 482) < 0.5 }!
        #expect(still.t > 230 && still.t < 250)
    }

    @Test func theRowsLandOnceTheDepthIsWithin12AndTheLengthWithin4() {
        var lab = CardLab.recorded()

        let played = lab.play(Recorded.opening) { $0.model.open() }

        let landed = played.firstIndex { $0.phase == .open }!
        let there = { (p: Played) in abs(p.w - 372) <= 12 && abs(p.h - 482) <= 4 }
        #expect(abs(played[landed].t - 125) < 1)
        #expect(there(played[landed]))
        #expect(!there(played[landed - 1]))
        expectEvery(played[..<landed]) { $0.head == 0 }
    }

    @Test func theRowsLandFromTheTopTwentyFiveMillisecondsApart() {
        var lab = CardLab.recorded()
        lab.model.open()
        lab.wait(1000) { $0.phase == .open }
        let landed = lab.model.t

        lab.wait(100)

        let since = lab.model.t - landed
        let panel = lab.frame.panel!
        #expect(panel.head.alpha == easeOut(min(1, since / 90)))
        for (i, place) in lab.model.revealOrder.enumerated() {
            #expect(panel.items[i].alpha == easeOut(clamp((since - 25 * Double(place)) / 90, 0, 1)))
        }
    }

    @Test func closingTheRowsFadeIn60msTheLengthStarts50msInAndTheDepthLagAfterIt() {
        var lab = CardLab.recorded()
        lab.play(Recorded.opening) { $0.model.open() }

        let played = lab.play(Recorded.closing) { $0.model.close() }

        expectEvery(played.filter { $0.t < 60 }) { abs($0.head - (1 - $0.t / 60)) < 1e-9 }
        expectEvery(played.filter { $0.t >= 60 }) { $0.head == 0 }
        let length = 50 / 0.88, depth = (50 + 30) / 0.88
        expectEvery(played.filter { $0.t < length }) { $0.h == 482 }
        expectEvery(played.filter { $0.t > length }) { $0.h < 482 }
        expectEvery(played.filter { $0.t < depth }) { $0.w == 372 }
        expectEvery(played.filter { $0.t > depth }) { $0.w < 372 }
    }

    @Test func closingItEasesIntoTheSlotWithoutABounceSeatedByAbout350ms() {
        var lab = CardLab.recorded()
        lab.play(Recorded.opening) { $0.model.open() }

        let played = lab.play(Recorded.closing) { $0.model.close() }

        expectEvery(played) { $0.w >= 15 && $0.h >= 124 }
        expectEvery(zip(played, played.dropFirst())) { $1.w <= $0.w && $1.h <= $0.h }
        let seated = played.first { $0.phase == .closed }!
        #expect(seated.t > 340 && seated.t < 360)
        #expect(seated.w == 15)
    }

    @Test func closingTheLightComesBackOverTheDepthsLast30() {
        var lab = CardLab.recorded()
        lab.play(Recorded.opening) { $0.model.open() }

        let played = lab.play(Recorded.closing) { $0.model.close() }

        let lit = played.firstIndex { $0.vis > 0 }!
        #expect(played[lit - 1].w <= 45)
        expectEvery(played[..<(lit - 1)]) { $0.w > 45 }
    }
}

/// A frame as the recording has it.
struct Played {
    let t: Double
    let phase: Phase
    let w, h, vis, head: Double
    let shape: CardGeometry

    /// The same card as the prototype's: the depth, length and light to the recording's six decimals, the head's
    /// opacity to the browser's three.
    func matches(_ recorded: Recorded) -> Bool {
        phase == recorded.phase
            && abs(w - recorded.w) < 1e-6 && abs(h - recorded.h) < 1e-6 && abs(vis - recorded.vis) < 1e-6
            && abs(head - recorded.head) < 6e-4
    }
}

extension CardLab {
    /// The card at rest as the recording starts: something needs Lee, the content is the recording's length, and the
    /// pointer rests where the open panel will be, away from the notch.
    static func recorded() -> CardLab {
        let css = Content.css
        let content = Content(
            headHeight: css.headHeight + Recorded.contentLength - css.height, entries: css.entries
        )
        var lab = CardLab(needsLee: true, pointer: CGPoint(x: 200, y: screen.notchY), content: content)
        lab.settle()
        return lab
    }

    /// The call, then a frame at each of the recording's times after it.
    @discardableResult
    mutating func play(_ recorded: [Recorded], after call: (CardLab) -> Void) -> [Played] {
        let start = now
        call(self)
        return recorded.map { r in
            step(at: start + r.t)
            let S = model.S
            return Played(
                t: r.t, phase: phase, w: S.w.x, h: S.h.x, vis: S.vis.x, head: frame.panel?.head.alpha ?? 0,
                shape: shape
            )
        }
    }
}
