import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepMenu
import SitRepPanel
import Testing

struct EdgePaneTests {
    private static func pane(_ show: EdgeSettings.Show, length: StripLength = .grows, hasGlass: Bool = true) -> EdgePane {
        var settings = EdgeSettings()

        settings.show = show
        settings.length = length

        return EdgePane(settings, hasGlass: hasGlass)
    }

    @Test func theNotchShowsWhereTheNotchAndLookButNotTheStrip() {
        let pane = Self.pane(.notch)

        #expect(pane.showsWhere && pane.showsNotch && pane.showsLook && pane.showsMaterial)
        #expect(!pane.showsStrip && !pane.showsMax && !pane.saysMenuCarries)
    }

    @Test func theStripShowsWhereTheStripAndLookButNotTheNotch() {
        let pane = Self.pane(.strip)

        #expect(pane.showsWhere && pane.showsStrip && pane.showsLook)
        #expect(!pane.showsNotch && !pane.saysMenuCarries)
    }

    @Test func maxIsForGrowsAlone() {
        #expect(Self.pane(.strip, length: .grows).showsMax)
        #expect(!Self.pane(.strip, length: .full).showsMax)
        #expect(!Self.pane(.notch, length: .grows).showsMax)
    }

    @Test func withNothingEverySectionGoesAndOneLineSaysWhatCarriesTheBoard() {
        let pane = Self.pane(.nothing)

        #expect(!pane.showsWhere && !pane.showsNotch && !pane.showsStrip && !pane.showsMax && !pane.showsLook)
        #expect(pane.saysMenuCarries)
        #expect(EdgePane.menuCarries == "The menu and the SitRep window carry the board.")
    }

    @Test func materialIsFromMacOS26AloneAndReduceMotionStaysBeforeIt() {
        let pane = Self.pane(.notch, hasGlass: false)

        #expect(pane.showsLook)
        #expect(!pane.showsMaterial)
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

struct NotificationsPaneTests {
    @Test(arguments: [
        (EdgeSettings.Show.notch, "Off, the notch swells and lights instead"),
        (.strip, "Off, the strip flashes instead"),
        (.nothing, "Off, the menu bar's light comes on instead"),
    ])
    func offTheSwitchSaysWhatTellsLeeInstead(show: EdgeSettings.Show, line: String) {
        #expect(NotificationsPane.switchLine(isOn: false, show: show) == line)
    }

    @Test func onItSaysTheEdgeStillTells() {
        #expect(NotificationsPane.switchLine(isOn: true, show: .notch) == "On, and the notch swells and lights as well")
    }

    @Test func macOSsAnswerIsInPlainWords() {
        #expect(NoticeLeave.allowed(.banners).words == "Allowed, as banners")
        #expect(NoticeLeave.allowed(.alerts).words == "Allowed, as alerts")
        #expect(NoticeLeave.denied.words == "Not allowed")
        #expect(NoticeLeave.unasked.words == "Not asked yet: macOS asks once the switch is on")
    }
}

struct PluginCardTests {
    private static let windows = [
        Watched.window("w1", session: "sr-boot", name: "The bootstrap", project: "Kit", version: "0.1.0", needsReload: true),
        Watched.window("w2", session: "sr-diff", name: "Diff", project: "Mint", version: "0.2.0", needsReload: false),
    ]

    @Test func itNamesThePluginsVersionAndTheWindowsRunningItAllCurrent() {
        let card = PluginCard(heard([.line(Watched.line(windows: [Self.windows[1], Self.windows[1]]))]), folder: "~/Code/sitrep")

        #expect(card.title == "sitrep 0.2.0 for Claude Code")
        #expect(card.line == "From ~/Code/sitrep · 2 windows, all on 0.2.0")
        #expect(card.isCurrent)
        #expect(card.reloads.isEmpty)
    }

    @Test func oneWindowIsSaidAsOne() {
        let card = PluginCard(heard([.line(Watched.line(windows: [Self.windows[1]]))]), folder: "~/Code/sitrep")

        #expect(card.line == "From ~/Code/sitrep · 1 window, on 0.2.0")
    }

    @Test func windowsOnAnOldSitrepAreCountedAndListedAsTheMenuListsThem() {
        let card = PluginCard(heard([.line(Watched.line(windows: Self.windows))]), folder: "~/Code/sitrep")

        #expect(card.line == "From ~/Code/sitrep · 2 windows, 1 needs /reload-plugins")
        #expect(card.reloads.map(\.label) == ["Kit · The bootstrap"])
        #expect(!card.isCurrent)
    }

    @Test func aStaleBoardSaysSoAndWhenNotItsWindowsNorCurrent() {
        let stale = heard([.line(Watched.line(windows: [Self.windows[1]])), .exited(.status(1), stderr: "")])
        let card = PluginCard(stale, folder: "~/Code/sitrep", clock: london)

        #expect(card.line == "From ~/Code/sitrep · SitRep can't read the board · as of 12:01")
        #expect(!card.isCurrent)
        #expect(card.reloads.isEmpty)
        #expect(card.title == "sitrep 0.2.0 for Claude Code")
    }

    @Test func withNoWindowItSaysSo() {
        #expect(PluginCard(heard([.line(Watched.line())]), folder: "~/Code/sitrep").line == "From ~/Code/sitrep · no window runs it")
    }

    @Test func beforeAnyBoardItIsLookingAndClaimsNothingCurrent() {
        let card = PluginCard(LastBoard(), folder: "~/Code/sitrep")

        #expect(card.title == "sitrep for Claude Code")
        #expect(card.line == "From ~/Code/sitrep · looking for the windows running it…")
        #expect(!card.isCurrent)
    }

    @Test func withNoPluginToRunItSaysWhy() {
        #expect(PluginCard(unrun: "No plugin.").line == "No plugin.")
    }
}

struct GhosttyLeaveTests {
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

    @Test func notificationsAreOffByDefaultAndSettingsOpensOnTheEdge() {
        Self.withDefaults { defaults in
            let settings = SavedSettings<AppSettings>(defaults).read()

            #expect(!settings.notifiesNewAsks)
            #expect(settings.pane == .edge)
        }
    }

    @Test func itIsSavedBesideTheEdgesUnderItsOwnKey() {
        Self.withDefaults { defaults in
            var settings = AppSettings()

            settings.notifiesNewAsks = true
            settings.pane = .general
            SavedSettings(defaults).save(settings)
            SavedEdgeSettings(defaults).save(EdgeSettings())

            #expect(SavedSettings<AppSettings>(defaults).read() == settings)
            #expect(defaults.data(forKey: "app") != nil)
            #expect(SavedEdgeSettings(defaults).read() == EdgeSettings())
        }
    }

    @Test func aValueAnotherVersionSavedKeepsWhatItCan() {
        Self.withDefaults { defaults in
            defaults.set(Data(#"{"notifiesNewAsks":true,"pane":"feel","sound":1}"#.utf8), forKey: "app")

            let read = SavedSettings<AppSettings>(defaults).read()

            #expect(read.notifiesNewAsks)
            #expect(read.pane == .edge)
        }
    }

    @Test func anythingButAnObjectIsTheDefaults() {
        Self.withDefaults { defaults in
            defaults.set(Data("[1]".utf8), forKey: "app")

            #expect(SavedSettings<AppSettings>(defaults).read() == AppSettings())
        }
    }
}
