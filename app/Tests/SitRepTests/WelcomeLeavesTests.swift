import AppKit
@testable import SitRep
import SitRepMenu
import SitRepRelay
import SitRepTestSupport
import Testing

/// Step 5, What it asks of macOS, and step 6's A click, over a Mac of the test's own: macOS is never asked, Ghostty never
/// opened, and the ten seconds never waited.
@MainActor
@Suite(.backstop)
struct WelcomeLeavesTests {
    typealias Made = WelcomeWorld.Made

    /// The welcome at What it asks of macOS, both leaves read.
    private static func atPermissions(_ change: (WelcomeWorld.Mac) -> Void = { _ in }) async throws -> Made {
        let made = Made()

        change(made.mac)
        made.at(.permissions)
        try await ended(made.welcome.reading, within: .seconds(10))
        return made
    }

    /// A row's button pressed, and its ask, once answered, done.
    private static func press(_ permission: WelcomePermission, on made: Made) async throws {
        made.welcome.press(permission)
        try await ended(made.welcome.asks[permission], within: .seconds(10))
    }

    // MARK: To ask

    @Test func arrivingAsksMacOSForNothing() async throws {
        let made = try await Self.atPermissions()

        #expect(made.welcome.leave(.notifications) == .toAsk && made.welcome.leave(.ghostty) == .toAsk)
        #expect(made.mac.asksForNotices == 0 && made.mac.allows.isEmpty && made.mac.opensGhostty == 0)
    }

    /// Turn On… turns on Notify me of a new ask, off by default, and asks macOS through the notices helper.
    @Test func turnOnTurnsOnNotifyMeOfANewAskAndAsksMacOS() async throws {
        let made = try await Self.atPermissions()

        #expect(!made.preferences.app.notifiesNewAsks)
        try await Self.press(.notifications, on: made)
        #expect(made.preferences.app.notifiesNewAsks)
        #expect(made.mac.asksForNotices == 1)
        #expect(made.welcome.leave(.notifications) == .on)
    }

    /// macOS asks only while Ghostty runs, so Allow… opens it first, and asks once it runs.
    @Test func allowOpensGhosttyFirstWhereItIsntRunning() async throws {
        let made = try await Self.atPermissions()

        try await Self.press(.ghostty, on: made)
        #expect(made.mac.opensGhostty == 1)
        #expect(made.mac.allows == [true])
        #expect(made.welcome.leave(.ghostty) == .on)
    }

    @Test func allowAsksAtOnceWhereGhosttyRuns() async throws {
        let made = try await Self.atPermissions { $0.ghosttyRuns = true }

        try await Self.press(.ghostty, on: made)
        #expect(made.mac.opensGhostty == 0 && made.mac.allows == [true])
    }

    // MARK: Asking

    /// A spinner while macOS's prompt is up, and after ten seconds of it, where macOS put it.
    @Test func whileMacOSAsksTheRowWaitsAndAfterTenSecondsSaysWhere() async throws {
        for permission in WelcomePermission.allCases {
            let made = try await Self.atPermissions {
                $0.holdsPrompt = true
                $0.holdsWait = true
            }

            made.welcome.press(permission)
            await until(turns: 1000) { made.mac.isPrompting && made.mac.isWaiting }
            #expect(made.welcome.leave(permission) == .asking(waitedLong: false), "\(permission)")
            #expect(made.mac.waits.contains(.seconds(10)), "\(permission)")
            made.mac.waitEnds()
            await until(turns: 1000) { made.welcome.leave(permission) == .asking(waitedLong: true) }
            made.mac.answer()
            try await ended(made.welcome.asks[permission], within: .seconds(10))
            #expect(made.welcome.leave(permission) == .on, "\(permission)")
        }
    }

    /// Answered within the ten seconds, the row never says where the prompt was.
    @Test func anAnswerBeforeTheTenSecondsSaysNothingOfThePrompt() async throws {
        let made = try await Self.atPermissions { $0.holdsWait = true }

        try await Self.press(.notifications, on: made)
        await until(turns: 1000) { made.mac.isWaiting }
        made.mac.waitEnds()
        try await ended(made.welcome.waitsOnPrompt[.notifications], within: .seconds(10))
        #expect(made.welcome.leave(.notifications) == .on)
    }

