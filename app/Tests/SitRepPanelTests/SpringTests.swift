@testable import SitRepPanel
import Testing

struct SpringTests {
    /// The spring's places, a step of this long at a time, for this long.
    private static func run(_ spring: inout Spring, for ms: Double, step: Double = 1000.0 / 60) -> [Double] {
        stride(from: step, through: ms, by: step).map { _ in
            spring.step(step)
            return spring.x
        }
    }

    @Test func aCriticallyDampedSpringSettlesWithoutPassingItsTarget() {
        var spring = Spring(0)
        spring.to(100, 200)

        let path = Self.run(&spring, for: 2000)

        #expect(path.allSatisfy { $0 <= 100 })
        #expect(spring.isAtRest)
        #expect(spring.x == 100)
    }

    @Test func aCriticallyDampedSpringCoversAbout95PercentInItsDuration() {
        var spring = Spring(0)
        spring.to(100, 200)

        _ = Self.run(&spring, for: 200, step: 1)

        #expect(abs(spring.x - 94.8) < 0.1)
    }

    @Test func aCriticallyDampedSpringRetargetedMidFlightStopsAtItsTargetRatherThanPassIt() {
        var spring = Spring(0)
        spring.v = 5
        spring.to(1, 200)

        spring.step(16)

        #expect(spring.x == 1)
        #expect(spring.v == 0)
    }

    @Test func anUnderdampedSpringOvershootsItsTarget() {
        var spring = Spring(0)
        spring.springTo(100, SpringParams(response: 0.3, damping: 0.38))

        let path = Self.run(&spring, for: 1500)

        #expect(path.max()! > 120)
        #expect(spring.isAtRest)
    }

    /// At the dampings of Lee's kicked springs (land, return, ask, rebound). The integrator damps a kick in its first
    /// substep before the spring moves, so the peak falls a little short of the exact one; the prototype's does too.
    @Test(arguments: [0.24, 0.29, 0.38, 0.42])
    func anUnderdampedSpringKickedFromRestPeaksAboutWherePeakSharePredicts(damping: Double) {
        let p = SpringParams(response: 0.3, damping: damping)
        let omega = 2 * Double.pi / (p.response * 1000)
        var spring = Spring(0)
        spring.springTo(0, p)
        spring.v = 1

        let peak = Self.run(&spring, for: 1000, step: 1).max()!

        let predicted = 1 / omega * peakShare(damping)
        #expect(peak <= predicted)
        #expect(peak > 0.98 * predicted)
    }

    @Test func theVelocityCarriesAcrossARetarget() {
        var spring = Spring(0)
        spring.springTo(100, SpringParams(response: 0.3, damping: 0.5))
        _ = Self.run(&spring, for: 50)
        let moving = spring.v
        let at = spring.x

        spring.springTo(-50, SpringParams(response: 0.2, damping: 0.8))
        #expect(spring.v == moving)
        spring.to(-50, 300)
        #expect(spring.v == moving)

        spring.step(1)
        #expect(spring.x > at)
    }

    @Test func aStepOfNoTimeLeavesItWhereItIs() {
        var spring = Spring(10)
        spring.springTo(100, SpringParams(response: 0.3, damping: 0.5))
        spring.v = 2

        spring.step(0)

        #expect(spring.x == 10)
        #expect(spring.v == 2)
    }
}
