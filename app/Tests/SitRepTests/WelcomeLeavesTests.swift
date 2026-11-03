import AppKit
@testable import SitRep
import SitRepLines
import SitRepMenu
import SitRepRelay
import Testing

/// Step 5, What it asks of macOS, and step 6's A click, over a Mac of the test's own: macOS is never asked, Ghostty never
/// opened, and the ten seconds never waited.
@MainActor
struct WelcomeLeavesTests {
    typealias Made = WelcomeWindowTests.Made

    /// The welcome at What it asks of macOS, both leaves read.
    private static func atPermissions(_ change: (WelcomeWindowTests.Mac) -> Void = { _ in }) async -> Made {
        let made = Made()

        change(made.mac)
        made.at(.permissions)
        await made.welcome.reading?.value
        return made
    }

    /// A row's button pressed, and its ask, once answered, done.
    private static func press(_ permission: WelcomePermission, on made: Made) async {
        made.welcome.press(permission)
        await made.welcome.asks[permission]?.value
    }

    /// Until macOS answers: the yields an ask's tasks take to reach its prompt, and the wait on it.
    private static func yields() async {
        for _ in 0 ..< 5 {
            await Task.yield()
        }
    }

    // MARK: To ask

    @Test func arrivingAsksMacOSForNothing() async {
        let made = await Self.atPermissions()

        #expect(made.welcome.leave(.notifications) == .toAsk && made.welcome.leave(.ghostty) == .toAsk)
        #expect(made.mac.asksForNotices == 0 && made.mac.allows.isEmpty && made.mac.opensGhostty == 0)
    }

    /// Turn On… turns on Notify me of a new ask, off by default, and asks macOS through the notices helper.
    @Test func turnOnTurnsOnNotifyMeOfANewAskAndAsksMacOS() async {
        let made = await Self.atPermissions()

        #expect(!made.preferences.app.notifiesNewAsks)
        await Self.press(.notifications, on: made)
        #expect(made.preferences.app.notifiesNewAsks)
        #expect(made.mac.asksForNotices == 1)
        #expect(made.welcome.leave(.notifications) == .on)
    }

    /// macOS asks only while Ghostty runs, so Allow… opens it first, and asks once it runs.
    @Test func allowOpensGhosttyFirstWhereItIsntRunning() async {
        let made = await Self.atPermissions()

        await Self.press(.ghostty, on: made)
        #expect(made.mac.opensGhostty == 1)
        #expect(made.mac.allows == [true])
        #expect(made.welcome.leave(.ghostty) == .on)
    }

    @Test func allowAsksAtOnceWhereGhosttyRuns() async {
        let made = await Self.atPermissions { $0.ghosttyRuns = true }

        await Self.press(.ghostty, on: made)
        #expect(made.mac.opensGhostty == 0 && made.mac.allows == [true])
    }

    // MARK: Asking

    /// A spinner while macOS's prompt is up, and after ten seconds of it, where macOS put it.
    @Test func whileMacOSAsksTheRowWaitsAndAfterTenSecondsSaysWhere() async {
        for permission in WelcomePermission.allCases {
            let made = await Self.atPermissions {
                $0.holdsPrompt = true
                $0.holdsWait = true
            }

            made.welcome.press(permission)
            await Self.yields()
            #expect(made.welcome.leave(permission) == .asking(waitedLong: false), "\(permission)")
            #expect(made.mac.waits == [.seconds(10)], "\(permission)")
            made.mac.waitEnds()
            await Self.yields()
            #expect(made.welcome.leave(permission) == .asking(waitedLong: true), "\(permission)")
            made.mac.answer()
            await made.welcome.asks[permission]?.value
            #expect(made.welcome.leave(permission) == .on, "\(permission)")
        }
    }

    /// Answered within the ten seconds, the row never says where the prompt was.
    @Test func anAnswerBeforeTheTenSecondsSaysNothingOfThePrompt() async {
        let made = await Self.atPermissions { $0.holdsWait = true }

        await Self.press(.notifications, on: made)
        made.mac.waitEnds()
        await Self.yields()
        #expect(made.welcome.leave(.notifications) == .on)
    }

    /// Pressed again while its prompt is up, a row asks nothing more.
    @Test func aRowAsksOnceWhileItsPromptIsUp() async {
        let made = await Self.atPermissions { $0.holdsPrompt = true }

        made.welcome.press(.ghostty)
        await Self.yields()
        made.welcome.press(.ghostty)
        await Self.yields()
        #expect(made.mac.allows.count == 1)
        made.mac.answer()
        await made.welcome.asks[.ghostty]?.value
    }

    // MARK: Refused

