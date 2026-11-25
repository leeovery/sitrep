import CoreGraphics
@testable import SitRepEdge
import Testing

/// The way from the list to the asks panel (`SafeTriangle`): held while the pointer keeps closing on the asks panel,
/// judged over a window, not sample to sample, with a point of jitter let by; ended by a rest, a turn away, a step out
/// of the triangle or its time; and started only by the pointer moving off the list.
@Suite(.backstop)
struct SafeTriangleTests {
    /// The asks panel, 200pt from where the pointer leaves the list.
    private static let asks = CGRect(x: 300, y: 100, width: 200, height: 200), onList = CGPoint(x: 100, y: 200)

    /// A way off the list at time 0, then the pointer at each of these points and times, the last one judged.
    private static func way(_ steps: [(x: Double, at: Double)]) -> CGPath? {
        var way = SafeTriangle()
        var held = way.holding(onList, onList: true, toward: asks, at: 0)

        for step in steps {
            held = way.holding(CGPoint(x: step.x, y: 200), onList: false, toward: asks, at: step.at)
        }
        return held
    }

    @Test func aPointerClosingInIsHeld() {
        #expect(Self.way([(150, 10), (200, 20)]) != nil)
    }

    /// A sample no newer than the last, as a step between a slow mouse's reports gives, leaves it held until it is a
    /// rest of longer than the window.
    @Test func aRepeatedSampleHoldsItUntilItIsARest() {
        #expect(Self.way([(150, 10), (150, 20), (150, 10 + SafeTriangle.window)]) != nil)
        #expect(Self.way([(150, 10), (150, 20), (150, 11 + SafeTriangle.window)]) == nil)
    }

    /// Closing in is judged against the window's start, not the last sample: a sample further than the one before,
    /// as a fast mouse's jitter gives, holds while it is closer than the pointer was a window ago.
    @Test func closingInIsJudgedOverTheWindowNotSampleToSample() {
        #expect(Self.way([(150, 10), (200, 20), (197, 21)]) != nil)
    }

    /// Against the window's start, a point further is let by as jitter; further than that ends it, as a turn away.
    @Test func aPointOfJitterIsLetByAndMoreIsATurn() {
        let start = 10.0, later = start + SafeTriangle.window + 10

        #expect(Self.way([(200, start), (199.6, start + 40), (200 - SafeTriangle.jitter * 0.8, later)]) != nil)
        #expect(Self.way([(200, start), (199.6, start + 40), (200 - SafeTriangle.jitter * 1.5, later)]) == nil)
    }

    /// Its time counts from the pointer moving off the list, however long it rested there first with no steps.
    @Test func itsTimeCountsFromTheMoveOffTheList() {
        var way = SafeTriangle()
        var held: CGPath?

        _ = way.holding(Self.onList, onList: true, toward: Self.asks, at: 0)
        for at in stride(from: 1000.0, through: 1000 + SafeTriangle.lasts, by: 10) {
            held = way.holding(CGPoint(x: 100 + (at - 990) / 3, y: 200), onList: false, toward: Self.asks, at: at)
        }
        #expect(held != nil)
    }

    /// The asks panel moving away from under the triangle while the pointer rests ends it, as a step out of it does.
    @Test func aRestTheTriangleMovesFromUnderEndsIt() {
        var way = SafeTriangle()
        let resting = CGPoint(x: 150, y: 200), lower = Self.asks.offsetBy(dx: 0, dy: 300)

        _ = way.holding(Self.onList, onList: true, toward: Self.asks, at: 0)
        #expect(way.holding(resting, onList: false, toward: Self.asks, at: 10) != nil)
        #expect(way.holding(resting, onList: false, toward: lower, at: 20) == nil)
        #expect(!way.holds)
    }

    @Test func aStepOutOfTheTriangleEndsIt() {
        var way = SafeTriangle()

        _ = way.holding(Self.onList, onList: true, toward: Self.asks, at: 0)
        #expect(way.holding(CGPoint(x: 200, y: 200), onList: false, toward: Self.asks, at: 10) != nil)
        #expect(way.holding(CGPoint(x: 210, y: 80), onList: false, toward: Self.asks, at: 20) == nil)
        #expect(!way.holds)
    }

    /// However it closes in, it holds no longer than its time from leaving the list, nor again until the pointer is
    /// back on the list.
    @Test func itHoldsForItsTimeAtMost() {
        let steps = stride(from: 10.0, through: SafeTriangle.lasts + 40, by: 10).map { (x: 100 + $0 / 3, at: $0) }

        #expect(Self.way(steps.filter { $0.at <= SafeTriangle.lasts }) != nil)
        #expect(Self.way(steps) == nil)
    }

    /// The list going from under a still pointer is no way to the asks panel, nor is the pointer moving on from there.
    @Test func theListLeavingAStillPointerStartsNone() {
        var way = SafeTriangle()

        _ = way.holding(Self.onList, onList: true, toward: Self.asks, at: 0)
        #expect(way.holding(Self.onList, onList: false, toward: Self.asks, at: 10) == nil)
        #expect(!way.holds)
        #expect(way.holding(CGPoint(x: 150, y: 200), onList: false, toward: Self.asks, at: 20) == nil)
    }

    /// Whether it must be judged again as time passes: while it holds the pointer, and not once it ends.
    @Test func itAsksToBeJudgedWhileItHolds() {
        var way = SafeTriangle()

        _ = way.holding(Self.onList, onList: true, toward: Self.asks, at: 0)
        #expect(!way.holds)
        _ = way.holding(CGPoint(x: 150, y: 200), onList: false, toward: Self.asks, at: 10)
        #expect(way.holds)
        _ = way.holding(CGPoint(x: 150, y: 200), onList: false, toward: Self.asks, at: 20 + SafeTriangle.window)
        #expect(!way.holds)
    }
}
