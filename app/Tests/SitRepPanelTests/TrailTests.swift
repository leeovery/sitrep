@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The pointer's trail, as the prototype's `trackPointer` and `trailVelocity` keep it: samples in the pointer's own
/// time, one within 1ms of the last moving it, and its speed from them alone, whenever a frame asks.
@Suite(.backstop)
struct TrailTests {
    @Test func aReadingWithin1msOfTheLastMovesItAndAddsNone() {
        var trail = Trail()

        trail.add(Vec(0, 0), at: 0)
        trail.add(Vec(10, 0), at: 20)
        trail.add(Vec(20, 0), at: 20.5)

        #expect(abs(trail.velocity(at: 21).x - 1) < 1e-12)
    }

    @Test func itsSpeedIsTheSamplesOwnWhicheverFrameAsks() {
        var trail = Trail()

        for i in 0 ... 6 {
            trail.add(Vec(0, 0.6 * 10 * Double(i)), at: 10 * Double(i))
        }

        #expect(abs(trail.velocity(at: 60).y - 0.6) < 1e-12)
        #expect(abs(trail.velocity(at: 76).y - 0.6) < 1e-12)
    }

    @Test func aReadingAfterThe60msItStaysFreshForGivesNoSpeed() {
        var trail = Trail()

        trail.add(Vec(0, 0), at: 0)
        trail.add(Vec(0, 10), at: 16)

        #expect(trail.velocity(at: 77) == Vec(0, 0))
    }
}
