import CoreGraphics
import Foundation
import ServiceManagement
import SitRepCore
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepPanel
import Testing

/// The welcome's steps and its footer at each (DESIGN, "The welcome window").
struct WelcomeStepsTests {
    @Test func itRunsHelloYourEdgeItsSoundThenReady() {
        #expect(WelcomeSteps().steps == [.hello, .edge, .sound, .ready])
    }

    @Test func eachStepPlaysItsOwnStage() {
        #expect(WelcomeSteps.all.map(\.stage) == [.loop, .lit, .chime, .callout])
    }

    @Test func eachHeadlineIsPapers() {
        #expect(WelcomeSteps.all.map(\.headline) == [
            "Every session, at the edge of your screen.", "Choose what sits at your edge.",
            "Hear it when Claude needs you.", "You're set. One thing in Claude Code.",
        ])
    }

    @Test func backAndContinueStopAtEitherEnd() {
        var steps = WelcomeSteps()

        steps.back()
        #expect(steps.current == .hello)
        for _ in 0 ..< 5 {
            steps.next()
        }
        #expect(steps.current == .ready && steps.isLast)
        steps.restart()
        #expect(steps.current == .hello && steps.isFirst)
    }

    /// The chevron dimmed, the first dash long, Continue reading Show me, and Skip setup there.
    @Test func atTheFirstStepContinueReadsShowMe() {
        #expect(WelcomeSteps().footer == WelcomeFooter(
            canGoBack: false, dashes: [.current, .ahead, .ahead, .ahead], continueTitle: "Show me", showsSkip: true
        ))
    }

    @Test func betweenThemItReadsContinue() {
        var steps = WelcomeSteps()

        steps.next()
        steps.next()
        #expect(steps.footer == WelcomeFooter(
            canGoBack: true, dashes: [.done, .done, .current, .ahead], continueTitle: "Continue", showsSkip: true
        ))
    }

    /// With nothing left to skip, Skip setup goes.
    @Test func atTheLastStepItReadsDoneAndSkipSetupGoes() {
        var steps = WelcomeSteps()

        steps.next()
        steps.next()
        steps.next()
        #expect(steps.footer == WelcomeFooter(
            canGoBack: true, dashes: [.done, .done, .done, .current], continueTitle: "Done", showsSkip: false
        ))
    }

    /// The list is data: a dash for each step it holds.
    @Test func aDashForEachStepInTheList() {
        let steps = WelcomeSteps([.hello, .edge, .sound, .edge, .ready, .hello])

        #expect(steps.footer.dashes.count == 6)
    }
}

/// Whether a welcome has closed on this Mac, kept apart from what Lee sets.
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

/// What the welcome does to the login item.
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

    /// So a later Welcome… never undoes Lee's choice in General.
    @Test func aWelcomeOpenedAgainChangesNothingUntilPressed() {
        #expect(Self.registers(WelcomeLogin(isFirst: false), [(.arrive, Self.off), (.close, Self.off)]) == [false, false])
    }
}

/// The sounds as the welcome lists them.
struct WelcomeSoundsTests {
    private static let macOS = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
        "Submarine", "Tink",
    ]

    @Test func glassLeadsTheFourMostDistinctThenTheRestInFindersOrder() {
        #expect(WelcomeSounds(Self.macOS).names == [
            "Glass", "Ping", "Pop", "Tink", "Basso", "Blow", "Bottle", "Frog", "Funk", "Hero", "Morse", "Purr", "Sosumi",
            "Submarine",
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
}

/// Step 3's form under the pictures.
struct WelcomeEdgeFormTests {
    @Test func theNotchsFormIsStyleMaterialAndEdge() {
        #expect(WelcomeEdgeForm.rows(EdgeSettings(), hasGlass: true) == [.style, .material, .edge])
    }

    /// One row for another, so the form keeps its height.
    @Test func atStripLengthTakesStylesPlace() {
        var strip = EdgeSettings()

        strip.show = .strip
        #expect(WelcomeEdgeForm.rows(strip, hasGlass: true) == [.length, .material, .edge])
    }

