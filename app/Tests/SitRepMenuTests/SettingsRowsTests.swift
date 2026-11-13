import Foundation
@testable import SitRepCore
@testable import SitRepEdge
import SitRepLines
@testable import SitRepMenu
import SitRepPanel
import SitRepRelay
import Testing

/// Edge's sections under the Show row's card: one named for the shape, holding the rows that tune it, then Motion.
struct EdgePaneTests {
    private static func sections(
        _ show: EdgeSettings.Show, length: StripLength = .grows, hasGlass: Bool = true
    ) -> [EdgePane.Section] {
        var settings = EdgeSettings()

        settings.show = show
        settings.length = length

        return EdgePane.sections(settings, hasGlass: hasGlass)
    }

    private static let motion = EdgePane.Section(name: "Motion", rows: [.reduceMotion])

    @Test func theNotchsSectionIsEdgeDisplayStyleAndMaterialThenMotion() {
        #expect(Self.sections(.notch) == [
            EdgePane.Section(name: "Notch", rows: [.edge, .display, .style, .material]), Self.motion,
        ])
    }

    @Test func theStripsSectionIsEdgeDisplayLengthMaxAndMaterialThenMotion() {
        #expect(Self.sections(.strip) == [
            EdgePane.Section(name: "Strip", rows: [.edge, .display, .length, .max, .material]), Self.motion,
        ])
    }

    @Test func maxIsForGrowsAlone() {
        #expect(Self.sections(.strip, length: .full).first?.rows == [.edge, .display, .length, .material])
        #expect(!Self.sections(.notch, length: .grows).contains { $0.rows.contains(.max) })
    }

    @Test func withNothingThereIsNoSectionAndOneLineSaysWhatCarriesTheBoard() {
        #expect(Self.sections(.nothing).isEmpty)
        #expect(EdgePane.menuCarries == "The menu carries the board.")
    }

    @Test func materialIsFromMacOS26AloneAndMotionStaysBeforeIt() {
        #expect(Self.sections(.notch, hasGlass: false).first?.rows == [.edge, .display, .style])
        #expect(Self.sections(.strip, hasGlass: false).last == Self.motion)
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

    /// With its pulse off, the notch lights for a new ask but doesn't swell, and the greyed line says so.
    @Test func whileMacOSStopsItTheNotchSwellsInsteadOnlyWhileItsPulseIsOn() {
        #expect(SettingsRow.notify(.denied, show: .notch, pulses: false).line
            == "Can't while macOS stops it; the notch lights instead")
        #expect(SettingsRow.notify(.denied, show: .notch, for: .turn, pulses: true).line
            == "Can't while macOS stops it; the notch swells and lights blue instead")
    }

    /// Lee's turn has its own switch, worded for it, greying as a new ask's does, saying what tells him instead.
    @Test(arguments: [
        (NoticeLeave?.some(.allowed(.banners)), EdgeSettings.Show.notch, nil),
        (.denied, .notch, "the notch lights blue"),
        (.allowed(.none), .strip, "its mark on the strip turns blue"),
        (.denied, .nothing, "the menu bar's light turns blue"),
    ])
    func leesTurnHasItsOwnSwitch(leave: NoticeLeave?, show: EdgeSettings.Show, instead: String?) {
        let line = instead.map { "Can't while macOS stops it; \($0) instead" } ?? Self.silent

        #expect(SettingsRow.notify(leave, show: show, for: .turn, pulses: false) == SettingsRow(
            label: "Notify me when it's my turn", line: line, side: .toggle(isEnabled: instead == nil)
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

    /// The windows are the rows of Needs /reload-plugins under it (`ClaudeCodePaneTests`), so the row has no control.
    @Test func windowsOnAnOlderPluginAreCountedWithTheirVersionWithNoControl() {
        let row = SettingsRow.plugin(heard([.line(Watched.line(windows: Self.windows))]), plugin: Self.clone)

        #expect(row == SettingsRow(
            label: Self.label, line: "Updated to 0.2.0. 2 windows run 0.1.0 until /reload-plugins", side: .none
        ))
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
        #expect(SettingsRow.login(LoginItem(.enabled)) == SettingsRow(
            label: "Open at login", line: "SitRep is only of use while it runs", side: .toggle(isEnabled: true)
        ))
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
    @Test func notificationsAreOffByDefault() {
        let defaults = MemoryDefaults()

        #expect(!SavedSettings<AppSettings>(defaults).read().notifiesNewAsks)
    }

    @Test func itIsSavedBesideTheEdgesUnderItsOwnKey() {
        let defaults = MemoryDefaults()
        var settings = AppSettings()

        settings.notifiesNewAsks = true
        SavedSettings(defaults).save(settings)
        SavedEdgeSettings(defaults).save(EdgeSettings())

        #expect(SavedSettings<AppSettings>(defaults).read() == settings)
        #expect(Set(defaults.dictionaryRepresentation().keys) == ["app", SavedEdgeSettings.key])
        #expect(SavedEdgeSettings(defaults).read() == EdgeSettings())
    }

    /// The separate Settings window of round 5 saved the pane it last showed here; that key is passed over, as the
    /// pane is saved on its own now (`SettingsWindowSettings`).
    @Test func aValueSavedWithTheSettingsWindowsPaneStillReadsTheKeyIgnored() throws {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"notifiesNewAsks":true,"pane":"general"}"#.utf8), forKey: "app")

        let read = SavedSettings<AppSettings>(defaults).read()
        let saved = try JSONEncoder().encode(read)
        let keys = try #require(try JSONSerialization.jsonObject(with: saved) as? [String: Any]).keys

        #expect(read.notifiesNewAsks)
        #expect(read.playsSound)
        #expect(read.sound == "Glass")
        #expect(Set(keys) == [
            "notifiesNewAsks", "playsSound", "sound", "pulsesNewAsks", "notifiesTurns", "playsTurnSound", "turnSound",
            "pulsesTurns", "terminal",
        ], "a resume command never set saved as none")
    }

    /// A value saved before Lee's turn had settings of its own (13 November 2026) reads as it did: its keys a new
    /// ask's, the notch pulsing for one as it always had, and his turn's all off.
    @Test func aValueSavedBeforeLeesTurnHadItsOwnReadsAsBefore() {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"notifiesNewAsks":true,"playsSound":false,"sound":"Submarine"}"#.utf8), forKey: "app")

        let read = SavedSettings<AppSettings>(defaults).read()

        #expect(read.notifies(.ask) && !read.playsSound && read.sound(for: .ask) == "Submarine")
        #expect(read.pulses == [.ask])
        #expect(!read.notifies(.turn) && !read.playsTurnSound && !read.pulsesTurns)
    }

    /// Lee's turn's settings, off by default, its sound Tink, apart from a new ask's Glass; each saved under a key of
    /// its own and read back, leaving the ask's as they were.
    @Test func leesTurnsSettingsAreItsOwnOffByDefaultSavedAndReadBack() {
        let defaults = MemoryDefaults()
        var settings = AppSettings()

        #expect(!settings.notifiesTurns && !settings.playsTurnSound && !settings.pulsesTurns)
        #expect(settings.sound(for: .turn) == "Tink" && settings.sound(for: .ask) == "Glass")

        settings.notifiesTurns = true
        settings.playsTurnSound = true
        settings.turnSound = "Pop"
        settings.pulsesTurns = true
        settings.pulsesNewAsks = false
        SavedSettings(defaults).save(settings)

        let read = SavedSettings<AppSettings>(defaults).read()

        #expect(read == settings)
        #expect(read.pulses == [.turn])
        #expect(!read.notifiesNewAsks && read.playsSound && read.sound == "Glass")
    }

    /// As each window played Glass before SitRep played the sound.
    @Test func aNewAskPlaysGlassByDefault() {
        let read = SavedSettings<AppSettings>(MemoryDefaults()).read()

        #expect(read.playsSound)
        #expect(read.sound == "Glass")
    }

    @Test func theSoundAndItsSwitchAreSavedAndReadBack() {
        let defaults = MemoryDefaults()
        var settings = AppSettings()

        settings.playsSound = false
        settings.sound = "Tink"
        SavedSettings(defaults).save(settings)

        let read = SavedSettings<AppSettings>(defaults).read()

        #expect(!read.playsSound)
        #expect(read.sound == "Tink")
    }

    /// Ghostty, by default and from a value saved before it.
    @Test func theTerminalIsGhosttyByDefault() {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"notifiesNewAsks":true}"#.utf8), forKey: "app")
        #expect(SavedSettings<AppSettings>(defaults).read().terminal == "ghostty")
    }

    /// Unset until Lee gives one, which reads as the default; his own saved under its key, `resume`, and read back, empty
    /// where he cleared it.
    @Test(arguments: ["portal open --claude {claude}", ""])
    func theResumeCommandIsUnsetByDefaultAndLeesIsSavedUnderItsOwnKeyAndReadBack(lees: String) throws {
        let defaults = MemoryDefaults()
        var settings = AppSettings()

        #expect(SavedSettings<AppSettings>(defaults).read().resumeCommand == nil)

        settings.resumeCommand = lees
        SavedSettings(defaults).save(settings)

        let data = try #require(defaults.data(forKey: "app"))
        let saved = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(saved["resume"] as? String == lees)
        #expect(saved["resumeCommand"] == nil)
        #expect(SavedSettings<AppSettings>(defaults).read().resumeCommand == lees)
    }

    /// Settings saved every field, so a resume command saved before it had a key of its own was saved empty where Lee
    /// never gave one: read where it holds a command, unset where it is empty, and saved under the new key from then.
    @Test(arguments: [
        (#"{"resumeCommand":"portal open -p {dir} -- claude --resume {claude}"}"#, "portal open -p {dir} -- claude --resume {claude}"),
        (#"{"resumeCommand":""}"#, nil),
        (#"{"resumeCommand":"","resume":""}"#, ""),
        (#"{"resumeCommand":"old {claude}","resume":"new {claude}"}"#, "new {claude}"),
    ] as [(String, String?)])
    func aResumeCommandSavedBeforeItsOwnKeyIsReadOnlyWhereItHoldsOne(saved: String, read: String?) throws {
        let defaults = MemoryDefaults()

        defaults.set(Data(saved.utf8), forKey: "app")

        let settings = SavedSettings<AppSettings>(defaults).read()

        #expect(settings.resumeCommand == read)
        SavedSettings(defaults).save(settings)
        #expect(!String(decoding: try #require(defaults.data(forKey: "app")), as: UTF8.self).contains("resumeCommand"))
        #expect(SavedSettings<AppSettings>(defaults).read().resumeCommand == read)
    }

    /// The open command, retired with stage 8's rethink (13 November 2026): a value saved with it reads what else it
    /// holds, and the next save leaves it out.
    @Test func aRetiredOpenCommandIsReadAndIgnored() throws {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"sound":"Tink","openCommand":"portal open -s {session}"}"#.utf8), forKey: "app")

        let read = SavedSettings<AppSettings>(defaults).read()

        #expect(read.sound == "Tink")
        SavedSettings(defaults).save(read)
        let saved = try #require(defaults.data(forKey: "app"))
        #expect(!String(decoding: saved, as: UTF8.self).contains("openCommand"))
    }

    /// "Your turn folds after", retired on 4 November 2026: a value saved with it reads what else it holds, and the next
    /// save leaves it out.
    @Test func aRetiredFoldPeriodIsReadAndIgnored() throws {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"notifiesNewAsks":true,"sound":"Tink","foldsAfter":"fourHours"}"#.utf8), forKey: "app")

        let read = SavedSettings<AppSettings>(defaults).read()

        #expect(read.notifiesNewAsks && read.sound == "Tink")
        SavedSettings(defaults).save(read)
        let saved = try #require(defaults.data(forKey: "app"))
        #expect(!String(decoding: saved, as: UTF8.self).contains("foldsAfter"))
    }

    @Test func aValueAnotherVersionSavedKeepsWhatItCan() {
        let defaults = MemoryDefaults()

        defaults.set(Data(#"{"notifiesNewAsks":"yes","sound":1}"#.utf8), forKey: "app")

        #expect(SavedSettings<AppSettings>(defaults).read() == AppSettings())
    }

    @Test func anythingButAnObjectIsTheDefaults() {
        let defaults = MemoryDefaults()

        defaults.set(Data("[1]".utf8), forKey: "app")

        #expect(SavedSettings<AppSettings>(defaults).read() == AppSettings())
    }
}
