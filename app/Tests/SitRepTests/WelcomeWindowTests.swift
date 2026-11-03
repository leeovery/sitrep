import AppKit
import ServiceManagement
@testable import SitRep
import SitRepCore
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepPanel
import SitRepRelay
import SwiftUI
import Testing

/// The welcome window, made, never shown, over a Mac of its own: nothing is registered with macOS, asked of it, opened,
/// copied or played.
@MainActor
struct WelcomeWindowTests {
    /// What the welcome asked of the Mac, and the login item and the leaves as macOS would say them.
    @MainActor
    final class Mac {
        var login = LoginItem(.notRegistered)
        var registers = 0
        var unregisters = 0
        var played: [String] = []
        var stops = 0
        var copies: [String] = []
        var opened: [Leaves.Place] = []
        /// Jumps to a session, and test notifications sent.
        var jumps: [String] = []
        var tests = 0
        /// What macOS says of notifications, and what Lee answers its prompt.
        var notices: NoticeLeave? = .unasked
        var answersNotices = NoticeLeave.allowed(.banners)
        var asksForNotices = 0
        /// While set, macOS's prompt waits on Lee until `answer` is called.
        var holdsPrompt = false
        private var prompt: CheckedContinuation<Void, Never>?
        /// Whether SitRep may control Ghostty, what Lee answers its prompt, and whether Ghostty runs as it is asked.
        var ghostty = GhosttyLeave.unknown
        var answersGhostty = GhosttyLeave.allowed
        var allows: [Bool] = []
        var ghosttyRuns = false
        var opensGhostty = 0
        /// The waits begun on a prompt; while `holdsWait` is set, each held until `waitEnds` is called, else over at
        /// once.
        var waits: [Duration] = []
        var holdsWait = false
        private var waiting: CheckedContinuation<Void, Never>?

        /// Choosing the login item flips it, as `Leaves.chooseLogin` does; waiting on Lee's approval, it opens Login
        /// Items and changes nothing. Asked, macOS takes Lee's answer, once he gives it while the prompt is held;
        /// macOS can say of Ghostty only while it runs.
        func services() -> SettingsServices {
            SettingsServices(
                displays: { [] }, hasGlass: true, jump: { self.jumps.append($0) }, sendTest: { self.tests += 1 },
                copy: { self.copies.append($0) },
                sounds: AlertSounds(
                    names: AlertSounds.live.names, play: { self.played.append($0) }, stop: { self.stops += 1 }
                ),
                noticeLeave: { self.notices },
                askForNotices: {
                    self.asksForNotices += 1
                    if self.holdsPrompt {
                        await withCheckedContinuation { self.prompt = $0 }
                    }
                    self.notices = self.answersNotices
                },
                login: { self.login },
                chooseLogin: { self.choose() },
                ghostty: { self.ghostty },
                allowGhostty: {
                    self.allows.append(self.ghosttyRuns)
                    if self.holdsPrompt {
                        await withCheckedContinuation { self.prompt = $0 }
                    }
                    self.ghostty = self.ghosttyRuns ? self.answersGhostty : .unknown
                    return self.ghostty
                },
                open: { self.opened.append($0) }
            )
        }

        func welcome() -> WelcomeMac {
            WelcomeMac(
                ghosttyRuns: { self.ghosttyRuns },
                openGhostty: {
                    self.opensGhostty += 1
                    self.ghosttyRuns = true
                },
                wait: { duration in
                    self.waits.append(duration)
                    if self.holdsWait {
                        await withCheckedContinuation { self.waiting = $0 }
                    }
                }
            )
        }

        /// Lee answers macOS's prompt.
        func answer() {
            prompt?.resume()
            prompt = nil
        }