    @Test func beforeMacOS26ThereIsNoMaterial() {
        #expect(WelcomeEdgeForm.rows(EdgeSettings(), hasGlass: false) == [.style, .edge])
    }
}

/// The last step's playback, in what-happens words.
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

    @Test(arguments: [(true, true, "Pop, and a notification"), (true, false, "Pop"), (false, true, "A notification"), (false, false, "Silent")])
    func aNewAskSaysItsSoundAndItsNotification(plays: Bool, notifies: Bool, words: String) {
        var app = AppSettings()

        app.playsSound = plays
        app.notifiesNewAsks = notifies
        #expect(WelcomePlayback.newAsk(app, sound: "Pop") == words)
    }

    @Test func atLoginHasItsFixInPlaceWhereItIsOff() {
        #expect(WelcomePlayback.atLogin(LoginItem(.enabled)) == .init(label: "At login", words: "Opens SitRep", fix: nil))
        #expect(WelcomePlayback.atLogin(LoginItem(.notRegistered)).fix == .turnOnLogin)
        #expect(WelcomePlayback.atLogin(LoginItem(.requiresApproval)).fix == .loginItems)
    }

    @Test func theFourRowsInTheirOrder() {
        let rows = WelcomePlayback.rows(edge: EdgeSettings(), app: AppSettings(), sound: "Glass", login: LoginItem(.enabled))

        #expect(rows.map(\.label) == ["At the edge", "A new ask", "At login", "A click"])
        #expect(rows.map(\.words) == ["Meniscus notch, left", "Glass", "Opens SitRep", "Opens Ghostty"])
    }
}

/// What the last step asks of Claude Code.
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
            label: "Claude Code plugin", line: "SitRep couldn't set up its plugin. marketplace add exited 1", side: .none
        )))
    }
}

/// The stage's made-up board and step 1's loop.
struct WelcomeStagePlayTests {
    @Test func atRestNothingNeedsLee() {
        let board = WelcomeBoard.calm(at: 0)

        #expect(!board.needsLee)
        #expect(board.sessions.map(\.kind) == [.working, .working, .turn])
    }

    /// Needs you 1, Working 2 and Your turn 1, as Paper's board A lists them.
    @Test func theAskLandsInNeedsYouNewAsItLands() {
        let landing = WelcomeBoard.asked(at: 0, isNew: true), lit = WelcomeBoard.asked(at: 0, isNew: false)

        #expect(landing.needsLee)
        #expect(landing.sessions.map(\.title) == [
            "Keep a year of requests?", "Running ", "Writing ", "Review the picker's themes",
        ])
        #expect(landing.new == [WelcomeBoard.asking])
        #expect(lit.needsLee && lit.new.isEmpty)
    }

    @Test func theAskLandsPartWayThroughTheLoopAndIsGoneAsItStartsAgain() {
        #expect(!WelcomeLoop.asks(at: 0))
        #expect(WelcomeLoop.asks(at: WelcomeLoop.lands))
        #expect(WelcomeLoop.asks(at: WelcomeLoop.length - 1))
        #expect(!WelcomeLoop.asks(at: WelcomeLoop.length + 1))
    }

    /// The pointer comes to the notch, rests on the panel it pours, and leaves, so it closes.
    @Test func thePointerComesToTheNotchRestsAndLeaves() throws {
        let notchY = 300.0
        let path = stride(from: 0, to: WelcomeLoop.length, by: 100).map { WelcomeLoop.pointer(at: $0, notchY: notchY) }
        let present = path.compactMap(\.self)

        #expect(path.first == .some(nil))
        #expect(path.last == .some(nil))
        #expect(present.contains(CGPoint(x: 4, y: notchY)))
        #expect(try #require(present.first).x > 200)
        #expect(present.map(\.x).min() == 4)
        #expect(WelcomeLoop.pointer(at: WelcomeLoop.lands, notchY: notchY) == nil)
    }
}
