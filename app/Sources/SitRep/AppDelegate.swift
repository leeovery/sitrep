import AppKit
import SitRepCore
import SitRepMenu
import SitRepWindow

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let banners = Banners.live()
    private let plugin = Plugin()
    private lazy var works = Works(banners: banners, plugin: plugin)
    private lazy var snoozes = Snoozes(plugin: plugin, banners: banners)
    private let feed = Feed()
    /// The plugin folder `watch` runs on; nil before it first starts.
    private var watching: String?
    private let preferences = Preferences()
    private let sounds = AlertSounds.live
    private let live = LiveBoard()
    private var menu: StatusMenu?
    private var edge: Edge?
    private let about = AboutWindow()
    private lazy var settings = SettingsWindow(
        settings: SettingsModel(preferences: preferences, live: live, services: makeServices())
    )
    private lazy var window = SitRepWindow(
        plugin: plugin, works: works, snoozes: snoozes, following: feed.following, preferences: preferences,
        openSettings: { [unowned self] in settings.show() }
    )

    /// The notices helper is listened to before launching ends, so a click that starts the app is heard.
    func applicationWillFinishLaunching(_ notification: Notification) {
        banners.start { [works] work, refused in works.jump(to: work, refused: refused) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = AppMenu.make()

        let edge = Edge(
            preferences,
            jump: { [works] session, answered in works.jump(to: session, answered: answered) },
            isJumping: { [works] in works.isJumping },
            open: { [window] in window.open(on: .session($0)) },
            snoozes: snoozes
        )
        let menu = StatusMenu(
            works: works, preferences: preferences, openWindow: { [window] in window.open() },
            openSettings: { [unowned self] in settings.show() }, openAbout: { [about] in about.show() }
        )

        self.edge = edge
        self.menu = menu
        plugin.start { [unowned self] in settled($0) }
    }

    /// Each look at the plugin: `watch` started on its folder, again only as the folder moves, and the menu speaking
    /// up with any trouble; with no plugin to run yet, everything that shows the board says why.
    private func settled(_ standing: PluginStanding) {
        live.plugin = standing
        if let folder = standing.folder {
            menu?.speak(of: standing.trouble)
            if folder != watching {
                watching = folder
                feed.start(plugin.cli(at: folder)) { [unowned self] in heard($0) }
            }
        } else if let trouble = standing.trouble, watching == nil {
            edge?.unrun(trouble.line)
            menu?.unrun(trouble)
            window.unrun(trouble.line)
        }
    }

    /// `watch` stops with the app.
    func applicationWillTerminate(_ notification: Notification) {
        feed.stop()
    }

    /// Each board, to everything that shows it; the sound Lee chose, once for the asks new on it, and a notification
    /// for each, in core's order, each while Lee has it on.
    private func heard(_ last: LastBoard) {
        live.last = last
        edge?.show(last)
        menu?.show(last)
        window.show(last)

        Chime.due(last, preferences.app).map(sounds.play)
        Notices.due(last, isOn: preferences.app.notifiesNewAsks).forEach(banners.post)
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