    /// Pressed again while its prompt is up, a row asks nothing more.
    @Test func aRowAsksOnceWhileItsPromptIsUp() async throws {
        let made = try await Self.atPermissions { $0.holdsPrompt = true }

        made.welcome.press(.ghostty)
        await until(turns: 1000) { made.mac.isPrompting }

        let asking = made.welcome.asks[.ghostty]

        made.welcome.press(.ghostty)
        #expect(made.welcome.asks[.ghostty] == asking, "no ask begun")
        made.mac.answer()
        try await ended(made.welcome.asks[.ghostty], within: .seconds(10))
        #expect(made.mac.allows.count == 1)
    }

    // MARK: When the ask can't be made

    /// With no Ghostty to open, the row says so and offers nothing; macOS is asked nothing.
    @Test func withGhosttyNotInstalledTheRowSaysSoAndOffersNothing() async throws {
        let made = try await Self.atPermissions { $0.opening = .notInstalled }

        try await Self.press(.ghostty, on: made)
        #expect(made.welcome.leave(.ghostty) == .unavailable)
        #expect(made.mac.allows.isEmpty)
        made.welcome.press(.ghostty)
        #expect(made.mac.opensGhostty == 1)
        #expect(made.welcome.playback[3] == .init(label: "A click", words: "Needs Ghostty", fix: nil))
    }

    /// Ghostty installed since, the row offers Allow… again as the window next comes forward.
    @Test func withGhosttyInstalledSinceAllowIsBack() async throws {
        let made = try await Self.atPermissions { $0.opening = .notInstalled }

        try await Self.press(.ghostty, on: made)
        try await made.key()
        #expect(made.welcome.leave(.ghostty) == .unavailable)
        made.mac.opening = .runs
        try await made.key()
        #expect(made.welcome.leave(.ghostty) == .toAsk && made.welcome.hitch(.ghostty) == nil)
        try await Self.press(.ghostty, on: made)
        #expect(made.welcome.leave(.ghostty) == .on)
    }

    /// Ghostty running but macOS answering neither way, as where Ghostty quit before macOS asked, a line says SitRep
    /// couldn't get its answer, and Allow… stays, to try again.
    @Test func allowWithNoAnswerFromMacOSSaysSo() async throws {
        let made = try await Self.atPermissions { $0.answersGhostty = .unknown }

        try await Self.press(.ghostty, on: made)
        #expect(made.mac.allows == [true])
        #expect(made.welcome.leave(.ghostty) == .toAsk && made.welcome.hitch(.ghostty) == .noAnswer)
        #expect(made.welcome.playback[3].line == WelcomeHitch.noAnswer.words)
        made.mac.answersGhostty = .allowed
        try await Self.press(.ghostty, on: made)
        #expect(made.welcome.leave(.ghostty) == .on)
    }

    /// Ghostty not opening, a line says so and Allow… stays, to try again.
    @Test func withGhosttyNotOpeningALineSaysSoAndAllowStays() async throws {
        let made = try await Self.atPermissions { $0.opening = .didNotOpen }

        try await Self.press(.ghostty, on: made)
        #expect(made.welcome.leave(.ghostty) == .toAsk && made.welcome.hitch(.ghostty) == .didNotOpen)
        #expect(made.mac.allows.isEmpty)
        #expect(made.welcome.playback[3].fix == .allowGhostty)
        #expect(made.welcome.playback[3].line == WelcomeHitch.didNotOpen.words)
        made.mac.opening = .runs
        try await Self.press(.ghostty, on: made)
        #expect(made.mac.opensGhostty == 2 && made.welcome.leave(.ghostty) == .on)
        #expect(made.welcome.hitch(.ghostty) == nil)
    }

    /// The notices helper never answering, Turn On… gives up at its limit and reads what macOS says; with no answer
    /// there either, it says so and leaves Turn On… to try again. Once the helper does return, macOS is read again,
    /// so a late answer shows without the window coming forward.
    @Test func turnOnGivesUpOnASilentHelperAndSaysSo() async throws {
        let made = try await Self.atPermissions {
            $0.notices = nil
            $0.holdsPrompt = true
            $0.limitRunsOut = true
        }

        try await Self.press(.notifications, on: made)
        #expect(made.mac.waits.contains(WelcomePermission.limit))
        #expect(made.welcome.leave(.notifications) == .toAsk)
        #expect(made.welcome.hitch(.notifications) == .noAnswer)
        made.mac.answer()
        await until(turns: 1000) { made.welcome.leave(.notifications) == .on }
        #expect(made.welcome.hitch(.notifications) == nil)
    }

