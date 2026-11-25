import CoreGraphics
import Foundation
import ServiceManagement
import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SitRepRelay
import SitRepTestSupport
import Testing

/// The welcome's steps and its footer at each (DESIGN, "The welcome window").
@Suite(.backstop)
struct WelcomeStepsTests {
    /// An ask, from Claude to you, after Hello; What it asks of macOS last but for Ready, once Lee has seen what each
    /// leave is for.
    @Test func itRunsHelloAnAskYourEdgeItsSoundWhatItAsksOfMacOSThenReady() {
        #expect(WelcomeSteps().steps == [.hello, .ask, .edge, .sound, .permissions, .ready])
    }

    /// Step 2 plays its own loop; the notch lit at What it asks of macOS, as for needs you, the banner it asks for
    /// beside it.
    @Test func eachStepPlaysItsOwnStage() {
        #expect(WelcomeSteps.all.map(\.stage) == [.loop, .answer, .lit, .chime, .lit, .callout])
        #expect(WelcomeSteps.all.map(\.stage.loop) == [.hello, .ask, nil, nil, nil, nil])
    }

    @Test func eachHeadlineIsPapers() {
        #expect(WelcomeSteps.all.map(\.headline) == [
            "Every session, at the edge of your screen.", "Claude asks. You answer.", "Choose what sits at your edge.",
            "Hear it when Claude needs you.", "Two things to allow, both optional.",
            "You're set. One thing in Claude Code.",
        ])
        #expect(WelcomeStep.ask.paragraph == "When a session needs you, the notch lights. Open it, pick the ask, and "
            + "you're in the session's window to answer.")
        #expect(WelcomeStep.permissions.paragraph == "SitRep works without either. Each one turns on one thing.")
    }

    @Test func backAndContinueStopAtEitherEnd() {
        var steps = WelcomeSteps()

        steps.back()
        #expect(steps.current == .hello)
        for _ in 0 ..< 7 {
            steps.next()
        }
        #expect(steps.current == .ready && steps.isLast)
        steps.restart()
        #expect(steps.current == .hello && steps.isFirst)
    }

    /// The chevron dimmed, the first of six dashes long, Continue, and Skip setup there.
    @Test func atTheFirstStepTheChevronIsDimmed() {
        #expect(WelcomeSteps().footer == WelcomeFooter(
            canGoBack: false, dashes: [.current] + Array(repeating: .ahead, count: 5), continueTitle: "Continue",
            showsSkip: true
        ))
    }

    @Test func betweenThemItReadsContinue() {
        var steps = WelcomeSteps()

        steps.next()
        steps.next()
        #expect(steps.footer == WelcomeFooter(
            canGoBack: true, dashes: [.done, .done, .current, .ahead, .ahead, .ahead], continueTitle: "Continue",
            showsSkip: true
        ))
    }

    /// With nothing left to skip, Skip setup goes.
    @Test func atTheLastStepItReadsDoneAndSkipSetupGoes() {
        var steps = WelcomeSteps()

        for _ in 0 ..< 5 {
            steps.next()
        }
        #expect(steps.footer == WelcomeFooter(
            canGoBack: true, dashes: Array(repeating: .done, count: 5) + [.current], continueTitle: "Done",
            showsSkip: false
        ))
    }

    /// The list is data: a dash for each step it holds.
    @Test func aDashForEachStepInTheList() {
        let steps = WelcomeSteps([.hello, .edge, .sound, .edge, .ready, .hello])

        #expect(steps.footer.dashes.count == 6)
    }
}

/// Whether a welcome has closed on this Mac, kept apart from what Lee sets.
@Suite(.backstop)
struct WelcomeSettingsTests {
    @Test func noWelcomeHasClosedAtFirst() {
        #expect(SavedSettings<WelcomeSettings>(MemoryDefaults()).read().welcomed == false)
    }

    @Test func itIsKeptUnderAKeyOfItsOwn() {
        let defaults = MemoryDefaults()

        SavedSettings<WelcomeSettings>(defaults).save(WelcomeSettings(welcomed: true))
        #expect(SavedSettings<WelcomeSettings>(defaults).read().welcomed)
        #expect(defaults.data(forKey: "welcome") != nil)
        #expect(defaults.data(forKey: AppSettings.key) == nil)
    }

