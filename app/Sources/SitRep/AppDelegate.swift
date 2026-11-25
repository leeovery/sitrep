import AppKit
import SitRepCore
import SitRepMenu
import SitRepScreen

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let banners = Banners.live()
    private let plugin = Plugin()
    private lazy var works = Works(banners: banners, path: plugin.path, hereFile: hereFile) { [preferences] in
        preferences.app.openSettings
    }
    private lazy var snoozes = Snoozes(plugin: plugin, post: banners.post)
    private lazy var answers = Answers(plugin: plugin, post: banners.post)
    /// Quitting, waiting on the answers (`applicationShouldTerminate`).
    private var quitting: Task<Void, Never>?
    private let feed = Feed()
    /// The plugin folder `watch` runs on; nil before it first starts.
    private var watching: String?
    private let preferences = Preferences(.standard, snoozeFile: .live)
    private let hereFile = HereFile.live
    private let sounds = AlertSounds.live
    private let live = LiveBoard()
    private var menu: StatusMenu?
    private var edge: Edge?
    private let about = AboutWindow()
    private lazy var services = makeServices()
    private lazy var settings = SettingsWindow(
        settings: SettingsModel(preferences: preferences, live: live, services: services)
    )
    /// Made as it first opens: by itself at the first start, on a Mac where none has closed, or from Show Welcome
    /// Window. A Mac long welcomed makes none until Lee asks for it.
    private var welcome: WelcomeWindow?
    private var quitOnSignal: QuitOnSignal?

    /// The notices helper is listened to before launching ends, so a click or a banner's answer that starts the app is
    /// heard; and a SIGTERM quits as Quit SitRep does.
    func applicationWillFinishLaunching(_ notification: Notification) {
        quitOnSignal = QuitOnSignal()
        banners.start(
            onClick: { [works] work, handBack in works.jump(to: work, handBack: handBack) },
            onAnswer: { [answers, live] in answers.send($0, on: live.last.board) }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = AppMenu.make()

        let edge = Edge(
            preferences,
            jump: { [works] session, answered in works.jump(to: session, answered: answered) },
            snoozes: snoozes,
            answers: answers
        )
        let menu = StatusMenu(
            works: works, preferences: preferences, openSettings: { [unowned self] in settings.show() },
            openAbout: { [about] in about.show() },
            openWelcome: { [unowned self] in openWelcome() }
        )

        works.heard = { [weak edge] in edge?.heard($0) }
        works.notHereChanged = { [weak edge, weak menu] notHere in
            edge?.show(notHere: notHere)
            menu?.show(notHere: notHere)
        }
        self.edge = edge
        self.menu = menu
        plugin.start { [unowned self] in settled($0) }
        if WelcomeWindow.opensAtStart(preferences) {
            openWelcome()
        }
    }

    /// Each look at the plugin: `watch` started on its folder, again only as the folder moves, and the menu speaking
    /// up with any trouble; with no plugin to run yet, everything that shows the board says why.
    private func settled(_ standing: PluginStanding) {
        live.plugin = standing
        if let folder = standing.folder {
            menu?.speak(of: standing.trouble)
            if folder != watching {
                watching = folder
                works.watchStarted()
                feed.start(plugin.cli(at: folder)) { [unowned self] in heard($0) }
            }
        } else if let trouble = standing.trouble, watching == nil {
            edge?.unrun(trouble.line)
            menu?.unrun(trouble)
            works.unrun(trouble.line)
        }
    }

    /// An answer held at quitting goes before the app does, as leaving the notch never cancels one (DESIGN,
    /// "Answering, with two seconds to undo"): sent at once, the app quitting once the CLI is done with it and with
    /// any gone before, within the CLI's time limit. Asked again meanwhile, it waits on the same.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard quitting == nil else {
            return .terminateLater
        }
        guard answers.isAnswering else {
            return .terminateNow
        }

        quitting = Task {
            await answers.finish()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    /// `watch` stops with the app, `here.json` goes with it, waited on a second at most, so no board in a terminal reads
    /// a SitRep no longer running, and a welcome open closes as its close button would close it, which quitting never
    /// tells it.
    func applicationWillTerminate(_ notification: Notification) {
        feed.stop()
        hereFile.remove()
        welcome?.closeIfOpen()
    }

    /// The welcome at its first step, made as it first opens.
    private func openWelcome() {
        let welcome = welcome ?? WelcomeWindow(
            welcome: WelcomeModel(preferences: preferences, live: live, services: welcomeServices(), mac: .live)
        )

        self.welcome = welcome
        welcome.show()
    }

    /// Settings' services, with sounds of the welcome's own, so stopping them never cuts off a new ask's.
    private func welcomeServices() -> SettingsServices {
        var services = services

        services.sounds = .live
        return services
    }

    /// Each board, to everything that shows it, and then to the jump, whose read of here dims rows on the board they
    /// already show; the sound Lee chose, once for the asks new on it, or for the sessions it moved into his turn, and
    /// a notification for each, each while Lee has it on.
    private func heard(_ last: LastBoard) {
        live.last = last
        edge?.show(last)
        menu?.show(last)
        works.show(last)

        Chime.due(last, preferences.app).map(sounds.play)
        Notices.due(last, preferences.app).forEach(banners.post)
    }

    /// ⌘,, through the main menu: the Settings window.
    @objc func showSettings(_ sender: Any?) {
        settings.show()
    }

    private func makeServices() -> SettingsServices {
        SettingsServices(
            displays: {
                Displays.named.enumerated().map { DisplayChoice.Connected(id: $1.id, name: $1.name, isMain: $0 == 0) }
            },
            hasGlass: Self.hasGlass,
            jump: { [works] in works.jump(to: $0) },
            sendTest: { [banners] in banners.post(Notices.test) },
            copy: { words in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(words, forType: .string)
            },
            sounds: sounds,
            noticeLeave: { [banners] in await banners.leave() },
            askForNotices: { [banners] in await banners.ask() },
            login: { Leaves.login },
            chooseLogin: { [banners] in Leaves.chooseLogin(banners) },
            ghostty: { await Leaves.ghostty() },
            allowGhostty: { await Leaves.allowGhostty() },
            open: { Leaves.open($0) }
        )
    }

    private static var hasGlass: Bool {
        if #available(macOS 26, *) {
            true
        } else {
            false
        }
    }
}