    /// Open System Settings…, at Notifications or at Privacy & Security › Automation; macOS asked nothing more.
    @Test func refusedOpensSystemSettingsAtTheLeavesPage() async {
        let made = await Self.atPermissions {
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
    @Test func refusedNotificationsTurnTheSwitchOnForWhenLeeAllowsThem() async {
        let made = await Self.atPermissions { $0.notices = .allowed(.none) }

        made.welcome.press(.notifications)
        #expect(made.preferences.app.notifiesNewAsks)
    }

    /// Changed in System Settings, both are read again as the window comes forward.
    @Test func bothAreReadAgainEachTimeTheWindowComesForward() async {
        let made = await Self.atPermissions { $0.notices = .denied }

        made.preferences.app.notifiesNewAsks = true
        made.mac.notices = .allowed(.banners)
        made.mac.ghostty = .allowed
        #expect(made.welcome.leave(.notifications) == .refused && made.welcome.leave(.ghostty) == .toAsk)
        await made.key()
        #expect(made.welcome.leave(.notifications) == .on && made.welcome.leave(.ghostty) == .on)
    }

    // MARK: Never in the way

    /// Continue goes on with neither allowed, and Skip setup from here asks macOS for nothing.
    @Test func neitherHoldsContinueBackAndSkippingAsksNothing() async {
        let made = await Self.atPermissions()

        made.welcome.goOn()
        #expect(made.welcome.step == .ready)
        made.welcome.goBack()
        made.welcome.skip()
        #expect(made.mac.asksForNotices == 0 && made.mac.allows.isEmpty && made.mac.opensGhostty == 0)
    }

    // MARK: A click, on Ready

    /// While the leave isn't granted, the row's Allow… is step 5's: Ghostty opened first, then macOS asked.
    @Test func aClicksAllowIsStepFivesAsk() async {
        let made = Made()

        made.at(.ready)
        await made.welcome.reading?.value
        #expect(made.welcome.playback[3] == .init(label: "A click", words: "Opens Ghostty", fix: .allowGhostty))
        made.welcome.fix(.allowGhostty)
        await made.welcome.asks[.ghostty]?.value
        #expect(made.mac.opensGhostty == 1 && made.mac.allows == [true])
        #expect(made.welcome.playback[3] == .init(label: "A click", words: "Opens the session's window", fix: nil))
    }

    @Test func aClickRefusedOpensAutomation() async {
        let made = Made()

        made.mac.ghostty = .denied
        made.at(.ready)
        await made.welcome.reading?.value
        #expect(made.welcome.playback[3].fix == .automation)
        made.welcome.fix(.automation)
        #expect(made.mac.opened == [.automation] && made.mac.allows.isEmpty)
    }
}

/// The callout a welcome's Done leaves beside the real edge, and the welcome opening by itself at the first start.
@MainActor
struct WelcomeAfterTests {
    typealias Made = WelcomeWindowTests.Made

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

    /// Beside the shape while it shows, following it; the first hover takes it away for good, saved, so a later Done
    /// never brings it back.
    @Test func theFirstHoverTakesTheCalloutAwayForGood() {
        let defaults = MemoryDefaults(), preferences = Preferences(defaults)
        var placed: [EdgeCallout.Beside?] = []
        let callout = EdgeCallout(preferences) { placed.append($0) }
        let notch = EdgeCallout.Beside(resting: CGRect(x: 0, y: 400, width: 7, height: 60), isRight: false)

        callout.beside(notch)
        #expect(placed.isEmpty)
        preferences.callout.done()
        #expect(placed == [notch])
        callout.pointedAt()
        #expect(placed == [notch, nil])
        #expect(Preferences(defaults).callout.standing == .gone)
        preferences.callout.done()
        callout.beside(notch)
        #expect(placed == [notch, nil])
    }

    /// The strip, or the notch dragged, takes it along; neither showing, as at Nothing or under a full-screen app,
    /// hides it until one shows again.
    @Test func itFollowsTheShapeAndHidesWhileNeitherShows() {
        let preferences = Preferences(MemoryDefaults())
        var placed: [EdgeCallout.Beside?] = []
        let callout = EdgeCallout(preferences) { placed.append($0) }
        let notch = EdgeCallout.Beside(resting: CGRect(x: 0, y: 400, width: 7, height: 60), isRight: false)
        let strip = EdgeCallout.Beside(resting: CGRect(x: 1476, y: 300, width: 36, height: 300), isRight: true)

        preferences.callout.done()
        callout.beside(notch)
        callout.beside(nil)
        callout.beside(strip)
        callout.beside(strip)
        #expect(placed == [notch, nil, strip])
    }

    /// Its near side 14 past the shape's front, room for its shadow round it, its middle level with the shape's.
    @Test func itStandsFourteenPastTheShapesFront() {
        let size = CGSize(width: 260, height: 90), room = CalloutWindow.room
        let left = CalloutWindow.frame(
            .init(resting: CGRect(x: 0, y: 400, width: 7, height: 60), isRight: false), size: size
        )
        let right = CalloutWindow.frame(
            .init(resting: CGRect(x: 1505, y: 400, width: 7, height: 60), isRight: true), size: size
        )

        #expect(left.minX + room == 7 + 14 && left.midY == 430 && left.size == size)
        #expect(right.maxX - room == 1505 - 14 && right.midY == 430)
    }

    // MARK: The first start

    /// At SitRep's first start on a Mac where no welcome has closed, it opens by itself, as Welcome… opens it; however
    /// it closes, it never opens by itself again.
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
            let first = Made(defaults: defaults, shows: false)

            first.window.showAtFirstStart()
            #expect(first.recorded.steps.first == .orderFront(movesToActiveSpace: true), "\(place)")
            #expect(first.welcome.step == .hello, "\(place)")
            close(first)

            let next = Made(defaults: defaults, shows: false)

            next.window.showAtFirstStart()
            #expect(next.recorded.steps.isEmpty, "\(place)")
        }
    }

    /// Opened by Welcome… and closed since #67, Lee's Mac has had its welcome.
    @Test func aMacWhoseWelcomeHasClosedOpensNoneByItself() {
        let made = Made(welcomed: true, shows: false)

        made.window.showAtFirstStart()
        #expect(made.recorded.steps.isEmpty)
    }
}
