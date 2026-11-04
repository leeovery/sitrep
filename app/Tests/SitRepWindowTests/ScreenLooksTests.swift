import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// When the window runs `sitrep screen`, and what it then says of each session: only while the window shows, at once
/// as it comes to show or becomes key, then five seconds after each look ends, never two at once.
struct ScreenLooksTests {
    private static let start = Date(timeIntervalSince1970: 1_793_000_000)
    private static let shown = ScreenAnswer.read(try! ScreenReading.read(Lines.screen))

    private static func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    /// A window opened, its first look made and answered with the reading given at the time given.
    private static func looked(_ answer: ScreenAnswer = shown, at seconds: TimeInterval = 0) -> WindowRun {
        let run = WindowRun()

        run.open()
        #expect(run.looksAtScreen(at: at(seconds)))
        _ = run.looked(answer, at: at(seconds))
        return run
    }

    @Test func aClosedWindowNeverLooks() {
        let run = WindowRun()

        #expect(run.nextScreenLook == nil)
        #expect(!run.looksAtScreen(at: Self.at(60)))
    }

    @Test func itLooksAtOnceAsItOpens() {
        let run = WindowRun()

        run.open()
        #expect(run.looksAtScreen(at: Self.start))
    }

    @Test func neverTwoLooksAtOnceHoweverLongOneTakesOrWhatAsksForAnother() {
        let run = WindowRun()

        run.open()
        #expect(run.looksAtScreen(at: Self.start))
        #expect(run.nextScreenLook == nil)
        run.window(isKey: true, at: Self.at(1))
        run.window(isVisible: false)
        run.window(isVisible: true)
        run.minimise()
        run.restore()
        #expect(!run.looksAtScreen(at: Self.at(60)))
    }

    @Test func theNextLookIsDueFiveSecondsAfterOneEnds() {
        let run = Self.looked(at: 2)

        #expect(run.nextScreenLook == Self.at(7))
        #expect(!run.looksAtScreen(at: Self.at(6.9)))
        #expect(run.looksAtScreen(at: Self.at(7)))
    }

    @Test func aFailedLookIsFollowedAsAnyIs() {
        let run = Self.looked(.failed("sitrep screen did not answer within 10 seconds."), at: 2)

        #expect(run.nextScreenLook == Self.at(7))
    }

    @Test func becomingKeyLooksAtOnce() {
        let run = Self.looked()

        run.window(isKey: false, at: Self.at(1))
        #expect(!run.looksAtScreen(at: Self.at(1)))
        run.window(isKey: true, at: Self.at(1))
        #expect(run.looksAtScreen(at: Self.at(1)))
    }

    @Test func coveredItStopsAndUncoveredItLooksAtOnce() {
        let run = Self.looked()

        run.window(isVisible: false)
        #expect(run.nextScreenLook == nil)
        #expect(!run.looksAtScreen(at: Self.at(60)))
        run.window(isKey: true, at: Self.at(60))
        #expect(!run.looksAtScreen(at: Self.at(60)), "a window not visible looks not, key or not")
        run.window(isVisible: true)
        #expect(run.looksAtScreen(at: Self.at(61)))
    }

    @Test func minimisedItStopsAndBackFromTheDockItLooksAtOnce() {
        let run = Self.looked()

        run.minimise()
        #expect(run.nextScreenLook == nil)
        #expect(!run.looksAtScreen(at: Self.at(60)))
        run.window(isVisible: true)
        #expect(!run.looksAtScreen(at: Self.at(60)), "macOS saying visible does not open a minimised window")
        run.restore()
        #expect(run.looksAtScreen(at: Self.at(61)))
    }

    @Test func closedItStops() {
        let run = Self.looked()

        run.close()
        #expect(run.nextScreenLook == nil)
        #expect(!run.looksAtScreen(at: Self.at(60)))
    }

    @Test func aLookEndingOnceTheWindowStoppedShowingDuesNoOther() {
        let run = WindowRun()

        run.open()
        #expect(run.looksAtScreen(at: Self.start))
        run.window(isVisible: false)
        _ = run.looked(Self.shown, at: Self.at(1))
        #expect(run.nextScreenLook == nil)
    }

    @Test func beforeAnyReadingEverySessionIsUnknown() {
        let run = WindowRun()

        run.open()
        #expect(run.onScreen(of: "sr-0nscrn") == .unknown)
    }

    @Test func aReadingSaysEachSessionItListsAndUnknownForOneItDoesNot() {
        let run = Self.looked()

        #expect(run.onScreen(of: "sr-0nscrn") == .on)
        #expect(run.onScreen(of: "sr-n0pane") == .off)
        #expect(run.onScreen(of: "sr-awayyy") == .unknown)
    }

    @Test func aLookSaysWhetherItChangedWhatTheWindowKnows() {
        let run = Self.looked(at: 0)

        #expect(run.looksAtScreen(at: Self.at(5)))
        #expect(!run.looked(Self.shown, at: Self.at(5)))
        #expect(run.looksAtScreen(at: Self.at(10)))
        #expect(run.looked(.read(try! ScreenReading.read(Lines.screenUnanswered)), at: Self.at(10)))
        #expect(run.onScreen(of: "sr-0nscrn") == .unknown)
    }

    @Test func aFailedLookLeavesEverySessionUnknown() {
        let run = Self.looked()

        #expect(run.looksAtScreen(at: Self.at(5)))
        #expect(run.looked(.failed("sitrep screen could not start: no such file."), at: Self.at(5)))
        #expect(run.onScreen(of: "sr-0nscrn") == .unknown)
    }

    @Test func minimisedOrCoveredTheReadingStands() {
        let run = Self.looked()

        run.window(isVisible: false)
        run.minimise()
        #expect(run.onScreen(of: "sr-0nscrn") == .on)
    }

    @Test func closingLetsTheReadingGoAndOneEndingAfterIsNotKept() {
        let run = Self.looked()

        run.close()
        #expect(run.onScreen(of: "sr-0nscrn") == .unknown)

        run.open()
        #expect(run.looksAtScreen(at: Self.at(60)))
        run.close()
        #expect(!run.looked(Self.shown, at: Self.at(61)))
        #expect(run.onScreen(of: "sr-0nscrn") == .unknown)
    }
}
