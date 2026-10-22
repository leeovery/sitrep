import Foundation
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepMenu
import SitRepPanel
import Testing

struct StaysOnScreenTests {
    private static func rows(_ show: EdgeSettings.Show, length: StripLength = .grows, hasGlass: Bool = true) -> [StaysOnScreen.Row] {
        var settings = EdgeSettings()

        settings.show = show
        settings.length = length

        return StaysOnScreen.rows(settings, hasGlass: hasGlass)
    }

    @Test func theNotchsCardIsEdgeDisplayStyleMaterialAndReduceMotion() {
        #expect(Self.rows(.notch) == [.edge, .display, .style, .material, .reduceMotion])
    }

    @Test func theStripsCardIsEdgeDisplayLengthMaxMaterialAndReduceMotion() {
        #expect(Self.rows(.strip) == [.edge, .display, .length, .max, .material, .reduceMotion])
    }

    @Test func maxIsForGrowsAlone() {
        #expect(Self.rows(.strip, length: .full) == [.edge, .display, .length, .material, .reduceMotion])
        #expect(!Self.rows(.notch, length: .grows).contains(.max))
    }

    @Test func withNothingThereIsNoCardAndOneLineSaysWhatCarriesTheBoard() {
        #expect(Self.rows(.nothing).isEmpty)
        #expect(StaysOnScreen.menuCarries == "The menu and the SitRep window carry the board.")
    }

    @Test func materialIsFromMacOS26AloneAndReduceMotionStaysBeforeIt() {
        #expect(Self.rows(.notch, hasGlass: false) == [.edge, .display, .style, .reduceMotion])
        #expect(Self.rows(.strip, hasGlass: false).last == .reduceMotion)
    }
}

struct DisplayChoiceTests {
    private static let builtIn = DisplayChoice.Connected(id: "A", name: "Built-in Retina Display", isMain: true)
    private static let studio = DisplayChoice.Connected(id: "B", name: "Studio Display", isMain: false)

    @Test func theMainDisplayComesFirstThenEveryOtherByName() {
        #expect(DisplayChoice.choices(among: [Self.builtIn, Self.studio], chosen: nil) == [
            .main, DisplayChoice(id: "B", name: "Studio Display"),
        ])
    }

    @Test func aChosenDisplayNotConnectedStillShowsAsTheChoice() {
        #expect(DisplayChoice.choices(among: [Self.builtIn], chosen: "C") == [
            .main, DisplayChoice(id: "C", name: "A display not connected"),
        ])
    }

    @Test func aChosenDisplayThatBecameTheMainOneShowsByItsName() {
        #expect(DisplayChoice.choices(among: [Self.builtIn, Self.studio], chosen: "A") == [
            .main, DisplayChoice(id: "B", name: "Studio Display"), DisplayChoice(id: "A", name: "Built-in Retina Display"),
        ])
    }
}

/// Notify me of a new ask, and macOS's own answer: a dot when it's fine, a button when it's Lee's.
struct NoticeRowsTests {
    private static let silent = "Silent; a click on it jumps to the session"

