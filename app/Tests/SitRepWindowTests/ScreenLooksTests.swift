import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// When the window runs `sitrep screen`, and what it then says of each session: only while the window shows, at once
/// as it comes to show, or becomes key with its reading over a second old, then five seconds after each look ends,
/// never two at once.
struct ScreenLooksTests {
    private static let start = Date(timeIntervalSince1970: 1_793_000_000)
    private static let shown = ScreenAnswer.read(try! ScreenReading.read(Lines.screen))
    private static let unanswered = ScreenAnswer.read(try! ScreenReading.read(Lines.screenUnanswered))

    private static func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    /// A window opened and visible, as macOS says once it comes forward.
    private static func opened() -> WindowRun {
        let run = WindowRun()

        run.open()
        run.window(isVisible: true)
        return run
    }

    /// A window opened, its first look made at the time given and answered with the reading given at once.
    private static func looked(_ answer: ScreenAnswer = shown, at seconds: TimeInterval = 0) throws -> WindowRun {
        let run = opened()
        let look = try #require(run.looksAtScreen(at: at(seconds)))

        _ = run.looked(answer, of: look, at: at(seconds))
        return run
    }

    @Test func aClosedWindowNeverLooks() {
        let run = WindowRun()

        #expect(run.nextScreenLook == nil)
        #expect(run.looksAtScreen(at: Self.at(60)) == nil)
    }

    @Test func itLooksAtOnceAsItOpensOnceMacOSSaysItIsVisible() {
        let run = WindowRun()

        run.open()
        #expect(run.looksAtScreen(at: Self.start) == nil, "opened still covered, as by a full-screen app")
        run.window(isVisible: true)
        #expect(run.looksAtScreen(at: Self.start) != nil)
    }

    @Test func neverTwoLooksAtOnceHoweverLongOneTakesOrWhatAsksForAnother() {
        let run = Self.opened()

        #expect(run.looksAtScreen(at: Self.start) != nil)
        #expect(run.nextScreenLook == nil)
        run.window(isKey: true, at: Self.at(1))
        run.window(isVisible: false)
        run.window(isVisible: true)
        run.minimise()
        run.restore()
        run.close()
        run.open()
        #expect(run.looksAtScreen(at: Self.at(60)) == nil)
    }

    @Test func theNextLookIsDueFiveSecondsAfterOneEnds() throws {
        let run = try Self.looked(at: 2)

        #expect(run.nextScreenLook == Self.at(7))
        #expect(run.looksAtScreen(at: Self.at(6.9)) == nil)
        #expect(run.looksAtScreen(at: Self.at(7)) != nil)
    }

    @Test func aFailedLookIsFollowedAsAnyIs() throws {
        let run = try Self.looked(.failed("sitrep screen did not answer within 10 seconds."), at: 2)

        #expect(run.nextScreenLook == Self.at(7))
    }

    @Test func becomingKeyLooksAtOnceWhereTheReadingIsOverASecondOld() throws {
        let run = try Self.looked(at: 0)

        run.window(isKey: false, at: Self.at(0.5))
        run.window(isKey: true, at: Self.at(1))
        #expect(run.looksAtScreen(at: Self.at(1)) == nil, "a second old, it stands")
        run.window(isKey: false, at: Self.at(1.5))
        run.window(isKey: true, at: Self.at(1.5))
        #expect(run.looksAtScreen(at: Self.at(1.5)) != nil)
    }

    @Test func becomingKeyDuringALookIsAnsweredByThatLook() throws {
        let run = Self.opened()
        let look = try #require(run.looksAtScreen(at: Self.start))

        run.window(isKey: true, at: Self.at(0.5))
        _ = run.looked(Self.shown, of: look, at: Self.at(1))
        #expect(run.nextScreenLook == Self.at(6))
    }

    @Test(arguments: [true, false])
    func backFromTheDockOrUncoveredDuringALookItLooksAgainAsThatOneEnds(isMinimised: Bool) throws {
        let run = Self.opened()
        let look = try #require(run.looksAtScreen(at: Self.start))

        if isMinimised {
            run.minimise()
            run.restore()
        } else {
            run.window(isVisible: false)
            run.window(isVisible: true)
        }
        #expect(run.looksAtScreen(at: Self.at(0.5)) == nil, "never two at once")
        _ = run.looked(Self.shown, of: look, at: Self.at(1))
        #expect(run.looksAtScreen(at: Self.at(1)) != nil)
    }

