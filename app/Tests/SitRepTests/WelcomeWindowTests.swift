import AppKit
import ServiceManagement
@testable import SitRep
import SitRepCore
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepPanel
import SwiftUI
import Testing

/// The welcome window, made, never shown, over a Mac of its own: nothing is registered with macOS, copied or played.
@MainActor
struct WelcomeWindowTests {
    /// What the welcome asked of the Mac, and the login item as macOS would say it.
    @MainActor
    final class Mac {
        var login = LoginItem(.notRegistered)
        var registers = 0
        var unregisters = 0
        var played: [String] = []
        var stops = 0
        var copies: [String] = []
        var opened: [Leaves.Place] = []

        /// Choosing the login item flips it, as `Leaves.chooseLogin` does; waiting on Lee's approval, it opens Login
        /// Items and changes nothing.
        func services() -> SettingsServices {
            SettingsServices(
                displays: { [] }, hasGlass: true, jump: { _ in }, sendTest: {}, copy: { self.copies.append($0) },
                sounds: AlertSounds(
                    names: AlertSounds.live.names, play: { self.played.append($0) }, stop: { self.stops += 1 }
                ),
                noticeLeave: { nil }, askForNotices: {},
                login: { self.login },
                chooseLogin: { self.choose() },
                ghostty: { .unknown }, allowGhostty: { .unknown }, open: { self.opened.append($0) }
            )
        }

        private func choose() {
            switch login.choice {
            case .register:
                registers += 1
                login = LoginItem(.enabled)
            case .unregister:
                unregisters += 1
                login = LoginItem(.notRegistered)
            case .openSettings:
                opened.append(.loginItems)
            }
        }
    }

    /// The welcome, its window's frame a recorded one, which never orders front.
    @MainActor
    private struct Made {
        let mac = Mac()
        let preferences: Preferences
        let welcome: WelcomeModel
        let window: WelcomeWindow
        let recorded = RecordedWindow.made()

        init(welcomed: Bool = false, plugin: PluginStanding? = nil) {
            let live = LiveBoard()

            live.plugin = plugin
            preferences = Preferences(MemoryDefaults())
            preferences.welcomed = welcomed
            welcome = WelcomeModel(preferences: preferences, live: live, services: mac.services())
            let recorded = recorded
            window = WelcomeWindow(welcome: welcome) { content in
                recorded.contentViewController = content
                return recorded
            }
            window.show()
        }

        /// The welcome at this step, from its first.
        func at(_ step: WelcomeStep) {
            while welcome.step != step {
                welcome.goOn()
            }
        }