    @Test(arguments: [NoticeLeave?.none, .unasked, .provisional, .allowed(.banners), .allowed(.alerts)])
    func theSwitchSaysWhatANoticeIsAndTakesLeesChoiceWhileMacOSLetsIt(leave: NoticeLeave?) {
        #expect(SettingsRow.notify(leave, show: .notch) == SettingsRow(
            label: "Notify me of a new ask", line: Self.silent, side: .toggle(isEnabled: true)
        ))
    }

    @Test(arguments: [
        (NoticeLeave.denied, EdgeSettings.Show.notch, "the notch swells and lights"),
        (.allowed(.none), .strip, "the strip flashes"),
        (.denied, .nothing, "the menu bar's light comes on"),
    ])
    func whileMacOSStopsItTheSwitchGreysAndSaysWhatTellsLeeInstead(leave: NoticeLeave, show: EdgeSettings.Show, instead: String) {
        #expect(SettingsRow.notify(leave, show: show) == SettingsRow(
            label: "Notify me of a new ask", line: "Can't while macOS stops it; \(instead) instead",
            side: .toggle(isEnabled: false)
        ))
    }

    @Test func allowedItSaysHowAndTakesLeeToSitRepsPageInSystemSettings() {
        let settings = SettingsRow.Side.button("Notification Settings…", .notifications)

        #expect(SettingsRow.allowed(.allowed(.banners)) == SettingsRow(
            label: "Allowed by macOS", line: "As banners, in System Settings › Notifications", side: settings
        ))
        #expect(SettingsRow.allowed(.allowed(.alerts)).line == "As alerts, in System Settings › Notifications")
        #expect(SettingsRow.allowed(.provisional) == SettingsRow(
            label: "Allowed by macOS", line: "Quietly, in Notification Center", side: settings
        ))
    }

    @Test func stoppedItSaysWhatIsWrongWithTheButtonToTheFix() {
        let settings = SettingsRow.Side.button("Notification Settings…", .notifications)

        #expect(SettingsRow.allowed(.denied) == SettingsRow(
            label: "Not allowed by macOS", line: "Turn SitRep on in System Settings › Notifications", side: settings
        ))
        #expect(SettingsRow.allowed(.allowed(.none)) == SettingsRow(
            label: "Not shown by macOS", line: "Choose banners in System Settings › Notifications", side: settings
        ))
    }

    /// SitRep is not in System Settings' list until macOS has asked, so there is nothing there to open.
    @Test func beforeMacOSHasAskedTheSwitchAsksAndThereIsNoButton() {
        #expect(SettingsRow.allowed(.unasked) == SettingsRow(
            label: "Not asked by macOS yet", line: "macOS asks once Notify me of a new ask is on", side: .none
        ))
        #expect(SettingsRow.allowed(nil).side == .none)
    }
}

struct PluginRowTests {
    private static let windows = [
        Watched.window("w1", session: "sr-boot", name: "The bootstrap", project: "Kit", version: "0.1.0", needsReload: true),
        Watched.window("w2", session: "sr-diff", name: "Diff", project: "Mint", version: "0.2.0", needsReload: false),
        Watched.window("w3", session: "sr-plan", name: "Plan the tool", project: "Terrace", version: "0.1.0", needsReload: true),
    ]
    private static let clone = PluginStanding.running(.folder("~/Code/sitrep"), folder: "/Users/lee/Code/sitrep")
    private static let label = "Claude Code plugin"
    private static let line = "Puts each Claude Code session on the board"

    @Test func everyWindowOnThePluginIsUpToDateWithItsDotAndNoVersionNorCount() {
        let row = SettingsRow.plugin(heard([.line(Watched.line(windows: [Self.windows[1]]))]), plugin: Self.clone)

        #expect(row == SettingsRow(label: Self.label, line: Self.line, side: .fine("Up to date")))
    }

    @Test func windowsOnAnOlderPluginAreCountedWithTheirVersionAndListedToJumpTo() {
        let row = SettingsRow.plugin(heard([.line(Watched.line(windows: Self.windows))]), plugin: Self.clone)

        #expect(row.line == "Updated to 0.2.0. 2 windows run 0.1.0 until /reload-plugins")
        guard case let .windows(windows) = row.side else {
            Issue.record("Show Windows, not \(row.side)")
            return
        }
        #expect(windows.map(\.label) == ["Kit · The bootstrap", "Terrace · Plan the tool"])
        #expect(windows.map(\.session) == ["sr-boot", "sr-plan"])
    }

    @Test func oneWindowBehindIsSaidAsOneAndWindowsOnSeveralVersionsAsOlder() {
        let one = SettingsRow.plugin(heard([.line(Watched.line(windows: Array(Self.windows.prefix(2))))]), plugin: Self.clone)
        let unsaid = Watched.window("w4", session: "sr-ledger", name: "Usage", project: "Switchboard", version: nil, needsReload: true)
        let several = SettingsRow.plugin(heard([.line(Watched.line(windows: [Self.windows[0], unsaid]))]), plugin: Self.clone)

        #expect(one.line == "Updated to 0.2.0. 1 window runs 0.1.0 until /reload-plugins")
        #expect(several.line == "Updated to 0.2.0. 2 windows run an older version until /reload-plugins")
    }

