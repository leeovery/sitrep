@testable import SitRepPanel
import Testing

struct AskClockTests {
    @Test func withNoAskThereIsNothingToFlash() {
        var clock = AskClock()

        clock.take(lastAsk: nil, simTime: 500, at: 10_000)

        #expect(clock.since(10_100) == nil)
    }

    @Test func anAskIsPlacedOnTheDisplaysClockFromTheFirstFrameThatCarriesIt() {
        var clock = AskClock()

        clock.take(lastAsk: 1000, simTime: 1016, at: 50_000)

        #expect(clock.since(50_000) == 16)
        #expect(clock.since(50_300) == 316)
    }

    @Test func theFlashRunsOnTheDisplaysClockThoughTheSimClockStandsStill() {
        var clock = AskClock()
        clock.take(lastAsk: 1000, simTime: 1016, at: 50_000)

        // frames stop: the sim clock stays at 1016 while the light's own refresh runs on
        clock.take(lastAsk: 1000, simTime: 1016, at: 50_500)

        #expect(clock.since(50_500) == 516)
    }

    @Test func framesAfterAPauseDoNotMoveAnAskAlreadyPlaced() {
        var clock = AskClock()
        clock.take(lastAsk: 1000, simTime: 1016, at: 50_000)

        // minutes idle, then a frame whose sim clock moved on by only the 50ms a frame may take
        clock.take(lastAsk: 1000, simTime: 1066, at: 230_000)

        #expect(clock.since(230_000) == 180_016)
    }

    @Test func aNewAskIsPlacedAfresh() {
        var clock = AskClock()
        clock.take(lastAsk: 1000, simTime: 1016, at: 50_000)

        clock.take(lastAsk: 2000, simTime: 2010, at: 60_000)

        #expect(clock.since(60_000) == 10)
    }
}