        /// The window closed once more, after it opened again: AppKit tells a window's delegate of its close only once
        /// until it orders in again, which the recorded window never does, so this tells the delegate as AppKit would.
        func closeAgain() {
            window.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: recorded))
        }

        /// What the window shows, laid out once SwiftUI has heard what changed.
        func settled() async -> NSView {
            await Task.yield()
            await Task.yield()
            recorded.contentView?.layoutSubtreeIfNeeded()
            return recorded.contentView ?? NSView()
        }
    }

    // MARK: The window

    @Test func itIs840By540NeverResizedAndBlack() {
        let window = Made().recorded

        #expect(window.contentRect(forFrameRect: window.frame).size == CGSize(width: 840, height: 540))
        #expect(window.styleMask == [.titled, .closable, .fullSizeContentView])
        #expect(window.titlebarAppearsTransparent && window.titleVisibility == .hidden)
        #expect(window.backgroundColor == .black)
        #expect(!window.isReleasedWhenClosed)
    }

    @Test func itClosesByItsButtonAndCommandWButNeitherMinimisesNorZooms() {
        let window = Made().recorded

        #expect(window.validateMenuItem(NSMenuItem(title: "", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "")))
        #expect(!window.validateMenuItem(NSMenuItem(title: "", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "")))
        #expect(window.standardWindowButton(.zoomButton)?.isEnabled != true)
    }

    /// Opened again, the same window comes forward on the Space Lee is on, as About SitRep does.
    @Test func itIsOneWindowBroughtForwardEachTimeItOpens() {
        let made = Made()

        made.window.show()
        #expect(made.recorded.steps == [
            .orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true),
            .orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true),
        ])
    }

    /// The menu's Welcome… opens it at its first step, wherever it was left.
    @Test func itOpensAtItsFirstStep() {
        let made = Made()

        made.at(.sound)
        made.window.show()
        #expect(made.welcome.step == .hello)
    }

    // MARK: The footer

    /// The footer as drawn: at the first step, Skip setup between the dashes and Continue, which reads Show me; at the
    /// last, nothing between them, and Done, a narrower pill, against the window's right, 16 in.
    @Test func atTheLastStepContinueReadsDoneAndSkipSetupGoes() throws {
        let made = Made()
        let first = try Self.footer(made)

        made.at(.ready)

        let last = try Self.footer(made)
        let between = { (spans: [ClosedRange<CGFloat>]) in spans.filter { $0.lowerBound > 200 }.dropLast() }
        let pills = try [first, last].map { try #require($0.last) }

        #expect(!between(first).isEmpty)
        #expect(between(last).isEmpty)
        #expect(pills.allSatisfy { abs($0.upperBound - 824) <= 0.5 })
        #expect(Self.width(pills[1]) < Self.width(pills[0]))
    }

    /// The first dash long, the rest short, 5 apart.
    @Test func atTheFirstStepTheFirstDashIsLong() throws {
        let made = Made()
        let dashes = try Self.footer(made).filter { $0.lowerBound > 60 && $0.upperBound < 200 }

        #expect(dashes.count == 4)
        #expect(zip(dashes.map(Self.width), [22.0, 10, 10, 10]).allSatisfy { abs($0 - $1) <= 0.5 })
    }

    @Test func continueGoesOnAndDoneClosesTheWindow() {
        let made = Made()
        var closes = 0

        made.welcome.closeWindow = { closes += 1 }
        made.welcome.goOn()
        #expect(made.welcome.step == .edge)
        made.at(.ready)
        made.welcome.goOn()
        #expect(closes == 1)
    }

    // MARK: Your edge

    /// Each press sets the setting itself, so the stage and the real edge move at once.
    @Test func aTileSetsTheRealSettingAndTheStageMoves() {
        let made = Made()

        made.at(.edge)
        made.welcome.choose(.strip)
        made.window.stage.step(at: Displays.now)
        #expect(made.preferences.edge.show == .strip)
        #expect(made.window.stage.surface is StripSurface)
    }

    @Test func aSegmentSetsTheRealSetting() async throws {
        let made = Made()

        made.at(.edge)

        let edge = try #require(Self.segments(in: await made.settled()).first { $0.label(forSegment: 0) == "Left" })

        edge.selectedSegment = 1
        edge.sendAction(edge.action, to: edge.target)
        #expect(made.preferences.edge.edge == .right)
    }

    /// One row for another in its place: Material and Edge stay where they were.
    @Test func atStripLengthTakesStylesPlaceAtTheSameHeight() async throws {
        let made = Made()

        made.at(.edge)

        let before = Self.rows(in: await made.settled())

        made.preferences.edit { $0.show = .strip }

        let after = Self.rows(in: await made.settled())

        #expect(before.keys.contains("Meniscus") && !before.keys.contains("Grows"))
        #expect(after["Grows"] == before["Meniscus"])
        #expect(after["Black"] == before["Black"] && after["Left"] == before["Left"])
    }

    // MARK: Its sound, and its start

    @Test func arrivingAtTheSoundsPlaysNothing() {
        let made = Made()

        made.at(.sound)
        #expect(made.mac.played.isEmpty)
    }

    /// Chosen, played once through the seam, and the stage's notch swelling with it.
    @Test func aSoundsClickChoosesItAndPlaysItOnce() {
        let made = Made()

        made.at(.sound)
        made.welcome.choose(sound: "Pop")
        #expect(made.mac.played == ["Pop"])
        #expect(made.preferences.app.sound == "Pop" && made.preferences.app.playsSound)
        #expect(made.welcome.sound == "Pop")
        #expect(made.welcome.chimes == 1)
    }

    /// Followers hear one change, Play a sound and the sound together, never a half-made one.
    @Test func aSoundsClickIsOneChangeToTheSettings() {
        let made = Made()
        var changes: [AppSettings] = []

        made.preferences.follow { changes.append($0) }
        made.at(.sound)
        made.welcome.choose(sound: nil)
        made.welcome.choose(sound: "Pop")
        #expect(changes.map(\.playsSound) == [false, true])
        #expect(changes.last?.sound == "Pop")
    }

    @Test func noSoundTurnsOffPlayingOne() {
        let made = Made()

        made.at(.sound)
        made.welcome.choose(sound: nil)
        #expect(!made.preferences.app.playsSound)
        #expect(made.mac.played.isEmpty)
        #expect(made.welcome.sound == nil)
        #expect(made.welcome.chimes == 1)
    }

    /// The close button or ⌘W: the window's own close stops the welcome's sound, registers SitRep where the first
    /// welcome had yet to, and marks the welcome done.
    @Test func theWindowsCloseStopsItsSoundRegistersAndIsDone() {
        let made = Made()

        made.recorded.performClose(nil)
        #expect(made.mac.stops == 1)
        #expect(made.mac.registers == 1 && made.welcome.login.isOn)
        #expect(made.preferences.welcomed)
        #expect(!made.welcome.isVisiting)
    }

    @Test func skipSetupClosesTheWindowAsItsCloseButtonDoes() {
        let made = Made()

        made.welcome.skip()
        #expect(made.mac.stops == 1 && made.mac.registers == 1)
        #expect(made.preferences.welcomed)
    }

    /// SitRep quitting tells the window nothing, so a welcome showing is closed as its close button would close it.
    @Test func quittingClosesAWelcomeShowingAsItsCloseButtonWould() {
        let made = Made()

        made.window.closeIfOpen()
        #expect(made.mac.registers == 1 && made.preferences.welcomed)
    }

    /// Never shown, there is no window to make only to close it, and nothing to do.
    @Test func quittingMakesNoWindowForAWelcomeNeverShown() {
        let mac = Mac(), preferences = Preferences(MemoryDefaults())
        var made = 0
        let window = WelcomeWindow(
            welcome: WelcomeModel(preferences: preferences, live: LiveBoard(), services: mac.services())
        ) { content in
            made += 1
            return RecordedWindow.made()
        }

        window.closeIfOpen()
        #expect(made == 0)
        #expect(mac.registers == 0 && !preferences.welcomed)
    }

    /// In the first welcome, SitRep is registered as Lee arrives, so macOS's notice comes as the stage shows it.
    @Test func theFirstWelcomeRegistersSitRepAsLeeArrivesAtTheSwitch() {
        let made = Made()

        made.at(.edge)
        #expect(made.mac.registers == 0)
        made.at(.sound)
        #expect(made.mac.registers == 1 && made.welcome.login.isOn)
        #expect(made.welcome.announcesNotice)
        made.recorded.close()
        #expect(made.mac.registers == 1)
    }

    /// Opened again while it shows, it goes back to its first step and keeps what the visit did: Lee's switch off
    /// stays off, arriving at it again and as the window closes.
    @Test func openingItWhileItShowsKeepsTheVisit() {
        let made = Made()

        made.at(.sound)
        made.welcome.setLogin(false)
        made.window.show()
        #expect(made.welcome.step == .hello)
        made.at(.sound)
        made.recorded.close()
        #expect(made.mac.registers == 1 && made.mac.unregisters == 1)
        #expect(!made.welcome.login.isOn)
    }

    /// A visit begins afresh once the window has closed: the welcome is done, so the next changes nothing.
    @Test func openingItAfterItClosedBeginsAVisitOfItsOwn() {
        let made = Made()

        made.recorded.close()
        made.welcome.setLogin(false)
        made.window.show()
        made.at(.sound)
        made.closeAgain()
        #expect(made.mac.registers == 1 && !made.welcome.login.isOn)
        #expect(!made.welcome.isVisiting)
    }

    /// So a later Welcome… never undoes Lee's choice in General, and shows no notice for an item on for months.
    @Test func aWelcomeOpenedAgainChangesNothingUntilPressed() {
        let made = Made(welcomed: true)

        made.mac.login = LoginItem(.enabled)
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        made.at(.sound)
        #expect(!made.welcome.announcesNotice)
        made.recorded.close()
        #expect(made.mac.registers == 0 && made.mac.unregisters == 0)
    }

    /// Turned on in Settings › General during the first steps, it is read afresh as Lee arrives: never flipped off.
    @Test func arrivingReadsTheLoginItemAfreshAndNeverUnregisters() {
        let made = Made()

        made.mac.login = LoginItem(.enabled)
        made.at(.sound)
        made.recorded.close()
        #expect(made.mac.registers == 0 && made.mac.unregisters == 0)
        #expect(made.welcome.login.isOn)
    }

    /// While macOS waits on Lee's approval, arriving registers nothing and the row is General's.
    @Test func arrivingWhileMacOSWaitsOnApprovalChangesNothing() {
        let made = Made()

        made.mac.login = LoginItem(.requiresApproval)
        made.at(.sound)
        #expect(made.mac.registers == 0 && made.mac.opened.isEmpty)
        #expect(made.welcome.loginRow.side == .button("Login Items Settings…", .loginItems))
    }

    /// Approved in System Settings, the row is read again as the window comes forward.
    @Test func comingForwardReadsTheLoginItemAgain() {
        let made = Made()

        made.mac.login = LoginItem(.requiresApproval)
        made.at(.sound)
        made.mac.login = LoginItem(.enabled)
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        #expect(made.welcome.login.isOn)
    }

    /// The switch is the real login item, as General's is: on as Lee arrives in the first welcome, and a press
    /// unregisters it at once, which closing then leaves.
    @Test func theSwitchIsTheRealLoginItem() async throws {
        let made = Made()

        made.at(.sound)

        let toggle = try #require(Self.views(NSSwitch.self, in: await made.settled()).first)

        #expect(toggle.state == .on)
        toggle.state = .off
        toggle.sendAction(toggle.action, to: toggle.target)
        #expect(!made.welcome.login.isOn)
        made.recorded.close()
        #expect(!made.welcome.login.isOn && made.mac.registers == 1)
    }

    // MARK: Ready

    @Test func copyPutsReloadPluginsOnThePasteboard() {
        let made = Made()

        made.at(.ready)
        made.welcome.copyReloadCommand()
        #expect(made.mac.copies == ["/reload-plugins"])
    }

    /// In Settings' words for the plugin's row, in place of the command.
    @Test func whereThePluginFailedItSaysWhatFailedInPlaceOfTheCommand() {
        let standing = PluginStanding.trouble(.noClaude, folder: nil)

        #expect(Made(plugin: standing).welcome.reload == .trouble(.plugin(LastBoard(), plugin: standing)))
        #expect(Made().welcome.reload == .command("/reload-plugins"))
    }

    @Test func thePlaybackReadsTheRealSettings() {
        let made = Made()

        made.preferences.edit { $0.style = .card; $0.edge = .right }
        made.at(.ready)
        #expect(made.welcome.playback.map(\.words) == ["Card notch, right", "Glass", "Opens SitRep", "Opens Ghostty"])
    }

    @Test func atLoginOffHasAFixThatTurnsItOn() {
        let made = Made(welcomed: true)

        made.at(.ready)
        #expect(made.welcome.playback[2].fix == .turnOnLogin)
        made.welcome.fix(.turnOnLogin)
        #expect(made.welcome.login.isOn)
        #expect(made.welcome.playback[2].fix == nil)
    }

    // MARK: The stage

    /// SitRep's own edge, never a picture: the notch's surface drawing it, or the strip's, as Lee chose.
    @Test func theStageHostsTheEdgesRealViews() async throws {
        let made = Made()
        let stage = made.window.stage
        let view = await made.settled()

        #expect(stage.isDescendant(of: view))
        #expect((stage.surface as? NotchSurface)?.drawing is NotchView)
        made.preferences.edit { $0.show = .strip }
        stage.step(at: Displays.now)
        #expect((stage.surface as? StripSurface)?.drawing is StripView)
    }

    @available(macOS 26, *)
    @Test func theStagesEdgeTakesTheMaterialLeeChose() {
        let made = Made()
        let stage = made.window.stage

        made.preferences.edit { $0.material = .glass }
        stage.step(at: Displays.now)
        #expect((stage.surface as? NotchSurface)?.drawing is NotchGlassView)
        made.preferences.edit { $0.show = .strip }
        stage.step(at: Displays.now)
        #expect((stage.surface as? StripSurface)?.drawing is StripGlassView)
    }

    /// The stage's screen: the notch's window against its left, or its right.
    @Test func theStageFollowsTheEdgeLeeChose() {
        let made = Made()
        let stage = made.window.stage
        let screen = stage.edge.frame

        #expect(stage.surface.frame.minX == 0)
        made.preferences.edit { $0.edge = .right }
        stage.step(at: Displays.now)
        #expect(stage.surface.frame.maxX == screen.maxX)
    }

    /// Step 1's open panel at 0.7, so it sits on the stage as on a screen; the notch alone at its real size after it,
    /// its home where Paper's boards put it.
    @Test func stepOnePlaysTheEdgeAtSevenTenthsAndTheRestAtItsRealSize() async {
        let made = Made()
        let stage = made.window.stage
        let size = WelcomeStyle.stage

        _ = await made.settled()
        #expect(StageEdge.loopScale == 0.7 && StageEdge.stillScale == 1)
        #expect(stage.scale == StageEdge.loopScale)
        #expect(stage.edge.frame.size == CGSize(width: size.width / 0.7, height: size.height / 0.7))
        #expect(abs(stage.edge.stage.notchY * stage.scale - StageEdge.loopNotchY) < 1e-9)
        for step in [WelcomeStep.edge, .sound, .ready] {
            made.at(step)
            _ = await made.settled()
            #expect(stage.scale == StageEdge.stillScale, "\(step)")
            #expect(stage.edge.frame.size == size, "\(step)")
            #expect(abs(stage.edge.stage.notchY - StageEdge.stillNotchY) < 1e-9, "\(step)")
        }
    }

    /// Each sound chosen, the stage's notch swells, as for an ask that lands: once settled, and again.
    @Test func theStagesNotchSwellsWithEachSoundChosen() async {
        let made = Made()
        let stage = made.window.stage
        var clock = Displays.now

        made.at(.sound)
        _ = await made.settled()
        #expect(stage.play == .chime)
        for sound in ["Pop", "Tink"] {
            clock = Self.settle(stage, from: max(clock, Displays.now))
            #expect(stage.lastPace != .moving, "\(sound)")
            made.welcome.choose(sound: sound)
            _ = await made.settled()
            #expect(stage.lastPace == .moving, "\(sound)")
        }
    }

    /// Frames draw only while the window is in front, the link paused behind it and gone once it closes; the next
    /// time it comes forward, frames run again.
    @Test func theStagesFramesStopWhileTheWindowIsBehind() async {
        let made = Made()
        let stage = made.window.stage

        made.at(.edge)
        _ = await made.settled()
        #expect(!stage.isDrawing)
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        #expect(stage.isRunning && stage.isDrawing)
        made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        #expect(!stage.isRunning && !stage.isDrawing)
        made.recorded.close()
        made.window.show()
        stage.play = .chime
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        stage.chime(1)
        #expect(stage.isDrawing)
        made.closeAgain()
        #expect(!stage.isDrawing)
    }

    /// A change Lee makes in Settings while the welcome is behind is drawn at once, the callout moving with the notch.
    @Test func aSettingsChangeIsDrawnWhileTheWindowIsBehind() async {
        let made = Made()
        let stage = made.window.stage

        made.at(.ready)
        _ = await made.settled()
        #expect(!stage.callout.place.isRight)
        made.preferences.edit { $0.edge = .right }
        await Task.yield()
        await Task.yield()
        #expect(!stage.isDrawing)
        #expect(stage.callout.place.isRight)
        #expect(stage.surface.frame.maxX == stage.edge.frame.maxX)
    }

    @Test func eachStepTellsTheStageWhatToPlay() async {
        let made = Made()

        _ = await made.settled()
        #expect(made.window.stage.play == .loop)
        made.at(.edge)
        _ = await made.settled()
        #expect(made.window.stage.play == .lit)
    }

    // MARK: Helpers

    /// The stage stepped a 60th at a time, behind, from this time, until nothing moves or ten seconds pass: when it
    /// stopped.
    private static func settle(_ stage: StageEdge, from start: Double) -> Double {
        var time = start

        repeat {
            time += 1000 / 60
            stage.step(at: time)
        } while stage.lastPace == .moving && time - start < 10_000
        return time
    }

    /// The footer as the window draws it, at the welcome's step: the lit spans across its middle, in points from the
    /// window's left.
    private static func footer(_ made: Made) throws -> [ClosedRange<CGFloat>] {
        let footer = WelcomeFooterView(welcome: made.welcome, footer: made.welcome.steps.footer)
        let drawn = try Drawn(footer, size: CGSize(width: WelcomeStyle.size.width, height: WelcomeStyle.footer))

        return drawn.litSpans(atY: WelcomeStyle.footer / 2)
    }

    private static func width(_ span: ClosedRange<CGFloat>) -> CGFloat {
        span.upperBound - span.lowerBound
    }

    private static func views<View: NSView>(_ kind: View.Type, in view: NSView) -> [View] {
        view.subviews.flatMap { ($0 as? View).map { [$0] } ?? views(kind, in: $0) }
    }

    private static func segments(in view: NSView) -> [NSSegmentedControl] {
        views(NSSegmentedControl.self, in: view)
    }

    /// The form's segmented controls by their first segment's word, each at its height in the window.
    private static func rows(in view: NSView) -> [String: CGFloat] {
        Dictionary(segments(in: view).map { ($0.label(forSegment: 0) ?? "", $0.convert($0.bounds, to: nil).midY) }) { $1 }
    }
}