    @Test func aValueWithoutTheFlagReadsAsNoneClosed() throws {
        let saved = try JSONDecoder().decode(WelcomeSettings.self, from: Data(#"{"other": 1}"#.utf8))

        #expect(saved == WelcomeSettings())
    }
}

/// The callout beside the real edge: due only as Done closes a welcome, and gone for good at the first hover.
@Suite(.backstop)
struct CalloutSettingsTests {
    private static func after(_ moves: (inout CalloutSettings) -> Void) -> CalloutSettings.Standing {
        var callout = CalloutSettings()

        moves(&callout)
        return callout.standing
    }

    @Test func itShowsOnlyOnceDoneHasClosedAWelcome() {
        #expect(!CalloutSettings().shows)
        #expect(Self.after { $0.done(.notch) } == .due)
        #expect(CalloutSettings(.due).shows)
    }

    @Test func theFirstHoverTakesItAwayForGood() {
        #expect(Self.after { $0.done(.notch); $0.pointedAt() } == .gone)
        #expect(Self.after { $0.done(.notch); $0.pointedAt(); $0.done(.notch) } == .gone)
    }

    /// Done at Nothing arms nothing: a shape picked later meets no callout. One already due still waits for a shape.
    @Test func doneAtNothingLeavesItAsItStood() {
        #expect(Self.after { $0.done(.nothing) } == .unshown)
        #expect(Self.after { $0.done(.nothing); $0.done(.strip) } == .due)
        #expect(Self.after { $0.done(.notch); $0.done(.nothing) } == .due)
    }

    /// Pointed at before any Done, there is nothing to take away: the next Done still shows it.
    @Test func aHoverBeforeDoneLeavesItToShow() {
        #expect(Self.after { $0.pointedAt(); $0.done(.notch) } == .due)
    }

    /// Apart from what Lee sets, as whether a welcome has closed is.
    @Test func itIsKeptUnderAKeyOfItsOwn() throws {
        let defaults = MemoryDefaults()

        SavedSettings<CalloutSettings>(defaults).save(CalloutSettings(.gone))
        #expect(SavedSettings<CalloutSettings>(defaults).read().standing == .gone)
        #expect(defaults.data(forKey: "notchCallout") != nil)
        #expect(defaults.data(forKey: AppSettings.key) == nil && defaults.data(forKey: WelcomeSettings.key) == nil)
        #expect(try JSONDecoder().decode(CalloutSettings.self, from: Data(#"{"other": 1}"#.utf8)) == CalloutSettings())
    }
}

/// Step 5's rows, and where each stands as macOS says.
@Suite(.backstop)
struct WelcomePermissionTests {
    @Test func eachRowHasItsReasonInOneClauseAndAButtonNamedForWhatItDoes() {
        #expect(WelcomePermission.allCases.map(\.title) == ["Notifications", "Control Ghostty"])
        #expect(WelcomePermission.allCases.map(\.reason) == [
            "So an ask reaches you when the edge is out of sight", "So a click takes you to the session's window",
        ])
        #expect(WelcomePermission.allCases.map(\.ask) == ["Turn On…", "Allow…"])
    }

    /// On only with the switch on and macOS showing them; refused while macOS shows none, whatever the switch.
    @Test func notificationsStandAsMacOSAndTheSwitchSay() {
        #expect(WelcomeLeave.notifications(nil, isOn: true) == .toAsk)
        #expect(WelcomeLeave.notifications(.unasked, isOn: true) == .toAsk)
        #expect(WelcomeLeave.notifications(.allowed(.banners), isOn: false) == .toAsk)
        #expect(WelcomeLeave.notifications(.allowed(.banners), isOn: true) == .on)
        #expect(WelcomeLeave.notifications(.allowed(.alerts), isOn: true) == .on)
        #expect(WelcomeLeave.notifications(.provisional, isOn: true) == .on)
        #expect(WelcomeLeave.notifications(.denied, isOn: false) == .refused)
        #expect(WelcomeLeave.notifications(.allowed(.none), isOn: true) == .refused)
    }

    /// One macOS can't say of, as Ghostty isn't running, is to ask: Allow… opens Ghostty first.
    @Test func ghosttyStandsAsMacOSSays() {
        #expect(WelcomeLeave.ghostty(.allowed) == .on)
        #expect(WelcomeLeave.ghostty(.denied) == .refused)
        #expect([GhosttyLeave.unasked, .unknown].map(WelcomeLeave.ghostty) == [.toAsk, .toAsk])
        #expect(WelcomeLeave.ghostty(nil) == .toAsk)
    }

    /// Under the reason: where macOS asked, once Lee has waited on it; to ask, what went wrong with the last ask;
    /// with no Ghostty to open, why; else nothing.
    @Test func theLineUnderARowsReasonSaysWhatItShould() {
        let ghostty = WelcomePermission.ghostty, notifications = WelcomePermission.notifications

        #expect(ghostty.line(.asking(waitedLong: false), hitch: nil) == nil)
        #expect(ghostty.line(.asking(waitedLong: true), hitch: nil) == ghostty.whereAsked)
        #expect(notifications.line(.asking(waitedLong: true), hitch: nil) == notifications.whereAsked)
        #expect(ghostty.line(.toAsk, hitch: nil) == nil)
        #expect(ghostty.line(.toAsk, hitch: .didNotOpen) == "Ghostty didn't open, so macOS couldn't ask")
        #expect(notifications.line(.toAsk, hitch: .noAnswer) == "SitRep couldn't get macOS's answer")
        #expect(ghostty.line(.unavailable, hitch: .notInstalled) == "Ghostty isn't installed")
        #expect(ghostty.line(.on, hitch: nil) == nil && ghostty.line(.refused, hitch: nil) == nil)
    }
}

