import CoreGraphics
import Foundation
import ServiceManagement
import SitRepCore
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepPanel
import SitRepRelay
import Testing

/// The welcome's steps and its footer at each (DESIGN, "The welcome window").
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

    /// The chevron dimmed, the first of six dashes long, Continue reading Show me, and Skip setup there.
    @Test func atTheFirstStepContinueReadsShowMe() {
        #expect(WelcomeSteps().footer == WelcomeFooter(
            canGoBack: false, dashes: [.current] + Array(repeating: .ahead, count: 5), continueTitle: "Show me",
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
struct CalloutSettingsTests {
    private static func after(_ moves: (inout CalloutSettings) -> Void) -> CalloutSettings.Standing {
        var callout = CalloutSettings()

        moves(&callout)
        return callout.standing
    }

    @Test func itShowsOnlyOnceDoneHasClosedAWelcome() {
        #expect(!CalloutSettings().shows)
        #expect(Self.after { $0.done() } == .due)
        #expect(CalloutSettings(.due).shows)
    }

    @Test func theFirstHoverTakesItAwayForGood() {
        #expect(Self.after { $0.done(); $0.pointedAt() } == .gone)
        #expect(Self.after { $0.done(); $0.pointedAt(); $0.done() } == .gone)
    }

    /// Pointed at before any Done, there is nothing to take away: the next Done still shows it.
    @Test func aHoverBeforeDoneLeavesItToShow() {
        #expect(Self.after { $0.pointedAt(); $0.done() } == .due)
    }

    /// Apart from what Lee sets, as whether a welcome has closed is.
    @Test func itIsKeptUnderAKeyOfItsOwn() throws {
        let defaults = MemoryDefaults()

        SavedSettings<CalloutSettings>(defaults).save(CalloutSettings(.gone))
        #expect(SavedSettings<CalloutSettings>(defaults).read().standing == .gone)
        #expect(defaults.data(forKey: "callout") != nil)
        #expect(defaults.data(forKey: AppSettings.key) == nil && defaults.data(forKey: WelcomeSettings.key) == nil)
        #expect(try JSONDecoder().decode(CalloutSettings.self, from: Data(#"{"other": 1}"#.utf8)) == CalloutSettings())
    }
}

/// Step 5's rows, and where each stands as macOS says.
struct WelcomePermissionTests {
    @Test func eachRowHasItsReasonInOneClauseAndAButtonNamedForWhatItDoes() {
        #expect(WelcomePermission.allCases.map(\.title) == ["Notifications", "Control Ghostty"])
        #expect(WelcomePermission.allCases.map(\.reason) == [
            "So an ask reaches you when the edge is out of sight", "So a click takes you to the session's window",
        ])
        #expect(WelcomePermission.allCases.map(\.ask) == ["Turn On…", "Allow…"])
        #expect(WelcomePermission.patience == .seconds(10))
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

    /// So a later Welcome… never undoes Lee's choice in General.
    @Test func aWelcomeOpenedAgainChangesNothingUntilPressed() {
        let again = WelcomeLogin(isFirst: false)

        #expect(Self.registers(again, [(.arrive, Self.off), (.close, Self.off)]) == [false, false])
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

    @Test(arguments: [
        (true, true, "Pop, and a notification"), (true, false, "Pop"), (false, true, "A notification"),
        (false, false, "Silent"),
    ])
    func aNewAskSaysItsSoundAndItsNotification(plays: Bool, notifies: Bool, words: String) {
        var app = AppSettings()

        app.playsSound = plays
        app.notifiesNewAsks = notifies
        #expect(WelcomePlayback.newAsk(app, sound: "Pop") == words)
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
            edge: EdgeSettings(), app: AppSettings(), sound: "Glass", login: LoginItem(.enabled), ghostty: .on
        )

        #expect(rows.map(\.label) == ["At the edge", "A new ask", "At login", "A click"])
        #expect(rows.map(\.words) == ["Meniscus notch, left", "Glass", "Opens SitRep", "Opens the session's window"])
    }

    /// Without the leave a click brings Ghostty forward, to none of its windows: step 5's Allow… in place, or once
    /// refused, the way to Automation.
    @Test func aClickHasStepFivesAskInPlaceWhileGhosttysLeaveIsntGranted() {
        #expect(WelcomePlayback.aClick(.on) == .init(label: "A click", words: "Opens the session's window", fix: nil))
        #expect(WelcomePlayback.aClick(.toAsk) == .init(label: "A click", words: "Opens Ghostty", fix: .allowGhostty))
        #expect(WelcomePlayback.aClick(.asking(waitedLong: false)).fix == .allowGhostty)
        #expect(WelcomePlayback.aClick(.refused) == .init(label: "A click", words: "Opens Ghostty", fix: .automation))
        #expect(WelcomePlayback.Fix.allowGhostty.title == "Allow…")
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
            label: "Claude Code plugin", line: "SitRep couldn't set up its plugin. marketplace add exited 1",
            side: .none
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
        #expect(landing.sessions.map(\.title) == [Sample.needsYou, "Running ", "Writing ", Sample.yourTurn])
        #expect(landing.sessions.map(\.code) == [nil, "the tests", "DESIGN.md", nil])
        #expect(landing.sessions.allSatisfy { $0.sub == "Project · Session" })
        #expect(landing.new == [WelcomeBoard.asking])
        #expect(lit.needsLee && lit.new.isEmpty)
    }

    @Test func theAskLandsPartWayThroughTheLoopAndIsGoneAsItStartsAgain() {
        #expect(!WelcomeLoop.hello.asks(at: 0))
        #expect(WelcomeLoop.hello.asks(at: WelcomeLoop.hello.lands))
        #expect(WelcomeLoop.hello.asks(at: WelcomeLoop.hello.length - 1))
        #expect(!WelcomeLoop.hello.asks(at: WelcomeLoop.hello.length + 1))
    }

    /// The pointer comes to the notch, rests on the panel it pours, and leaves, so it closes.
    @Test func thePointerComesToTheNotchRestsAndLeaves() throws {
        let notchY = 300.0
        let path = stride(from: 0, to: WelcomeLoop.hello.length, by: 100).map { WelcomeLoop.hello.pointer(at: $0, notchY: notchY) }
        let present = path.compactMap(\.self)

        #expect(path.first == .some(nil))
        #expect(path.last == .some(nil))
        #expect(present.contains(CGPoint(x: 4, y: notchY)))
        #expect(try #require(present.first).x > 200)
        #expect(present.map(\.x).min() == 4)
        #expect(WelcomeLoop.hello.pointer(at: WelcomeLoop.hello.lands, notchY: notchY) == nil)
    }

    /// Once the panel has poured, the pointer moves from the notch onto the ask's row, and rests there until it leaves.
    @Test func afterThePourThePointerMovesOntoTheAsksRow() throws {
        let notchY = 300.0, row = CGPoint(x: 150, y: 120)
        let path = stride(from: 0, to: WelcomeLoop.hello.length, by: 100).compactMap {
            WelcomeLoop.hello.pointer(at: $0, notchY: notchY, row: row)
        }
        let onNotch = try #require(path.firstIndex(of: CGPoint(x: 4, y: notchY)))
        let onRow = try #require(path.firstIndex(of: row))

        #expect(onNotch < onRow)
        #expect(try #require(path.lastIndex(of: CGPoint(x: 4, y: notchY))) < onRow)
        #expect(path.filter { $0 == row }.count >= 20)
    }

    /// The panel looks for the ask's row from the pointer's setting off for it until the pointer is gone.
    @Test func thePanelFindsTheRowOnlyWhileThePointerGoesToIt() throws {
        let times = stride(from: 0, to: WelcomeLoop.hello.length, by: 100)
        let finding = times.filter(WelcomeLoop.hello.findsRow(at:))
        let pointing = times.filter { WelcomeLoop.hello.pointer(at: $0, notchY: 300, row: CGPoint(x: 150, y: 120)) != nil }
        let first = try #require(finding.first)

        #expect(Set(finding).isSubset(of: Set(pointing)))
        #expect(WelcomeLoop.hello.pointer(at: first - 100, notchY: 300) == CGPoint(x: 4, y: 300))
    }

    /// Frames sleep between the pointer's glides: it moves only on its way to the notch, to the row, and away.
    @Test func thePointerMovesOnlyWhileItGlides() {
        let times = stride(from: 0, to: WelcomeLoop.hello.length, by: 50)

        for time in times {
            let before = WelcomeLoop.hello.pointer(at: time, notchY: 300, row: CGPoint(x: 150, y: 120))
            let after = WelcomeLoop.hello.pointer(at: time + 50, notchY: 300, row: CGPoint(x: 150, y: 120))

            if before != nil, after != nil, before != after {
                #expect(WelcomeLoop.hello.pointerMoves(at: time), "at \(time)")
            }
            if before == after {
                #expect(!WelcomeLoop.hello.pointerMoves(at: time) || before == nil, "at \(time)")
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
    }

    /// Step 1's loop shows no session and lights no words: the ask stays to its end and no row is clicked.
    @Test func stepOnesLoopClicksNothingAndHasNoScene() {
        let loop = WelcomeLoop.hello
        let times = stride(from: 0, to: loop.length, by: 100)

        #expect(times.allSatisfy { loop.scene(at: $0) == .rest && !loop.presses(at: $0) })
    }
}

/// Step 2's loop: the ask lands, the panel pours, the row is clicked, the ask is answered in its session, and it goes.
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
    /// goes into the session's window.
    @Test func thePointerPressesTheRowItRestsOn() throws {
        let row = CGPoint(x: 150, y: 120)
        let presses = try #require(Self.span(Self.loop.presses(at:)))

        #expect(presses.lowerBound == Self.loop.clicks)
        for time in Self.times where Self.loop.presses(at: time) {
            #expect(Self.loop.pointer(at: time, notchY: 300, row: row) == row, "at \(time)")
        }
        #expect(Self.loop.pointer(at: presses.upperBound + 50, notchY: 300, row: row) == row)
        #expect(Self.loop.pointer(at: Self.loop.lands, notchY: 300, row: row) == nil)
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
        #expect(WelcomeLoop.Moment.allCases.map(\.words) == [
            "An ask lands", "Open it from the notch", "Answer it in its session",
        ])
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
struct SampleTests {
    /// Lee's real projects never stand in for a sample: Settings' notification, the welcome's terminal and its board.
    /// The ask's tool keeps the plugin's own name, sitrep, and names no project.
    @Test func noSampleNamesARealProject() {
        let board = WelcomeBoard.asked(at: 0, isNew: true).sessions
        let lines = board.flatMap(\.lines).flatMap { [$0.ask, $0.title, $0.code].compactMap(\.self) }
        let words = [Sample.ask, Sample.project, Sample.place, Sample.terminal, Sample.terminalAsk, Sample.needsYou]
            + [Sample.running, Sample.writing].flatMap { [$0.title, $0.code] } + [Sample.yourTurn]
            + [Sample.answer, Sample.terminalAnswer]
            + board.flatMap { [$0.id, $0.project, $0.name, $0.sub] } + lines
        let projects = ["Switchboard", "Kit", "Portal", "Fabric", "ledger"]

        for real in projects + ["SitRep"] {
            #expect(!words.contains { $0.localizedCaseInsensitiveContains(real) }, "\(real)")
        }
        for real in projects {
            #expect(!Sample.terminalTool.localizedCaseInsensitiveContains(real), "\(real)")
        }
    }
}
