import AppKit
import ServiceManagement
@testable import SitRep
import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SitRepRelay
import SitRepTestSupport
import SwiftUI
import Testing

/// The welcome window, made, never shown, over a Mac of its own: nothing is registered with macOS, asked of it, opened,
/// copied or played.
@MainActor
@Suite(.backstop)
struct WelcomeWindowTests {
    typealias Mac = WelcomeWorld.Mac
    typealias Made = WelcomeWorld.Made
    typealias Clock = WelcomeWorld.Clock

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

        let item = { (action: Selector) in NSMenuItem(title: "", action: action, keyEquivalent: "") }

        #expect(window.validateMenuItem(item(#selector(NSWindow.performClose(_:)))))
        #expect(!window.validateMenuItem(item(#selector(NSWindow.performMiniaturize(_:)))))
        #expect(window.standardWindowButton(.zoomButton)?.isEnabled != true)
    }

    /// Opened again while it shows, the same window comes forward on the Space Lee is on, as About SitRep does.
    @Test func whileItShowsItIsOneWindowBroughtForward() {
        let made = Made()

        made.window.show()
        #expect(made.frames.made.count == 1)
        #expect(made.recorded.steps == [
            .orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true),
            .orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true),
        ])
    }

    /// Each time it opens, a window of its own, its stage too, comes forward on the Space Lee is on, centred.
    @Test func afterItClosedItOpensAsAWindowOfItsOwn() throws {
        let made = Made()
        let first = made.recorded, stage = try made.stage

        first.setFrameOrigin(.zero)
        first.close()
        made.window.show()

        #expect(made.frames.made.count == 2)
        #expect(made.recorded !== first)
        #expect(try made.stage !== stage)
        #expect(made.recorded.delegate === made.window)
        #expect(made.recorded.steps == [.orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true)])
        #expect(made.recorded.contentRect(forFrameRect: made.recorded.frame).size == WelcomeStyle.size)
        #expect(made.recorded.frame.origin != .zero)
    }

    /// Closed, by Skip setup, its close button or SitRep quitting, the window, its content and its stage are let go.
    @Test func closedTheWindowIsLetGo() async {
        let closes: [@MainActor (WelcomeModel, WelcomeWindow, RecordedWindow?) -> Void] = [
            { welcome, _, _ in welcome.skip() }, { _, _, window in window?.performClose(nil) },
            { _, window, _ in window.closeIfOpen() },
        ]

        for (place, closing) in closes.enumerated() {
            let mac = Mac()
            let welcome = WelcomeModel(
                preferences: Preferences(MemoryDefaults()), live: LiveBoard(), services: mac.services(), mac: mac.welcome()
            )
            weak var window: RecordedWindow?
            weak var content: NSViewController?
            weak var stage: StageEdge?
            let shown = WelcomeWindow(welcome: welcome) { made in
                let recorded = RecordedWindow.made()

                recorded.contentViewController = made
                (window, content) = (recorded, made)
                return recorded
            }

            shown.show()
            stage = shown.stage
            window?.becomeKey()
            #expect(window != nil && content != nil && stage != nil, "\(place)")
            closing(welcome, shown, window)
            await until(turns: 1000, "\(place)") { window == nil && content == nil && stage == nil }
            #expect(!welcome.isVisiting && shown.stage == nil, "\(place)")
        }
    }

    /// The menu's Show Welcome Window opens it at its first step, wherever it was left.
    @Test func itOpensAtItsFirstStep() {
        let made = Made()

        made.at(.sound)
        made.window.show()
        #expect(made.welcome.step == .hello)
    }

    // MARK: The footer

    /// The footer as drawn: at the first step, Skip setup between the dashes and Continue; at the last, nothing between
    /// them, and Done, a narrower pill, against the window's right, 16 in.
    @Test func atTheLastStepContinueReadsDoneAndSkipSetupGoes() throws {
        let made = Made()
        let first = try Self.footer(made)

        made.at(.ready)

        let last = try Self.footer(made)
        let between = { (spans: [ClosedRange<CGFloat>]) in spans.filter { $0.lowerBound > 200 }.dropLast() }
        let pills = try [first, last].map { try #require($0.last) }

        #expect(!between(first).isEmpty)
        #expect(between(last).isEmpty)
        expectEvery(pills) { abs($0.upperBound - 824) <= 0.5 }
        #expect(Self.width(pills[1]) < Self.width(pills[0]))
    }

    /// The first dash long, the rest short, 5 apart.
    @Test func atTheFirstStepTheFirstDashIsLong() throws {
        let made = Made()
        let dashes = try Self.footer(made).filter { $0.lowerBound > 60 && $0.upperBound < 200 }

        #expect(dashes.count == WelcomeSteps.all.count)
        #expect(dashes.count == 6)
        expectEvery(zip(dashes.map(Self.width), [22.0, 10, 10, 10, 10, 10])) { abs($0 - $1) <= 0.5 }
    }

    @Test func continueGoesOnAndDoneClosesTheWindow() {
        let made = Made()
        var closes = 0

        made.welcome.closeWindow = { closes += 1 }
        made.welcome.goOn()
        #expect(made.welcome.step == .ask)
        made.at(.ready)
        made.welcome.goOn()
        #expect(closes == 1)
    }

    // MARK: Your edge

    /// Each press sets the setting itself, so the stage and the real edge move at once.
    @Test func aTileSetsTheRealSettingAndTheStageMoves() throws {
        let made = Made()

        made.at(.edge)
        made.welcome.choose(.strip)
        try made.stage.step(at: made.clock.now)
        #expect(made.preferences.edge.show == .strip)
        #expect(try made.stage.surface is StripSurface)
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

    /// A sound's click saves one change to the settings, Play a sound and the sound together, never a half-made one.
    @Test func aSoundsClickIsOneChangeToTheSettings() {
        let defaults = MemoryDefaults()
        let made = Made(defaults: defaults)
        nonisolated(unsafe) var changes: [AppSettings] = []

        made.at(.sound)

        let saves = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: nil
        ) { _ in changes.append(SavedSettings<AppSettings>(defaults).read()) }

        defer { NotificationCenter.default.removeObserver(saves) }
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
            welcome: WelcomeModel(
                preferences: preferences, live: LiveBoard(), services: mac.services(), mac: mac.welcome()
            )
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
        made.recorded.close()
        #expect(made.mac.registers == 1 && !made.welcome.login.isOn)
        #expect(!made.welcome.isVisiting)
    }

    /// So a later Show Welcome Window never undoes Lee's choice in General, and shows no notice for an item on for
    /// months.
    @Test func aWelcomeOpenedAgainChangesNothingUntilPressed() {
        let made = Made(welcomed: true)

        made.mac.login = LoginItem(.enabled)
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: made.recorded))
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

    /// Lee's own Mac: SitRep registered before any welcome closed. Turned off in Settings › General, Skip setup leaves
    /// it off.
    @Test func anItemFoundOnIsLeesSoSkipNeverTurnsItBackOn() {
        let made = Made(login: LoginItem(.enabled))

        made.mac.login = LoginItem(.notRegistered)
        made.welcome.skip()
        #expect(made.mac.registers == 0 && !made.welcome.login.isOn)
    }

    /// Changed elsewhere since the welcome last read it, it is Lee's: off again as the window closes, it stays off.
    @Test func anItemFoundChangedIsLeesSoClosingLeavesIt() {
        let made = Made()

        made.mac.login = LoginItem(.requiresApproval)
        Self.key(made)
        made.mac.login = LoginItem(.notRegistered)
        made.welcome.skip()
        #expect(made.mac.registers == 0)
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
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: made.recorded))
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
        let stage = try made.stage
        let view = await made.settled()

        #expect(stage.isDescendant(of: view))
        #expect((stage.surface as? NotchSurface)?.drawing is NotchView)
        made.preferences.edit { $0.show = .strip }
        stage.step(at: made.clock.now)
        #expect((stage.surface as? StripSurface)?.drawing is StripView)
    }

    @available(macOS 26, *)
    @Test func theStagesEdgeTakesTheMaterialLeeChose() throws {
        let made = Made()
        let stage = try made.stage

        made.preferences.edit { $0.material = .glass }
        stage.step(at: made.clock.now)
        #expect((stage.surface as? NotchSurface)?.drawing is NotchGlassView)
        made.preferences.edit { $0.show = .strip }
        stage.step(at: made.clock.now)
        #expect((stage.surface as? StripSurface)?.drawing is StripGlassView)
    }

    /// The stage's screen: the notch's window against its left, or its right.
    @Test func theStageFollowsTheEdgeLeeChose() throws {
        let made = Made()
        let stage = try made.stage
        let screen = stage.edge.frame

        #expect(stage.surface.frame.minX == 0)
        made.preferences.edit { $0.edge = .right }
        stage.step(at: made.clock.now)
        #expect(stage.surface.frame.maxX == screen.maxX)
    }

    /// Step 1's open panel at 0.7, so it sits on the stage as on a screen; the notch alone at its real size after it,
    /// its home where Paper's boards put it.
    @Test func stepOnePlaysTheEdgeAtSevenTenthsAndTheRestAtItsRealSize() async throws {
        let made = Made()
        let stage = try made.stage
        let size = WelcomeStyle.stage

        _ = await made.settled()
        #expect(StageEdge.loopScale == 0.7 && StageEdge.stillScale == 1)
        #expect(stage.scale == StageEdge.loopScale)
        #expect(stage.edge.frame.size == CGSize(width: size.width / 0.7, height: size.height / 0.7))
        #expect(abs(stage.edge.stage.notchY * stage.scale - StageEdge.loopNotchY) < 1e-9)
        for step in [WelcomeStep.edge, .sound, .permissions, .ready] {
            made.at(step)
            _ = await made.settled()
            #expect(stage.scale == StageEdge.stillScale, "\(step)")
            #expect(stage.edge.frame.size == size, "\(step)")
            #expect(abs(stage.edge.stage.notchY - StageEdge.stillNotchY) < 1e-9, "\(step)")
        }
    }

    /// Each sound chosen, the stage's notch swells, as for an ask that lands: once settled, and again.
    @Test func theStagesNotchSwellsWithEachSoundChosen() async throws {
        let made = Made()
        let stage = try made.stage

        made.at(.sound)
        _ = await made.settled()
        #expect(stage.play == .chime)
        for sound in ["Pop", "Tink"] {
            Self.settle(stage, on: made.clock)
            #expect(stage.lastPace != .moving, "\(sound)")
            made.welcome.choose(sound: sound)
            _ = await made.settled()
            #expect(stage.lastPace == .moving, "\(sound)")
        }
    }

    /// In front, frames run as things move, the light alone on its slow refresh; behind, none for the light alone;
    /// closed, the link gone for good, the next window's stage making one of its own as it comes forward.
    @Test func theStagesFramesStopWhileTheWindowIsBehind() async throws {
        let made = Made()
        let stage = try made.stage

        made.at(.edge)
        _ = await made.settled()
        #expect(stage.link == nil)
        Self.key(made)
        #expect(stage.standing == .inFront && stage.isDrawing)
        Self.settle(stage, on: made.clock)
        #expect(stage.isDrawing == (stage.lastPace == .light))
        made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: made.recorded))
        #expect(stage.standing == .behind && !stage.isDrawing)

        let link = try #require(stage.link)

        made.recorded.close()
        #expect(stage.standing == .closed && stage.link == nil)
        made.window.show()

        let next = try made.stage

        next.play = .chime
        Self.key(made)
        next.chime(1)
        #expect(next.isDrawing && next.link !== link)
        #expect(stage.standing == .closed && stage.link == nil)
        made.recorded.close()
        #expect(next.standing == .closed && next.link == nil)
    }

    /// Step 1 at rest sleeps, its next beat pending at the loop's next change, the ask landing; a beat re-arms it, and
    /// at that time in the loop, the ask lands and frames run.
    @Test func onStepOneTheStageSleepsUntilTheLoopsNextBeat() throws {
        let made = Made()
        let stage = try made.stage

        Self.settle(stage, on: made.clock)
        Self.key(made)

        let beat = try #require(stage.beat as? Clock.Wake)
        let wait = WelcomeLoop.hello.next(after: stage.loopTime) - stage.loopTime

        #expect(!stage.isDrawing)
        #expect(WelcomeLoop.hello.next(after: stage.loopTime) == WelcomeLoop.hello.lands)
        #expect(beat.due == made.clock.now + wait)
        beat.fire()

        let rearmed = try #require(stage.beat as? Clock.Wake)

        #expect(rearmed !== beat)
        made.clock.fire(rearmed)
        #expect(stage.loopTime > WelcomeLoop.hello.lands)
        #expect(stage.isDrawing && stage.beat == nil)
    }

    /// Closing stops the frames for good: the link invalidated and the pending beat with it.
    @Test func closingDropsTheLinkAndTheBeat() throws {
        let made = Made()
        let stage = try made.stage

        Self.settle(stage, on: made.clock)
        Self.key(made)
        stage.step(at: made.clock.pass(WelcomeLoop.hello.lands - stage.loopTime))
        Self.settle(stage, on: made.clock)

        let beat = try #require(stage.beat as? Clock.Wake)

        #expect(stage.link != nil)
        made.recorded.close()
        #expect(stage.link == nil && stage.beat == nil && !beat.isValid)
    }

    /// A change Lee makes in Settings while the welcome is behind is drawn at once, the callout moving with the notch.
    @Test func aSettingsChangeIsDrawnWhileTheWindowIsBehind() async throws {
        let made = Made()
        let stage = try made.stage

        made.at(.ready)
        _ = await made.settled()
        Self.key(made)
        made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: made.recorded))
        #expect(stage.callout.place?.isRight == false)
        made.preferences.edit { $0.edge = .right }
        _ = await made.settled()
        #expect(stage.callout.place?.isRight == true)
        #expect(stage.surface.frame.maxX == stage.edge.frame.maxX)
    }

    /// One that sets the shape moving runs frames behind until it settles, then sleeps, the loop's clock held.
    @Test func aChangeMadeBehindRunsFramesUntilItSettles() async throws {
        let made = Made()
        let stage = try made.stage

        Self.settle(stage, on: made.clock)
        Self.key(made)
        made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: made.recorded))

        let loopTime = stage.loopTime

        made.preferences.edit { $0.show = .strip }
        _ = await made.settled()
        #expect(stage.lastPace == .moving && stage.isDrawing)
        Self.settle(stage, on: made.clock)
        #expect(stage.lastPace != .moving && !stage.isDrawing)
        #expect(stage.loopTime == loopTime)
    }

    /// The ask's row is found again on the shape as it now stands: the notch's in its panel, then, the strip chosen, the
    /// strip's mark, in the strip's depth, from the change's own frame. Frames on a clock of the test's own, never
    /// awaiting, so no frame on the display's clock comes between them.
    @Test func theLoopsPointerFindsTheRowAgainAfterAChange() throws {
        let made = Made()
        let stage = try made.stage

        Self.settle(stage, on: made.clock)
        Self.key(made)
        while stage.row == nil, stage.loopTime < WelcomeLoop.hello.length - 100 {
            stage.step(at: made.clock.pass(1000 / 60))
        }
        #expect(try #require(stage.row).x > Strip.restingWidth)
        made.preferences.edit { $0.show = .strip }
        stage.step(at: made.clock.pass(1000 / 60))
        #expect(try #require(stage.row).x < Strip.restingWidth)
    }

    /// The strip's length changed while the pointer rests on the ask's mark sends the mark elsewhere before the strip
    /// has begun to move: the pointer goes where the mark now goes from the change's own frame, never where it was.
    @Test func aChangeThatMovesTheMarkMovesThePointerAtOnce() throws {
        let made = Made()
        let stage = try made.stage

        made.preferences.edit { $0.show = .strip }
        Self.settle(stage, on: made.clock)
        Self.key(made)
        while stage.loopTime < WelcomeLoop.hello.onRow + 300 {
            stage.step(at: made.clock.pass(1000 / 60))
        }

        let before = try #require(stage.row)

        made.preferences.edit { $0.length = .full }
        stage.step(at: made.clock.pass(1000 / 60))

        let moved = try #require(stage.row)

        for _ in 0 ..< 40 {
            stage.step(at: made.clock.pass(1000 / 60))
        }
        #expect(moved != before)
        #expect(stage.row == moved)
    }

    /// The strip's length changed while the window is behind, the loop paused before the stage looks for the ask's
    /// mark, while the pointer rests on it, or once the pointer has gone: back in front, the pointer goes by the mark
    /// where it now is, in that loop or the next, as on a stage that had the length from the first.
    @Test(arguments: [WelcomeLoop.hello.seeks - 500, WelcomeLoop.hello.onRow + 300, WelcomeLoop.hello.leave + 1000])
    func aChangeWhileThePlayIsPausedFindsTheRowWhereItNowIs(pausedAt: Double) throws {
        let hello = WelcomeLoop.hello, made = Made()
        let stage = try Self.stripOnTheLoop(made, to: pausedAt)
        let loop = pausedAt < hello.onRow + 600 ? 0 : hello.length

        made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: made.recorded))
        made.preferences.edit { $0.length = .full }
        Self.settle(stage, on: made.clock)
        Self.key(made)
        Self.run(stage, on: made.clock, to: loop + hello.onRow + 600)

        #expect(stage.row == (try Self.rowOnAFullStrip(at: stage.loopTime)))
    }

    /// The strip's length changed while the pointer glides off the ask's mark, the loop paused or not: it glides off
    /// the mark where it now is, never where it was; and in the next loop, the pointer goes by it there.
    @Test(arguments: [false, true])
    func aChangeAsThePointerGlidesOffFindsTheRowWhereItNowIs(paused: Bool) throws {
        let made = Made()
        let stage = try Self.stripOnTheLoop(made, to: WelcomeLoop.hello.leave + 200)
        let was = try #require(stage.row)

        if paused {
            made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: made.recorded))
        }
        made.preferences.edit { $0.length = .full }
        stage.step(at: made.clock.pass(1000 / 60))
        Self.key(made)
        stage.step(at: made.clock.pass(1000 / 60))

        let now = try #require(stage.row)

        #expect(now != was)
        #expect(now == (try Self.rowOnAFullStrip(at: stage.loopTime)))
        Self.run(stage, on: made.clock, to: WelcomeLoop.hello.length + WelcomeLoop.hello.onRow + 300)
        #expect(stage.row == now)
    }

    /// The notch restyled while its panel is out, the loop paused or not, plays the loop from its start, as the notch
    /// closes its panel to change: the panel pours again in the new style, and the pointer goes to the ask's row
    /// there, as on a stage that had the style from the first.
    @Test(arguments: [false, true])
    func aStyleChangeWhileThePanelIsOutPlaysTheLoopAgain(paused: Bool) throws {
        let hello = WelcomeLoop.hello, made = Made()
        let stage = try made.stage

        Self.settle(stage, on: made.clock)
        Self.key(made)
        Self.run(stage, on: made.clock, to: hello.onRow + 300)
        try #require(stage.isOut && stage.row != nil)
        if paused {
            made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: made.recorded))
        }
        made.preferences.edit { $0.style = .card }
        stage.step(at: made.clock.pass(1000 / 60))
        #expect(stage.loopTime < 1000 / 60 + 1)
        #expect(stage.row == nil && !stage.isOut)
        Self.key(made)
        Self.run(stage, on: made.clock, to: hello.onRow + 600)

        let card = Made()

        card.preferences.edit { $0.style = .card }

        let fromTheFirst = try card.stage

        Self.settle(fromTheFirst, on: card.clock)
        Self.key(card)
        Self.run(fromTheFirst, on: card.clock, to: stage.loopTime)
        #expect(stage.isOut)
        #expect(stage.row != nil && stage.row == fromTheFirst.row)
    }

    /// The strip at Grows on the stage, in front, the loop played this far.
    private static func stripOnTheLoop(_ made: Made, to loopTime: Double) throws -> StageEdge {
        let stage = try made.stage

        made.preferences.edit { $0.show = .strip }
        Self.settle(stage, on: made.clock)
        Self.key(made)
        Self.run(stage, on: made.clock, to: loopTime)
        return stage
    }

    /// The ask's mark found on a stage whose strip was Full from the first, its loop played this far.
    private static func rowOnAFullStrip(at loopTime: Double) throws -> CGPoint? {
        let made = Made()

        made.preferences.edit { $0.length = .full }
        return try Self.stripOnTheLoop(made, to: loopTime).row
    }

    /// The strip centres where the notch sits on the stage, Paper's place, wherever Lee dragged his own, so the
    /// callout points at it.
    @Test func theStagesStripCentresWhereTheCalloutPoints() async throws {
        let made = Made()
        let stage = try made.stage

        made.preferences.edit { $0.show = .strip; $0.along = 0.1 }
        made.at(.ready)
        _ = await made.settled()
        #expect(stage.surface is StripSurface)

        let place = try #require(stage.callout.place)

        #expect(abs(place.middle - StageEdge.stillNotchY) < 1e-9)
        #expect(abs(stage.resting.midY * stage.scale - place.middle) < 4)
    }

    @Test func eachStepTellsTheStageWhatToPlay() async throws {
        let made = Made()

        _ = await made.settled()
        #expect(try made.stage.play == .loop)
        made.at(.edge)
        _ = await made.settled()
        #expect(try made.stage.play == .lit)
    }

    // MARK: Helpers

    /// The window come forward, as AppKit tells its delegate.
    private static func key(_ made: Made) {
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: made.recorded))
    }

    /// The stage stepped a 60th at a time on the test's clock, until nothing moves or ten seconds pass.
    private static func settle(_ stage: StageEdge, on clock: Clock) {
        let start = clock.now

        repeat {
            stage.step(at: clock.pass(1000 / 60))
        } while stage.lastPace == .moving && clock.now - start < 10_000
    }

    /// The stage stepped a 60th at a time on the test's clock, until its loop has played this far.
    private static func run(_ stage: StageEdge, on clock: Clock, to loopTime: Double) {
        while stage.loopTime < loopTime {
            stage.step(at: clock.pass(1000 / 60))
        }
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
        let rows = segments(in: view).map { ($0.label(forSegment: 0) ?? "", $0.convert($0.bounds, to: nil).midY) }

        return Dictionary(rows) { $1 }
    }
}