/// What the welcome does to the login item.
@Suite(.backstop)
struct WelcomeLoginTests {
    private static let off = LoginItem(.notRegistered)
    private static let on = LoginItem(.enabled)
    private static let waiting = LoginItem(.requiresApproval)

    private enum Moment {
        case arrive, close
    }

    /// Whether it registers SitRep at each moment in turn, the item as given at each.
    private static func registers(_ login: WelcomeLogin, _ moments: [(Moment, LoginItem)]) -> [Bool] {
        var login = login

        return moments.map { moment, item in moment == .arrive ? login.arrive(item) : login.close(item) }
    }

    private static func pressed(_ login: WelcomeLogin) -> WelcomeLogin {
        var login = login

        login.press()
        return login
    }

    /// So macOS's notice comes as the stage shows it.
    @Test func theFirstWelcomeRegistersSitRepAsLeeArrivesAtTheSwitch() {
        #expect(Self.registers(WelcomeLogin(isFirst: true), [(.arrive, Self.off), (.close, Self.off)]) == [true, false])
    }

    @Test func leavingBeforeTheSwitchRegistersItAsTheWindowCloses() {
        #expect(Self.registers(WelcomeLogin(isFirst: true), [(.close, Self.off)]) == [true])
    }

    /// Turned off once registered, it stays off: the switch is Lee's.
    @Test func theSwitchPressedIsLeesAndClosingLeavesIt() {
        let pressed = Self.pressed(WelcomeLogin(isFirst: true))

        #expect(Self.registers(pressed, [(.arrive, Self.off), (.close, Self.off)]) == [false, false])
    }

    @Test func itNeverRegistersWhatIsOnOrWaitsOnLeesApproval() {
        #expect(Self.registers(WelcomeLogin(isFirst: true), [(.arrive, Self.on), (.close, Self.off)]) == [false, false])
        #expect(Self.registers(WelcomeLogin(isFirst: true), [(.close, Self.waiting)]) == [false])
    }

    /// As on Lee's own Mac, SitRep registered before any welcome closed: found on, it is his, so turned off in
    /// Settings › General, closing leaves it off.
    @Test func anItemFoundOnIsLeesAndClosingNeverTurnsItBackOn() {
        var login = WelcomeLogin(isFirst: true)

        login.read(Self.on)
        #expect(Self.registers(login, [(.close, Self.off)]) == [false])
    }

    /// Found changed from the last read, Lee changed it elsewhere: it is his.
    @Test func anItemFoundChangedIsLees() {
        var login = WelcomeLogin(isFirst: true)

        login.read(Self.off)
        login.read(Self.waiting)
        #expect(login.isSettled)
        #expect(Self.registers(login, [(.close, Self.off)]) == [false])
    }

    /// Read off, and off as it closes, it is still the welcome's to register.
    @Test func anItemReadOffAndStillOffIsStillTheWelcomes() {
        var login = WelcomeLogin(isFirst: true)

        login.read(Self.off)
        login.read(Self.off)
        #expect(Self.registers(login, [(.close, Self.off)]) == [true])
    }

    /// So a later Show Welcome Window never undoes Lee's choice in General.
    @Test func aWelcomeOpenedAgainChangesNothingUntilPressed() {
        let again = WelcomeLogin(isFirst: false)

        #expect(Self.registers(again, [(.arrive, Self.off), (.close, Self.off)]) == [false, false])
    }
}

/// The sounds as the welcome lists them.
@Suite(.backstop)
struct WelcomeSoundsTests {
    private static let macOS = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
        "Submarine", "Tink",
    ]

    @Test func glassLeadsTheFourMostDistinctThenTheRestInFindersOrder() {
        #expect(WelcomeSounds(Self.macOS).names == [
            "Glass", "Ping", "Pop", "Tink", "Basso", "Blow", "Bottle", "Frog", "Funk", "Hero", "Morse", "Purr",
            "Sosumi", "Submarine",
        ])
    }

    @Test func theFourthRowSaysHowManyMoreAreAScrollAway() {
        let sounds = WelcomeSounds(Self.macOS)

        #expect((0 ..< 6).map(sounds.aside(at:)) == [nil, nil, nil, "and 10 more", nil, nil])
    }

    @Test func aSoundMacOSLacksIsPassedOver() {
        let sounds = WelcomeSounds(["Basso", "Pop", "Tink"])

        #expect(sounds.names == ["Pop", "Tink", "Basso"])
        #expect(sounds.aside(at: 3) == nil)
    }

    /// The list scrolls as it appears only to a sound chosen past the four that show.
    @Test func itScrollsToASoundChosenAScrollAway() {
        let sounds = WelcomeSounds(Self.macOS)

        #expect(sounds.scrolledTo("Tink") == nil)
        #expect(sounds.scrolledTo("Basso") == "Basso")
        #expect(sounds.scrolledTo("Submarine") == "Submarine")
        #expect(sounds.scrolledTo("Gone") == nil)
    }
}