    @Test func coveredItStopsAndUncoveredItLooksAtOnce() throws {
        let run = try Self.looked()

        run.window(isVisible: false)
        #expect(run.nextScreenLook == nil)
        #expect(run.looksAtScreen(at: Self.at(60)) == nil)
        run.window(isKey: true, at: Self.at(60))
        #expect(run.looksAtScreen(at: Self.at(60)) == nil, "a window not visible looks not, key or not")
        run.window(isVisible: true)
        #expect(run.looksAtScreen(at: Self.at(61)) != nil)
    }

    @Test func minimisedItStopsAndBackFromTheDockItLooksAtOnce() throws {
        let run = try Self.looked()

        run.minimise()
        run.window(isVisible: false)
        #expect(run.nextScreenLook == nil)
        #expect(run.looksAtScreen(at: Self.at(60)) == nil)
        run.restore()
        #expect(run.looksAtScreen(at: Self.at(60)) == nil, "back still covered, it waits on macOS")
        run.window(isVisible: true)
        #expect(run.looksAtScreen(at: Self.at(61)) != nil)
    }

    @Test func closedItStops() throws {
        let run = try Self.looked()

        run.close()
        #expect(run.nextScreenLook == nil)
        #expect(run.looksAtScreen(at: Self.at(60)) == nil)
    }

    @Test func aLookEndingOnceTheWindowStoppedShowingDuesNoOther() throws {
        let run = Self.opened()
        let look = try #require(run.looksAtScreen(at: Self.start))

        run.window(isVisible: false)
        _ = run.looked(Self.shown, of: look, at: Self.at(1))
        #expect(run.nextScreenLook == nil)
    }

    @Test func aLookBegunBeforeACloseIsLetGoAndTheReopensLookRunsAtOnce() throws {
        let run = Self.opened()
        let look = try #require(run.looksAtScreen(at: Self.start))

        run.close()
        run.open()
        run.window(isVisible: true)
        #expect(!run.looked(Self.shown, of: look, at: Self.at(1)))
        #expect(run.onScreen(of: "sr-0nscrn") == nil)
        #expect(run.looksAtScreen(at: Self.at(1)) != nil)
    }

    @Test func beforeAnyReadingNoSessionHasAnAnswer() {
        #expect(Self.opened().onScreen(of: "sr-0nscrn") == nil)
    }

    @Test func aReadingSaysEachSessionItListsAndNothingOfOneItDoesNot() throws {
        let run = try Self.looked()

        #expect(run.onScreen(of: "sr-0nscrn") == .on)
        #expect(run.onScreen(of: "sr-n0pane") == .off)
        #expect(run.onScreen(of: "sr-awayyy") == nil)
    }

    @Test func unknownIsOnlyWhatTheReadingListsAsUnknown() throws {
        let run = try Self.looked(Self.unanswered)

        #expect(run.onScreen(of: "sr-0nscrn") == .unknown)
        #expect(run.onScreen(of: "sr-awayyy") == nil)
    }

    @Test func aLookSaysWhetherItChangedWhatTheWindowKnows() throws {
        let run = try Self.looked(at: 0)
        let same = try #require(run.looksAtScreen(at: Self.at(5)))

        #expect(!run.looked(Self.shown, of: same, at: Self.at(5)))
        let other = try #require(run.looksAtScreen(at: Self.at(10)))
        #expect(run.looked(Self.unanswered, of: other, at: Self.at(10)))
    }

    @Test func aFailedLookLeavesNoAnswer() throws {
        let run = try Self.looked()
        let look = try #require(run.looksAtScreen(at: Self.at(5)))

        #expect(run.looked(.failed("sitrep screen could not start: no such file."), of: look, at: Self.at(5)))
        #expect(run.onScreen(of: "sr-0nscrn") == nil)
    }

    @Test func minimisedOrCoveredTheReadingStands() throws {
        let run = try Self.looked()

        run.window(isVisible: false)
        run.minimise()
        #expect(run.onScreen(of: "sr-0nscrn") == .on)
    }

    @Test func closingLetsTheReadingGoAndOneEndingAfterIsNotKept() throws {
        let run = try Self.looked()

        run.close()
        #expect(run.onScreen(of: "sr-0nscrn") == nil)

        run.open()
        run.window(isVisible: true)
        let look = try #require(run.looksAtScreen(at: Self.at(60)))
        run.close()
        #expect(!run.looked(Self.shown, of: look, at: Self.at(61)))
        #expect(run.onScreen(of: "sr-0nscrn") == nil)
    }
}
