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

/// The welcome window's world, for its suites: a Mac of its own, the windows the welcome makes, each a recorded one,
/// and the welcome made over them; nothing is registered with macOS, asked of it, opened, copied or played.
enum WelcomeWorld {
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
        /// What macOS says of notifications, and what Lee answers its prompt: nil, the helper silent.
        var notices: NoticeLeave? = .unasked
        var answersNotices: NoticeLeave? = .allowed(.banners)
        var asksForNotices = 0
        /// While set, macOS's prompt waits on Lee until `answer` is called.
        var holdsPrompt = false
        private var prompt: CheckedContinuation<Void, Never>?
        /// While set, a read of notifications waits until `readEnds` is called, then says what macOS said as it began.
        var holdsRead = false
        private var read: CheckedContinuation<Void, Never>?
        /// Whether SitRep may control Ghostty, what Lee answers its prompt, and whether Ghostty runs as it is asked.
        var ghostty = GhosttyLeave.unknown
        var answersGhostty = GhosttyLeave.allowed
        var allows: [Bool] = []
        var ghosttyRuns = false
        /// What opening Ghostty comes to, Ghostty installed unless it comes to not installed, and how many times it was
        /// opened.
        var opening = GhosttyOpening.runs
        var opensGhostty = 0
        /// The waits begun: on a prompt, while `holdsWait` is set, each held until `waitEnds` is called, else over at
        /// once; on the notices helper, over only once `limitRunsOut` is set, else until the ask no longer waits.
        var waits: [Duration] = []
        var holdsWait = false
        var limitRunsOut = false
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
                noticeLeave: {
                    let said = self.notices

                    if self.holdsRead {
                        await withCheckedContinuation { self.read = $0 }
                    }
                    return said
                },
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
                ghosttyInstalled: { self.opening != .notInstalled }, ghosttyRuns: { self.ghosttyRuns },
                openGhostty: {
                    self.opensGhostty += 1
                    self.ghosttyRuns = self.opening == .runs
                    return self.opening
                },
                wait: { duration in
                    self.waits.append(duration)
                    if duration == WelcomePermission.limit {
                        if !self.limitRunsOut {
                            try? await Task.sleep(for: .seconds(3600))
                        }
                    } else if self.holdsWait {
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

        /// The read held ends.
        func readEnds() {
            read?.resume()
            read = nil
        }

        /// Whether macOS's prompt, a read or a wait on a prompt is held now.
        var isPrompting: Bool { prompt != nil }
        var isReading: Bool { read != nil }
        var isWaiting: Bool { waiting != nil }

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

    /// The welcome's windows, each a recorded one, made in turn as it opens; focusing, each gives focus to its first key
    /// view as it orders in and as it keys, as AppKit does.
    @MainActor
    final class Frames {
        var focusing = false
        private(set) var made: [RecordedWindow] = []

        func frame(_ content: NSViewController) -> RecordedWindow {
            let window = RecordedWindow.made()

            window.focusesAsItOrders = focusing
            window.focusesAsItKeys = focusing
            window.contentViewController = content
            made.append(window)
            return window
        }
    }

    /// The welcome, shown, its window's frame a recorded one, which never orders front, over defaults of its own unless
    /// given some.
    @MainActor
    struct Made {
        let mac = Mac()
        let preferences: Preferences
        let welcome: WelcomeModel
        let window: WelcomeWindow
        let frames = Frames()

        init(
            welcomed: Bool = false, plugin: PluginStanding? = nil, login: LoginItem = LoginItem(.notRegistered),
            defaults: UserDefaults = MemoryDefaults(), focusing: Bool = false
        ) {
            let live = LiveBoard()

            frames.focusing = focusing
            live.plugin = plugin
            mac.login = login
            preferences = Preferences(defaults)
            if welcomed {
                preferences.welcomed = true
            }
            welcome = WelcomeModel(preferences: preferences, live: live, services: mac.services(), mac: mac.welcome())
            window = WelcomeWindow(welcome: welcome, frame: frames.frame)
            window.show()
        }

        /// The window showing, or last shown.
        var recorded: RecordedWindow { frames.made.last! }

        /// The stage of the window showing.
        var stage: StageEdge {
            get throws { try #require(window.stage) }
        }

        /// The window come forward, as AppKit tells its delegate, and what it read then read.
        func key() async {
            window.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: recorded))
            await welcome.reading?.value
        }

        /// The welcome at this step, from its first.
        func at(_ step: WelcomeStep) {
            while welcome.step != step {
                welcome.goOn()
            }
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
}