/// Step 3's form under the pictures.
@Suite(.backstop)
struct WelcomeEdgeFormTests {
    @Test func theNotchsFormIsStyleAndEdge() {
        #expect(WelcomeEdgeForm.rows(EdgeSettings()) == [.style, .edge])
    }

    /// One row for another, so the form keeps its height.
    @Test func atStripLengthTakesStylesPlace() {
        var strip = EdgeSettings()

        strip.show = .strip
        #expect(WelcomeEdgeForm.rows(strip) == [.length, .edge])
    }

    /// The notch's rows stay in their place at Nothing, so the form keeps its height, taking no presses.
    @Test func atNothingTheNotchsRowsStayTakingNoPresses() {
        var nothing = EdgeSettings()

        nothing.show = .nothing
        #expect(WelcomeEdgeForm.rows(nothing) == [.style, .edge])
        #expect(!WelcomeEdgeForm.takesPresses(nothing))
    }

    @Test(arguments: [EdgeSettings.Show.notch, .strip])
    func eachShapeIsChosenAndTakesPresses(show: EdgeSettings.Show) {
        var settings = EdgeSettings()

        settings.show = show
        #expect(WelcomeEdgeForm.chosen(settings) == show)
        #expect(WelcomeEdgeForm.takesPresses(settings))
        #expect(WelcomeEdgeForm.under(settings) == .showNothing)
    }

    /// Neither picture ringed, and the line in Show nothing at the edge's place.
    @Test func atNothingNeitherShapeIsChosenAndTheLineShows() {
        var nothing = EdgeSettings()

        nothing.show = .nothing
        #expect(WelcomeEdgeForm.chosen(nothing) == nil)
        #expect(WelcomeEdgeForm.under(nothing) == .nothingShown)
    }

    @Test func underTheFormItSaysWhatItDoes() {
        #expect(WelcomeEdgeForm.Under.showNothing.words == "Show nothing at the edge")
        #expect(
            WelcomeEdgeForm.Under.nothingShown.words
                == "Only the menu bar's light. Choose Notch or Strip to bring it back."
        )
    }
}

/// The last step's playback, in what-happens words.
@Suite(.backstop)
struct WelcomePlaybackTests {
    private static func edge(_ change: (inout EdgeSettings) -> Void) -> EdgeSettings {
        var settings = EdgeSettings()

        change(&settings)
        return settings
    }

    @Test func atTheEdgeSaysTheShapeItsStyleAndItsEdge() {
        #expect(WelcomePlayback.atTheEdge(EdgeSettings()) == "Meniscus notch, left")
        #expect(WelcomePlayback.atTheEdge(Self.edge { $0.style = .card; $0.edge = .right }) == "Card notch, right")
        #expect(WelcomePlayback.atTheEdge(Self.edge { $0.show = .strip }) == "Strip, left")
        #expect(WelcomePlayback.atTheEdge(Self.edge { $0.show = .nothing }) == "The menu bar's light alone")
    }

    @Test(arguments: [
        (true, true, "Pop, and a notification"), (true, false, "Pop"), (false, true, "A notification"),
        (false, false, "Silent"),
    ])
    func aNewAskSaysItsSoundAndItsNotification(plays: Bool, notifies: Bool, words: String) {
        var app = AppSettings()

        app.playsSound = plays
        app.notifiesNewAsks = notifies
        #expect(WelcomePlayback.newAsk(app, sound: "Pop") == .init(label: "A new ask", words: words, fix: nil))
    }