    /// Still unasked at the limit, macOS's prompt is up: the row waits on it, saying where it is, and takes Lee's
    /// answer once he gives it.
    @Test func turnOnPastItsLimitWaitsOnAPromptStillUp() async throws {
        let made = try await Self.atPermissions {
            $0.holdsPrompt = true
            $0.holdsWait = true
            $0.limitRunsOut = true
        }

        made.welcome.press(.notifications)
        await until(turns: 1000) { made.welcome.leave(.notifications) == .asking(waitedLong: true) }
        #expect(made.mac.waits.contains(WelcomePermission.limit) && made.mac.isPrompting)
        made.mac.waitEnds()
        made.mac.answer()
        try await ended(made.welcome.asks[.notifications], within: .seconds(10))
        #expect(made.welcome.leave(.notifications) == .on)
        #expect(made.welcome.hitch(.notifications) == nil)
    }

    /// The helper gone, its ask ends at once with nothing to read: the row says so, rather than nothing.
    @Test func turnOnWithTheHelperGoneSaysSo() async throws {
        let made = try await Self.atPermissions {
            $0.notices = nil
            $0.answersNotices = nil
        }

        try await Self.press(.notifications, on: made)
        #expect(made.welcome.hitch(.notifications) == .noAnswer)
        #expect(made.welcome.leave(.notifications) == .toAsk)
    }

    // MARK: Reads

    /// A read begun before Lee answered, ending after the ask's own, is older than it, so it writes nothing.
    @Test func aStaleReadNeverUndoesAnAnswer() async throws {
        let made = try await Self.atPermissions()

        made.mac.holdsRead = true
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: made.recorded))
        await until(turns: 1000) { made.mac.isReading }
        made.mac.holdsRead = false
        try await Self.press(.notifications, on: made)
        #expect(made.welcome.leave(.notifications) == .on)
        made.mac.readEnds()
        try await ended(made.welcome.reading, within: .seconds(10))
        #expect(made.welcome.leave(.notifications) == .on)
    }

    /// Of two reads, only the later writes: arriving at a step as the window comes forward reads twice.
    @Test func ofTwoReadsTheLaterWrites() async throws {
        let made = try await Self.atPermissions()

        made.mac.holdsRead = true
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: made.recorded))
        await until(turns: 1000) { made.mac.isReading }

        let earlier = made.welcome.reading

        made.mac.holdsRead = false
        made.mac.notices = .denied
        try await made.key()
        #expect(made.welcome.leave(.notifications) == .refused)
        made.mac.readEnds()
        try await ended(earlier, within: .seconds(10))
        #expect(made.welcome.leave(.notifications) == .refused)
    }

    // MARK: Refused

    /// Open System Settings…, at Notifications or at Privacy & Security › Automation; macOS asked nothing more.
    @Test func refusedOpensSystemSettingsAtTheLeavesPage() async throws {
        let made = try await Self.atPermissions {
            $0.notices = .denied
            $0.ghostty = .denied
        }

        #expect(made.welcome.leave(.notifications) == .refused && made.welcome.leave(.ghostty) == .refused)
        made.welcome.press(.notifications)
        made.welcome.press(.ghostty)
        #expect(made.mac.opened == [.notifications, .automation])
        #expect(made.mac.asksForNotices == 0 && made.mac.allows.isEmpty)
    }

    /// The row is about Notify me of a new ask, so it goes on for the banners Lee allows in System Settings.
    @Test func refusedNotificationsTurnTheSwitchOnForWhenLeeAllowsThem() async throws {
        let made = try await Self.atPermissions { $0.notices = .allowed(.none) }

        made.welcome.press(.notifications)
        #expect(made.preferences.app.notifiesNewAsks)
    }

    /// Changed in System Settings, both are read again as the window comes forward.
    @Test func bothAreReadAgainEachTimeTheWindowComesForward() async throws {
        let made = try await Self.atPermissions { $0.notices = .denied }

        made.preferences.app.notifiesNewAsks = true
        made.mac.notices = .allowed(.banners)
        made.mac.ghostty = .allowed
        #expect(made.welcome.leave(.notifications) == .refused && made.welcome.leave(.ghostty) == .toAsk)
        try await made.key()
        #expect(made.welcome.leave(.notifications) == .on && made.welcome.leave(.ghostty) == .on)
    }

    // MARK: Never in the way

    /// Continue goes on with neither allowed, and Skip setup from here asks macOS for nothing.
    @Test func neitherHoldsContinueBackAndSkippingAsksNothing() async throws {
        let made = try await Self.atPermissions()

        made.welcome.goOn()
        #expect(made.welcome.step == .ready)
        made.welcome.goBack()
        made.welcome.skip()
        #expect(made.mac.asksForNotices == 0 && made.mac.allows.isEmpty && made.mac.opensGhostty == 0)
    }

    // MARK: A click, on Ready

    /// While the leave isn't granted, the row's Allow… is step 5's: Ghostty opened first, then macOS asked.
    @Test func aClicksAllowIsStepFivesAsk() async throws {
        let made = Made()

        made.at(.ready)
        try await ended(made.welcome.reading, within: .seconds(10))
        #expect(made.welcome.playback[3] == .init(label: "A click", words: "Opens Ghostty", fix: .allowGhostty))
        made.welcome.fix(.allowGhostty)
        try await ended(made.welcome.asks[.ghostty], within: .seconds(10))
        #expect(made.mac.opensGhostty == 1 && made.mac.allows == [true])
        #expect(made.welcome.playback[3] == .init(label: "A click", words: "Opens the session's window", fix: nil))
    }

    @Test func aClickRefusedOpensAutomation() async throws {
        let made = Made()

        made.mac.ghostty = .denied
        made.at(.ready)
        try await ended(made.welcome.reading, within: .seconds(10))
        #expect(made.welcome.playback[3].fix == .automation)
        made.welcome.fix(.automation)
        #expect(made.mac.opened == [.automation] && made.mac.allows.isEmpty)
    }

    // MARK: A new ask, on Ready

    /// While macOS shows none of SitRep's notifications, A new ask promises none, and has step 5's Open System
    /// Settings… in place.
    @Test func aNewAskPromisesNoNotificationMacOSRefuses() async throws {
        let made = Made()

        made.preferences.app.notifiesNewAsks = true
        made.mac.notices = .denied
        made.at(.ready)
        try await ended(made.welcome.reading, within: .seconds(10))
        #expect(made.welcome.playback[1] == .init(label: "A new ask", words: "Glass", fix: .notifications))
        made.welcome.fix(.notifications)
        #expect(made.mac.opened == [.notifications] && made.mac.asksForNotices == 0)
        made.mac.notices = .allowed(.banners)
        try await made.key()
        #expect(made.welcome.playback[1] == .init(label: "A new ask", words: "Glass, and a notification", fix: nil))
    }
}