        /// The wait on a prompt runs out.
        func waitEnds() {
            waiting?.resume()
            waiting = nil
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

    /// The welcome, its window's frame a recorded one, which never orders front; shown, unless made for SitRep's first
    /// start, over defaults of its own unless given some.
    @MainActor
    struct Made {
        let mac = Mac()
        let preferences: Preferences
        let welcome: WelcomeModel
        let window: WelcomeWindow
        let recorded = RecordedWindow.made()

        init(
            welcomed: Bool = false, plugin: PluginStanding? = nil, login: LoginItem = LoginItem(.notRegistered),
            defaults: UserDefaults = MemoryDefaults(), shows: Bool = true
        ) {
            let live = LiveBoard()

            live.plugin = plugin
            mac.login = login
            preferences = Preferences(defaults)
            if welcomed {
                preferences.welcomed = true
            }
            welcome = WelcomeModel(preferences: preferences, live: live, services: mac.services(), mac: mac.welcome())
            let recorded = recorded
            window = WelcomeWindow(welcome: welcome) { content in
                recorded.contentViewController = content
                return recorded
            }
            if shows {
                window.show()
            }
        }

        /// The window come forward, as AppKit tells its delegate, and what it read then read.
        func key() async {
            window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
            await welcome.reading?.value
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

        /// What the window shows, laid out once SwiftUI has heard what changed, and what the layout told after it, the
        /// callout's place, told.
        func settled() async -> NSView {
            await Task.yield()
            await Task.yield()
            recorded.contentView?.layoutSubtreeIfNeeded()
            await Task.yield()
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

        let item = { (action: Selector) in NSMenuItem(title: "", action: action, keyEquivalent: "") }

        #expect(window.validateMenuItem(item(#selector(NSWindow.performClose(_:)))))
        #expect(!window.validateMenuItem(item(#selector(NSWindow.performMiniaturize(_:)))))
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

        #expect(dashes.count == WelcomeSteps.all.count)
        #expect(dashes.count == 6)
        #expect(zip(dashes.map(Self.width), [22.0, 10, 10, 10, 10, 10]).allSatisfy { abs($0 - $1) <= 0.5 })
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
        for step in [WelcomeStep.edge, .sound, .permissions, .ready] {
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

    /// In front, frames run as things move, the light alone on its slow refresh; behind, none for the light alone;
    /// closed, the link gone, made anew as the window next comes forward.
    @Test func theStagesFramesStopWhileTheWindowIsBehind() async throws {
        let made = Made()
        let stage = made.window.stage

        made.at(.edge)
        _ = await made.settled()
        #expect(stage.link == nil)
        Self.key(made)
        #expect(stage.standing == .inFront && stage.isDrawing)
        Self.settle(stage, from: Displays.now)
        #expect(stage.isDrawing == (stage.lastPace == .light))
        made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        #expect(stage.standing == .behind && !stage.isDrawing)

        let link = try #require(stage.link)

        made.recorded.close()
        #expect(stage.standing == .closed && stage.link == nil)
        made.window.show()
        stage.play = .chime
        Self.key(made)
        stage.chime(1)
        #expect(stage.isDrawing && stage.link !== link)
        made.closeAgain()
        #expect(stage.link == nil)
    }

    /// Step 1 at rest sleeps, its next beat pending at the loop's next change, the ask landing; a beat re-arms it, and
    /// at that time in the loop, the ask lands and frames run.
    @Test func onStepOneTheStageSleepsUntilTheLoopsNextBeat() throws {
        let made = Made()
        let stage = made.window.stage

        Self.settle(stage, from: Displays.now)
        Self.key(made)

        let beat = try #require(stage.beat)
        let wait = (WelcomeLoop.hello.next(after: stage.loopTime) - stage.loopTime) / 1000

        #expect(!stage.isDrawing)
        #expect(WelcomeLoop.hello.next(after: stage.loopTime) == WelcomeLoop.hello.lands)
        #expect(abs(beat.fireDate.timeIntervalSinceNow - wait) < 0.1)
        beat.fire()
        #expect(stage.beat != nil && stage.beat !== beat)

        let time = Displays.now

        stage.step(at: time)
        stage.step(at: time + WelcomeLoop.hello.lands - stage.loopTime)
        #expect(stage.isDrawing && stage.beat == nil)
    }

    /// Closing stops the frames for good: the link invalidated and the pending beat with it.
    @Test func closingDropsTheLinkAndTheBeat() throws {
        let made = Made()
        let stage = made.window.stage

        Self.settle(stage, from: Displays.now)
        Self.key(made)

        let time = Displays.now

        stage.step(at: time)
        stage.step(at: time + WelcomeLoop.hello.lands - stage.loopTime)
        Self.settle(stage, from: time + WelcomeLoop.hello.lands)

        let beat = try #require(stage.beat)

        #expect(stage.link != nil)
        made.recorded.close()
        #expect(stage.link == nil && stage.beat == nil && !beat.isValid)
    }

    /// A change Lee makes in Settings while the welcome is behind is drawn at once, the callout moving with the notch.
    @Test func aSettingsChangeIsDrawnWhileTheWindowIsBehind() async {
        let made = Made()
        let stage = made.window.stage

        made.at(.ready)
        _ = await made.settled()
        Self.key(made)
        made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        #expect(!stage.callout.place.isRight)
        made.preferences.edit { $0.edge = .right }
        _ = await made.settled()
        #expect(stage.callout.place.isRight)
        #expect(stage.surface.frame.maxX == stage.edge.frame.maxX)
    }

    /// One that sets the shape moving runs frames behind until it settles, then sleeps, the loop's clock held.
    @Test func aChangeMadeBehindRunsFramesUntilItSettles() async {
        let made = Made()
        let stage = made.window.stage

        Self.settle(stage, from: Displays.now)
        Self.key(made)
        made.window.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))

        let loopTime = stage.loopTime

        made.preferences.edit { $0.show = .strip }
        _ = await made.settled()
        #expect(stage.lastPace == .moving && stage.isDrawing)
        Self.settle(stage, from: Displays.now)
        #expect(stage.lastPace != .moving && !stage.isDrawing)
        #expect(stage.loopTime == loopTime)
    }

    /// The ask's row is found again on the shape as it now stands: another style's panel lays it elsewhere, and the
    /// strip has none. Frames on a clock of the test's own, never awaiting, so no frame on the display's clock comes
    /// between them.
    @Test func theLoopsPointerFindsTheRowAgainAfterAChange() throws {
        let made = Made()
        let stage = made.window.stage

        Self.settle(stage, from: Displays.now)
        Self.key(made)

        var time = Displays.now

        while stage.row == nil, stage.loopTime < WelcomeLoop.hello.length - 100 {
            time += 1000 / 60
            stage.step(at: time)
        }

        let meniscus = try #require(stage.row)

        made.preferences.edit { $0.style = .card }
        for _ in 0 ..< 30 {
            time += 1000 / 60
            stage.step(at: time)
        }
        #expect(stage.row != meniscus)
        made.preferences.edit { $0.show = .strip }
        stage.step(at: time + 1000 / 60)
        #expect(stage.row == nil)
    }

    /// The strip centres where the notch sits on the stage, Paper's place, wherever Lee dragged his own, so the
    /// callout points at it.
    @Test func theStagesStripCentresWhereTheCalloutPoints() async {
        let made = Made()
        let stage = made.window.stage

        made.preferences.edit { $0.show = .strip; $0.along = 0.1 }
        made.at(.ready)
        _ = await made.settled()
        #expect(stage.surface is StripSurface)
        #expect(abs(stage.callout.place.middle - StageEdge.stillNotchY) < 1e-9)
        #expect(abs(stage.resting.midY * stage.scale - stage.callout.place.middle) < 4)
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

    /// The window come forward, as AppKit tells its delegate.
    private static func key(_ made: Made) {
        made.window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
    }

    /// The stage stepped a 60th at a time from this time, until nothing moves or ten seconds pass: when it stopped.
    @discardableResult
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
        let rows = segments(in: view).map { ($0.label(forSegment: 0) ?? "", $0.convert($0.bounds, to: nil).midY) }

        return Dictionary(rows) { $1 }
    }
}