    /// While macOS shows none of SitRep's notifications, A new ask promises none and has step 5's Open System
    /// Settings… in place; with Notify me off, it promised none, so it has nothing to fix.
    @Test(arguments: [(true, "Pop"), (false, "Silent")])
    func aNewAskPromisesNoNotificationMacOSRefuses(plays: Bool, words: String) {
        var app = AppSettings()

        app.playsSound = plays
        app.notifiesNewAsks = true
        #expect(WelcomePlayback.newAsk(app, sound: "Pop", notices: .refused) == .init(
            label: "A new ask", words: words, fix: .notifications
        ))
        #expect(WelcomePlayback.Fix.notifications.title == "Open System Settings…")
        app.notifiesNewAsks = false
        #expect(WelcomePlayback.newAsk(app, sound: "Pop", notices: .refused).fix == nil)
        app.notifiesNewAsks = true
        #expect(WelcomePlayback.newAsk(app, sound: "Pop", notices: .on).fix == nil)
    }

    @Test func atLoginHasItsFixInPlaceWhereItIsOff() {
        #expect(
            WelcomePlayback.atLogin(LoginItem(.enabled)) == .init(label: "At login", words: "Opens SitRep", fix: nil)
        )
        #expect(WelcomePlayback.atLogin(LoginItem(.notRegistered)).fix == .turnOnLogin)
        #expect(WelcomePlayback.atLogin(LoginItem(.requiresApproval)).fix == .loginItems)
    }

    @Test func theFourRowsInTheirOrder() {
        let rows = WelcomePlayback.rows(
            edge: EdgeSettings(), app: AppSettings(), sound: "Glass", notices: .toAsk, login: LoginItem(.enabled),
            ghostty: .on
        )

        #expect(rows.map(\.label) == ["At the edge", "A new ask", "At login", "A click"])
        #expect(rows.map(\.words) == ["Meniscus notch, left", "Glass", "Opens SitRep", "Opens the session's window"])
    }

    /// Without the leave a click brings Ghostty forward, to none of its windows: step 5's Allow… in place, with what
    /// went wrong with its last ask, or once refused, the way to Automation.
    @Test func aClickHasStepFivesAskInPlaceWhileGhosttysLeaveIsntGranted() {
        #expect(WelcomePlayback.aClick(.on) == .init(label: "A click", words: "Opens the session's window", fix: nil))
        #expect(WelcomePlayback.aClick(.toAsk) == .init(label: "A click", words: "Opens Ghostty", fix: .allowGhostty))
        #expect(WelcomePlayback.aClick(.toAsk, hitch: .didNotOpen).line == "Ghostty didn't open, so macOS couldn't ask")
        #expect(WelcomePlayback.aClick(.refused) == .init(label: "A click", words: "Opens Ghostty", fix: .automation))
        #expect(WelcomePlayback.Fix.allowGhostty.title == "Allow…")
        #expect(WelcomePlayback.Fix.automation.title == "Open System Settings…")
    }

    /// While its ask is under way, step 5's row: a spinner in the fix's place, and where macOS asked once Lee has
    /// waited on it.
    @Test func aClickWhileItsAskIsUnderWayShowsStepFivesSpinner() {
        #expect(WelcomePlayback.aClick(.asking(waitedLong: false)) == .init(
            label: "A click", words: "Opens Ghostty", fix: nil, isAsking: true
        ))
        #expect(WelcomePlayback.aClick(.asking(waitedLong: true)).line == WelcomePermission.ghostty.whereAsked)
    }

    /// With no Ghostty to open, what a click needs, in what-happens words, with nothing to press.
    @Test func aClickWithNoGhosttyNeedsIt() {
        #expect(WelcomePlayback.aClick(.unavailable, hitch: .notInstalled) == .init(
            label: "A click", words: "Needs Ghostty", fix: nil
        ))
    }
}

/// What the last step asks of Claude Code.
@Suite(.backstop)
struct WelcomeReloadTests {
    @Test func itAsksForReloadPluginsWhileThePluginRunsOrIsLookedFor() {
        #expect(WelcomeReload(nil) == .command("/reload-plugins"))
        #expect(WelcomeReload(.running(.own, folder: "/plugin")) == .command("/reload-plugins"))
    }

    /// In Settings' words for the plugin's row.
    @Test func whereThePluginsInstallFailedItSaysWhatFailed() {
        let standing = PluginStanding.trouble(.failed("marketplace add exited 1"), folder: nil)

        #expect(WelcomeReload(standing) == .trouble(.plugin(LastBoard(), plugin: standing)))
        #expect(WelcomeReload(standing) == .trouble(SettingsRow(
            label: "Claude Code plugin", line: "SitRep couldn't set up its plugin. marketplace add exited 1",
            side: .none
        )))
    }
}

/// The stage's made-up board and step 1's loop.
@Suite(.backstop)
struct WelcomeStagePlayTests {
    @Test func atRestNothingNeedsLee() {
        let board = WelcomeBoard.calm(at: 0)

        #expect(!board.needsLee)
        #expect(board.sessions.map(\.kind) == [.working, .working])
    }

    /// Needs you 1 and Working 2, in the panel's order.
    @Test func theAskLandsInNeedsYouNewAsItLands() {
        let landing = WelcomeBoard.asked(at: 0, isNew: true), lit = WelcomeBoard.asked(at: 0, isNew: false)

        #expect(landing.needsLee)
        #expect(landing.sessions.map(\.title) == [Sample.needsYou, "Running ", "Writing "])
        #expect(landing.sessions.map(\.code) == [nil, "the tests", "DESIGN.md"])
        expectEvery(landing.sessions) { $0.sub == "Project · Session" }
        #expect(landing.new == [WelcomeBoard.asking])
        #expect(lit.needsLee && lit.new.isEmpty)
    }

    @Test func theAskLandsPartWayThroughTheLoopAndIsGoneAsItStartsAgain() {
        #expect(!WelcomeLoop.hello.asks(at: 0))
        #expect(WelcomeLoop.hello.asks(at: WelcomeLoop.hello.lands))
        #expect(WelcomeLoop.hello.asks(at: WelcomeLoop.hello.length - 1))
        #expect(!WelcomeLoop.hello.asks(at: WelcomeLoop.hello.length + 1))
    }