/// The callout a welcome's Done leaves beside the real edge, and the welcome opening by itself at the first start.
@MainActor
@Suite(.backstop)
struct WelcomeAfterTests {
    typealias Made = WelcomeWorld.Made

    // MARK: The callout

    @Test func doneLeavesTheCalloutBesideTheRealEdge() {
        let made = Made()

        made.at(.ready)
        made.welcome.goOn()
        #expect(made.preferences.callout.shows)
    }

    /// Skip setup, ⌘W and the close button, and SitRep quitting, leave none.
    @Test func noOtherCloseLeavesIt() {
        let closes: [(Made) -> Void] = [
            { $0.welcome.skip() }, { $0.recorded.performClose(nil) }, { $0.recorded.close() },
            { $0.window.closeIfOpen() },
        ]

        for (place, close) in closes.enumerated() {
            let made = Made()

            made.at(.ready)
            close(made)
            #expect(!made.preferences.callout.shows, "\(place)")
            #expect(made.preferences.welcomed, "\(place)")
        }
    }

    // MARK: The first start

    /// At SitRep's first start on a Mac where no welcome has closed, it opens by itself, as Show Welcome Window opens
    /// it; however it closes, it never opens by itself again.
    @Test func itOpensByItselfOnceAtTheFirstStartAndNeverAgain() {
        let closes: [(Made) -> Void] = [
            { $0.welcome.skip() }, { $0.recorded.performClose(nil) }, { $0.window.closeIfOpen() },
            { made in
                made.at(.ready)
                made.welcome.goOn()
            },
        ]

        for (place, close) in closes.enumerated() {
            let defaults = MemoryDefaults()

            #expect(WelcomeWindow.opensAtStart(Preferences(defaults)), "\(place)")

            let first = Made(defaults: defaults)

            #expect(first.welcome.step == .hello, "\(place)")
            close(first)
            #expect(!WelcomeWindow.opensAtStart(Preferences(defaults)), "\(place)")
        }
    }

    /// Opened by Show Welcome Window and closed since #67, Lee's Mac has had its welcome.
    @Test func aMacWhoseWelcomeHasClosedOpensNoneByItself() {
        #expect(!WelcomeWindow.opensAtStart(Made(welcomed: true).preferences))
    }
}
