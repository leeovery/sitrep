import AppKit
@testable import SitRep
import SitRepPanel
import SitRepTestSupport
import Testing

/// A scroll event as the edge takes it (DESIGN, "Paging"): its deltas the way the Mac scrolls, a wheel's notch as 16
/// points; and where it falls in its gesture, a trackpad's momentum apart from the gesture before it, so a flick takes
/// no second step, and a mouse's wheel, which has no phases.
@MainActor
@Suite(.backstop)
struct ScrollEventTests {
    /// A scroll event, `across` and `down` in pixels, or in a wheel's lines, at a trackpad's scroll and momentum
    /// phases, as Quartz numbers them.
    private static func event(
        across: Int32, down: Int32 = 0, phase: Int64 = 0, momentum: Int64 = 0, lines: Bool = false
    ) throws -> NSEvent {
        let made = try #require(CGEvent(
            scrollWheelEvent2Source: nil, units: lines ? .line : .pixel, wheelCount: 2, wheel1: down, wheel2: across,
            wheel3: 0
        ))

        made.setIntegerValueField(.scrollWheelEventIsContinuous, value: lines ? 0 : 1)
        made.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        made.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
        return try #require(NSEvent(cgEvent: made))
    }

    @Test func itsDeltasAreTheWayTheMacScrollsAWheelsNotchSixteenPoints() throws {
        let precise = try Self.event(across: -20, down: 6, phase: 2), notch = try Self.event(across: -1, lines: true)

        #expect(Scroll(precise).along == -precise.scrollingDeltaX && Scroll(precise).down == -precise.scrollingDeltaY)
        #expect(Scroll(precise).along > 0)
        #expect(!notch.hasPreciseScrollingDeltas && Scroll(notch).along == -notch.scrollingDeltaX * 16)
    }

    /// The fingers' touch and their scroll beginning begin it; their lift, or a cancel, ends it; between, it changes;
    /// whatever runs on after the lift is momentum; and with no phase at all, a mouse's wheel.
    @Test(arguments: [
        (128, 0, Scroll.Phase.began), (1, 0, .began), (2, 0, .changed), (4, 0, .ended),
        (8, 0, .ended), (0, 1, .momentum), (0, 2, .momentum), (0, 3, .momentum), (0, 0, .wheel),
    ] as [(Int64, Int64, Scroll.Phase)])
    func itTellsWhereItFallsInItsGesture(phase: Int64, momentum: Int64, falls: Scroll.Phase) throws {
        #expect(Scroll(try Self.event(across: -4, phase: phase, momentum: momentum)).phase == falls)
    }
}