    private static let home = CGPoint(x: 4, y: 300), row = CGPoint(x: 150, y: 120)

    /// The pointer comes to the notch, rests on the panel it pours, and leaves, so it closes.
    @Test func thePointerComesToTheNotchRestsAndLeaves() throws {
        let path = stride(from: 0, to: WelcomeLoop.hello.length, by: 100).map {
            WelcomeLoop.hello.pointer(at: $0, home: Self.home)
        }
        let present = path.compactMap(\.self)

        #expect(path.first == .some(nil))
        #expect(path.last == .some(nil))
        #expect(present.contains(Self.home))
        #expect(try #require(present.first).x > 200)
        #expect(present.map(\.x).min() == Self.home.x)
        #expect(WelcomeLoop.hello.pointer(at: WelcomeLoop.hello.lands, home: Self.home) == nil)
    }

    /// Once the panel has poured, the pointer steps from the notch onto the ask's row, and rests there until it leaves.
    @Test func afterThePourThePointerStepsOntoTheAsksRow() throws {
        let path = stride(from: 0, to: WelcomeLoop.hello.length, by: 100).compactMap {
            WelcomeLoop.hello.pointer(at: $0, home: Self.home, row: Self.row)
        }
        let onRow = try #require(path.firstIndex(of: Self.row))

        let left = try #require(path.lastIndex(of: Self.row))

        #expect(try #require(path.lastIndex(of: Self.home)) == onRow - 1)
        expectEvery(path[onRow ... left]) { $0 == Self.row }
        #expect(path[onRow ... left].count >= 20)
        #expect(WelcomeLoop.hello.pointer(at: WelcomeLoop.hello.onRow, home: Self.home, row: Self.row) == Self.row)
    }

    /// From the moment it touches the edge, in both loops, the pointer is only ever at home, which no row covers, on
    /// the ask's row, or level with the row going out from it: never between home and the row, where it would light
    /// another row as it passed, nor off the row's height on its way out.
    @Test(arguments: [WelcomeLoop.hello, .ask])
    func onTheEdgeThePointerIsAtHomeOnTheRowOrLevelWithItGoingOut(_ loop: WelcomeLoop) {
        for time in stride(from: loop.arrive, to: loop.length, by: 10) {
            let pointer = loop.pointer(at: time, home: Self.home, row: Self.row)
            let goesOut = pointer.map { $0.y == Self.row.y && $0.x >= Self.row.x } ?? true

            #expect(pointer == Self.home || goesOut, "at \(time)")
            if loop.findsRow(at: time) {
                #expect(pointer != nil, "at \(time)")
            }
        }
        #expect(loop.pointer(at: loop.leave - 1, home: Self.home, row: Self.row) == Self.row)
        #expect(loop.pointer(at: loop.gone ?? loop.leave, home: Self.home, row: Self.row) == nil)
    }

    /// Step 1's pointer glides off the row past the panel's front, 372 deep, so the notch closes as a hand leaving it
    /// closes it; with no row found, it leaves at once from home, as a glide from there would cross the rows. Step
    /// 2's leaves at once, as the jump takes Lee into the session.
    @Test func onlyStepOnesPointerGlidesOffTheRow() throws {
        let hello = WelcomeLoop.hello, gone = try #require(hello.gone)
        let out = try #require(hello.pointer(at: gone - 1, home: Self.home, row: Self.row))

        #expect(out.y == Self.row.y && out.x > 372)
        #expect(hello.pointerMoves(at: hello.leave))
        #expect(hello.pointer(at: hello.leave, home: Self.home) == nil)
        #expect(WelcomeLoop.ask.gone == nil && !WelcomeLoop.ask.pointerMoves(at: WelcomeLoop.ask.leave))
    }

    /// The stage looks for the ask's row from once the panel has poured until the pointer leaves the row.
    @Test func theStageLooksForTheRowFromThePourUntilThePointerLeavesIt() throws {
        let times = stride(from: 0, to: WelcomeLoop.hello.length, by: 100)
        let finding = times.filter(WelcomeLoop.hello.findsRow(at:))
        let pointing = times.filter { WelcomeLoop.hello.pointer(at: $0, home: Self.home, row: Self.row) != nil }
        let first = try #require(finding.first)

        #expect(Set(finding).isSubset(of: Set(pointing)))
        #expect(WelcomeLoop.hello.pointer(at: first - 100, home: Self.home) == Self.home)
        #expect(WelcomeLoop.hello.pointer(at: first, home: Self.home, row: Self.row) == Self.home)
        #expect(!WelcomeLoop.hello.findsRow(at: WelcomeLoop.hello.leave))
    }