    @Test func aStaleBoardSaysWhySitRepCantReadItAndListsNoWindowsNorADot() {
        let stale = heard([.line(Watched.line(windows: Self.windows)), .exited(.status(1), stderr: "")])

        #expect(SettingsRow.plugin(stale, plugin: Self.clone) == SettingsRow(
            label: Self.label, line: "SitRep can't read the board: sitrep watch ended with status 1.", side: .none
        ))
    }

    @Test func beforeAnyBoardItClaimsNothing() {
        #expect(SettingsRow.plugin(LastBoard(), plugin: Self.clone) == SettingsRow(label: Self.label, line: Self.line, side: .none))
    }

    @Test func whileSitRepLooksForThePluginItSaysSo() {
        #expect(SettingsRow.plugin(LastBoard(), plugin: nil).line == "Looking for Claude Code's sitrep plugin…")
    }

    /// SitRep looks again after trouble by itself: there is nothing for a button to do.
    @Test(arguments: [
        (PluginTrouble.noClaude, "SitRep can't find Claude Code. Install Claude Code, and SitRep will find it."),
        (.uncarried, "This SitRep carries no plugin. Build it with app/build."),
        (.unfound(.folder("~/Code/sitrep")), "SitRep can't find the sitrep plugin. Claude Code has it from ~/Code/sitrep, where SitRep can't read it."),
        (.unfound(.github("leeovery/sitrep")), "SitRep can't find the sitrep plugin. Claude Code has it from GitHub, leeovery/sitrep, where SitRep can't read it."),
        (.failed("Path does not exist: /nowhere"), "SitRep couldn't set up its plugin. Path does not exist: /nowhere"),
    ])
    func withTroubleItSaysWhatInTheMenusWordsWithNoDotEvenOverTheBoardItRunsMeanwhile(trouble: PluginTrouble, line: String) {
        let current = heard([.line(Watched.line(windows: [Self.windows[1]]))])
        let row = SettingsRow.plugin(current, plugin: .trouble(trouble, folder: "/Users/lee/Library/Application Support/sitrep"))

        #expect(row == SettingsRow(label: Self.label, line: line, side: .none))
        #expect(SettingsRow.plugin(LastBoard(), plugin: .trouble(trouble, folder: nil)).line == line)
    }
}

struct LoginRowTests {
    @Test func itIsTheSwitchOnceReadAndGreyBefore() {
        #expect(SettingsRow.login(LoginItem(.enabled)) == SettingsRow(label: "Open at login", line: nil, side: .toggle(isEnabled: true)))
        #expect(SettingsRow.login(LoginItem(.notRegistered)).side == .toggle(isEnabled: true))
        #expect(SettingsRow.login(nil).side == .toggle(isEnabled: false))
    }

    @Test func whileMacOSWaitsOnLeesApprovalTheButtonTakesHimToLoginItems() {
        #expect(SettingsRow.login(LoginItem(.requiresApproval)) == SettingsRow(
            label: "Open at login", line: "Waiting for your approval in System Settings › Login Items",
            side: .button("Login Items Settings…", .loginItems)
        ))
    }
}

struct GhosttyRowTests {
    private static let label = "Bring a session's Ghostty window to the front"

    @Test func allowedItIsADotAndAWordWithNothingToPress() {
        #expect(SettingsRow.ghostty(.allowed) == SettingsRow(
            label: Self.label, line: "So a click on a session jumps to it", side: .fine("Allowed")
        ))
    }

    @Test func notAllowedTheButtonGoesToAutomationInSystemSettings() {
        #expect(SettingsRow.ghostty(.denied) == SettingsRow(
            label: Self.label, line: "Not allowed, so a click on a session can't reach its window",
            side: .button("Open System Settings…", .automation)
        ))
    }

    /// SitRep isn't in Automation's list until macOS has asked, so Allow… brings up macOS's own prompt instead.
    @Test func beforeMacOSHasAskedAllowBringsUpItsPrompt() {
        #expect(SettingsRow.ghostty(.unasked).side == .button("Allow…", .allowGhostty))
    }

    @Test func whileMacOSCantSayOrBeforeItIsAskedThereIsNothingToPress() {
        #expect(SettingsRow.ghostty(.unknown) == SettingsRow(label: Self.label, line: "macOS says only while Ghostty runs", side: .none))
        #expect(SettingsRow.ghostty(nil).side == .none)
    }

    @Test(arguments: [(Int32(0), GhosttyLeave.allowed), (-1743, .denied), (-1744, .unasked), (-600, .unknown)])
    func macOSsAnswerReadsAsTheLeave(status: Int32, leave: GhosttyLeave) {
        #expect(GhosttyLeave(status) == leave)
    }
}

struct AppSettingsTests {
    /// Defaults of their own, gone after the test.
    private static func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "com.leeovery.sitrep.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!

        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    @Test func notificationsAreOffByDefault() {
        Self.withDefaults { defaults in
            #expect(!SavedSettings<AppSettings>(defaults).read().notifiesNewAsks)
        }
    }

    @Test func itIsSavedBesideTheEdgesUnderItsOwnKey() {
        Self.withDefaults { defaults in
            var settings = AppSettings()

            settings.notifiesNewAsks = true
            SavedSettings(defaults).save(settings)
            SavedEdgeSettings(defaults).save(EdgeSettings())

            #expect(SavedSettings<AppSettings>(defaults).read() == settings)
            #expect(defaults.data(forKey: "app") != nil)
            #expect(SavedEdgeSettings(defaults).read() == EdgeSettings())
        }
    }

    /// The separate Settings window saved the pane it last showed; that key is passed over.
    @Test func aValueSavedWithTheSettingsWindowsPaneStillReadsTheKeyIgnored() throws {
        try Self.withDefaults { defaults in
            defaults.set(Data(#"{"notifiesNewAsks":true,"pane":"general"}"#.utf8), forKey: "app")

            let read = SavedSettings<AppSettings>(defaults).read()
            let saved = try JSONEncoder().encode(read)
            let keys = try #require(try JSONSerialization.jsonObject(with: saved) as? [String: Any]).keys

            #expect(read.notifiesNewAsks)
            #expect(Set(keys) == ["notifiesNewAsks", "foldsAfter"])
        }
    }

    @Test func yourTurnFoldsAfterAnHourByDefault() {
        Self.withDefaults { defaults in
            #expect(SavedSettings<AppSettings>(defaults).read().foldsAfter == .hour)
        }
    }

    @Test(arguments: FoldPeriod.allCases)
    func theFoldPeriodIsSavedAndReadBack(period: FoldPeriod) {
        Self.withDefaults { defaults in
            var settings = AppSettings()

            settings.foldsAfter = period
            SavedSettings(defaults).save(settings)

            #expect(SavedSettings<AppSettings>(defaults).read().foldsAfter == period)
        }
    }

    /// A period another version saved that this one doesn't know is the default, and keeps what else it can.
    @Test func aFoldPeriodItDoesNotKnowIsTheDefault() {
        Self.withDefaults { defaults in
            defaults.set(Data(#"{"notifiesNewAsks":true,"foldsAfter":"week"}"#.utf8), forKey: "app")

            let read = SavedSettings<AppSettings>(defaults).read()

            #expect(read.foldsAfter == .hour)
            #expect(read.notifiesNewAsks)
        }
    }

    @Test func settingsNamesEachPeriod() {
        #expect(FoldPeriod.allCases.map(\.title) == ["An hour", "Four hours", "Today", "Never"])
    }

    @Test func aValueAnotherVersionSavedKeepsWhatItCan() {
        Self.withDefaults { defaults in
            defaults.set(Data(#"{"notifiesNewAsks":"yes","sound":1}"#.utf8), forKey: "app")

            #expect(SavedSettings<AppSettings>(defaults).read() == AppSettings())
        }
    }

    @Test func anythingButAnObjectIsTheDefaults() {
        Self.withDefaults { defaults in
            defaults.set(Data("[1]".utf8), forKey: "app")

            #expect(SavedSettings<AppSettings>(defaults).read() == AppSettings())
        }
    }
}