    /// The pointer goes by the ask's row from when the stage looks for it until it has glided off it: step 1's through
    /// its glide, step 2's until it leaves with the jump.
    @Test(arguments: [WelcomeLoop.hello, .ask])
    func thePointerGoesByTheRowFromTheSearchUntilItHasGlidedOff(_ loop: WelcomeLoop) throws {
        let times = stride(from: 0, to: loop.length, by: 10)
        let holding = times.filter(loop.holdsRow(at:))
        let byRow = times.filter { time in
            let row = loop.pointer(at: time, home: Self.home, row: Self.row)

            return row != nil && row != loop.pointer(at: time, home: Self.home, row: CGPoint(x: Self.row.x, y: Self.row.y + 40))
        }

        try #require(!byRow.isEmpty)
        expectEvery(byRow) { loop.holdsRow(at: $0) }
        #expect(holding.first == loop.seeks)
        #expect(loop.holdsRow(at: (loop.gone ?? loop.leave) - 10) && !loop.holdsRow(at: loop.gone ?? loop.leave))
    }

    /// Frames sleep but for the pointer's glides, to the notch and off the row: its step onto the row is a beat.
    @Test func thePointerMovesOnlyWhileItGlides() {
        let times = stride(from: 0, to: WelcomeLoop.hello.length, by: 50)

        for time in times {
            let before = WelcomeLoop.hello.pointer(at: time, home: Self.home, row: Self.row)
            let after = WelcomeLoop.hello.pointer(at: time + 50, home: Self.home, row: Self.row)
            let steps = before == Self.home && after == Self.row

            if before != nil, after != nil, before != after, !steps {
                #expect(WelcomeLoop.hello.pointerMoves(at: time), "at \(time)")
            }
            if before == after || steps {
                #expect(!WelcomeLoop.hello.pointerMoves(at: time), "at \(time)")
            }
        }
    }

    /// Asleep, the stage wakes at the loop's next beat: the ask landing, the pointer setting off, or the loop again.
    @Test func theLoopsNextBeatIsWhenItNextChangesOfItself() {
        #expect(WelcomeLoop.hello.next(after: 0) == WelcomeLoop.hello.lands)
        #expect(WelcomeLoop.hello.next(after: WelcomeLoop.hello.lands) > WelcomeLoop.hello.lands)
        #expect(WelcomeLoop.hello.pointerMoves(at: WelcomeLoop.hello.next(after: WelcomeLoop.hello.lands)))
        #expect(WelcomeLoop.hello.next(after: WelcomeLoop.hello.length + 10) == WelcomeLoop.hello.length + WelcomeLoop.hello.lands)
        #expect(WelcomeLoop.hello.next(after: WelcomeLoop.hello.length - 1) == WelcomeLoop.hello.length)
        #expect(WelcomeLoop.hello.next(after: WelcomeLoop.hello.seeks) == WelcomeLoop.hello.onRow)
    }

    /// Step 1's loop shows no session and lights no words: the ask stays to its end and no row is clicked.
    @Test func stepOnesLoopClicksNothingAndHasNoScene() {
        let loop = WelcomeLoop.hello
        let times = stride(from: 0, to: loop.length, by: 100)

        expectEvery(times) { loop.scene(at: $0) == .rest && !loop.presses(at: $0) }
    }
}

/// Step 2's loop: the ask lands, the panel pours, the row is clicked, the ask is answered in its session, and it goes.
@Suite(.backstop)
struct WelcomeAskLoopTests {
    private static let loop = WelcomeLoop.ask
    private static let times = Array(stride(from: 0, to: loop.length, by: 50))

    /// The times at which this holds, as one span, first to last.
    private static func span(_ holds: (Double) -> Bool) -> ClosedRange<Double>? {
        let held = times.filter(holds)

        return held.first.map { $0 ... held[held.count - 1] }
    }

    /// Its beats in their order, and a rest at the end before it starts again.
    @Test func itsBeatsComeInTheirOrder() throws {
        let loop = Self.loop
        let clicks = try #require(loop.clicks), answers = try #require(loop.answers)
        let resolves = try #require(loop.resolves)

        #expect(loop.lands < clicks && clicks < answers && answers < resolves && resolves < loop.length)
        #expect(loop.length - resolves >= 2_000)
    }

    /// The ask on the board from its landing until it is answered, so the notch lights and its light goes out.
    @Test func theAskIsOnTheBoardFromItsLandingUntilItIsAnswered() throws {
        let asks = try #require(Self.span(Self.loop.asks(at:)))

        #expect(asks.lowerBound == Self.loop.lands)
        #expect(asks.upperBound == (Self.loop.resolves ?? 0) - 50)
        #expect(!Self.loop.asks(at: Self.loop.length + 10))
    }

    /// The pointer reaches the notch, which pours, then the row, and presses it there until the jump lands; then it
    /// leaves the stage, into the session's window.
    @Test func thePointerPressesTheRowItRestsOn() throws {
        let home = CGPoint(x: 4, y: 300), row = CGPoint(x: 150, y: 120)
        let presses = try #require(Self.span(Self.loop.presses(at:)))

        #expect(presses.lowerBound == Self.loop.clicks)
        for time in Self.times where Self.loop.presses(at: time) {
            #expect(Self.loop.pointer(at: time, home: home, row: row) == row, "at \(time)")
        }
        #expect(Self.loop.pointer(at: presses.upperBound + 50, home: home, row: row) == nil)
        #expect(Self.loop.pointer(at: Self.loop.lands, home: home, row: row) == nil)
        #expect(Self.loop.findsRow(at: presses.lowerBound))
    }

    /// The three lines lit in step: the landing until the pointer sets off, opening it until the click, answering it
    /// until the ask goes; then none, through the rest.
    @Test func theThreeMomentsAreLitInStepWithTheLoop() throws {
        let loop = Self.loop
        let moments = Self.times.map { loop.scene(at: $0).moment }
        let order = moments.reduce(into: [WelcomeLoop.Moment?]()) { order, moment in
            if order.last != moment {
                order.append(moment)
            }
        }

        #expect(order == [nil, .lands, .opens, .answers, nil])
        #expect(loop.scene(at: loop.lands).moment == .lands)
        #expect(loop.scene(at: try #require(loop.clicks)).moment == .answers)
        #expect(loop.scene(at: try #require(loop.resolves)).moment == nil)
    }

    /// The middle line names the shape the stage shows: the strip where Lee chose it, else the notch.
    @Test func itsWordsNameTheShapeTheStageShows() {
        #expect(WelcomeLoop.Moment.allCases.map { $0.words(.notch) } == [
            "An ask lands", "Open it from the notch", "Answer it in its session",
        ])
        #expect(WelcomeLoop.Moment.opens.words(.strip) == "Open it from the strip")
        #expect(WelcomeLoop.Moment.opens.words(.nothing) == "Open it from the notch")
    }

    /// The session's window comes forward as the jump lands, and the answer shows in it once given, both until the
    /// loop starts again.
    @Test func theSessionComesForwardAndTheAnswerShowsInIt() throws {
        let loop = Self.loop
        let inSession = try #require(Self.span { loop.scene(at: $0).isInSession })
        let answered = try #require(Self.span { loop.scene(at: $0).isAnswered })

        #expect(inSession.lowerBound > (loop.clicks ?? 0) && inSession.upperBound == loop.length - 50)
        #expect(answered.lowerBound == loop.answers && answered.upperBound == loop.length - 50)
        #expect(loop.scene(at: 0) == .rest)
    }

    /// Asleep between beats, it wakes at each: the click, the answer and the ask going among them.
    @Test func itWakesAtEachBeat() throws {
        let loop = Self.loop

        for beat in try [loop.lands, #require(loop.clicks), #require(loop.answers), #require(loop.resolves)] {
            #expect(loop.next(after: beat - 1) == beat, "\(beat)")
        }
    }
}

/// The words SitRep makes up where it shows what a place will hold.
@Suite(.backstop)
struct SampleTests {
    /// Settings' notification, the welcome's terminal and its board; the ask's tool aside, which keeps the plugin's
    /// own name, sitrep.
    private static var words: [String] {
        let board = WelcomeBoard.asked(at: 0, isNew: true).sessions
        let lines = board.flatMap(\.lines).flatMap { [$0.ask, $0.title, $0.code].compactMap(\.self) }

        return [Sample.ask, Sample.project, Sample.place, Sample.terminal, Sample.terminalAsk, Sample.needsYou]
            + [Sample.running, Sample.writing].flatMap { [$0.title, $0.code] }
            + [Sample.answer, Sample.terminalAnswer]
            + board.flatMap { [$0.id, $0.project, $0.name, $0.sub] } + lines
    }

    /// Lee's real work never stands in for a sample, the ask's tool's included. Each sample is held to
    /// `tests/real-names.txt`'s rule, and, as samples are few and short, to every listed name and its keyed form
    /// anywhere in it, case aside.
    @Test(.realNamesListed) func noSampleNamesARealProject() throws {
        let real = try RealNames.listed()
        let named = real.names.flatMap { [$0, $0.lowercased().replacingOccurrences(of: " ", with: "-")] }

        for word in Self.words + [Sample.terminalTool] {
            #expect(real.found(in: word).isEmpty, "\(word)")
            for name in named {
                #expect(!word.localizedCaseInsensitiveContains(name), "\(word) holds \(name)")
            }
        }
    }

    /// Nor do SitRep itself or the real request ledger stand in for one, in any checkout, the list or none.
    @Test func noSampleNamesSitRepOrTheLedger() {
        for word in Self.words {
            #expect(!word.localizedCaseInsensitiveContains("SitRep"), "\(word) holds SitRep")
        }
        for word in Self.words + [Sample.terminalTool] {
            #expect(!word.localizedCaseInsensitiveContains("ledger"), "\(word) holds ledger")
        }
    }
}
