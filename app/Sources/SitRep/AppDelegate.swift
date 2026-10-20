import AppKit
import SitRepCore
import SitRepMenu

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let banners = Banners()
    private let sitrep = Plugin.cli()
    private lazy var works = Works(banners: banners, sitrep: sitrep)
    private let feed = Feed()
    private let preferences = Preferences()
    private let live = LiveBoard()
    private var menu: StatusMenu?
    private var edge: Edge?
    private var settings: SettingsWindow?
    private lazy var window = SitRepWindow(sitrep: sitrep, works: works)

    /// Banners are listened to before launching ends, so a click that starts the app is heard.
    func applicationWillFinishLaunching(_ notification: Notification) {
        banners.listen { [works] work in works.jump(to: work) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = AppMenu.make()

        let edge = Edge(
            preferences,
            jump: { [works] session, answered in works.jump(to: session, answered: answered) },
            isJumping: { [works] in works.isJumping }
        )
        let settings = SettingsWindow(preferences: preferences, live: live, services: services())
        let menu = StatusMenu(
            works: works, preferences: preferences, openWindow: { [window] in window.open() },
            openSettings: { settings.show() }
        )

        self.edge = edge
        self.settings = settings
        self.menu = menu
        if let sitrep {
            feed.start(sitrep) { [unowned self] in heard($0) }
        } else {
            live.unrun = Plugin.unbuilt
            edge.unrun(Plugin.unbuilt)
            menu.unrun(Plugin.unbuilt)
            window.unrun(Plugin.unbuilt)
        }
    }

    /// `watch` stops with the app.
    func applicationWillTerminate(_ notification: Notification) {
        feed.stop()
    }

    /// Each board, to everything that shows it, and a notification for each ask new on it, in core's order, while Lee
    /// has them on.
    private func heard(_ last: LastBoard) {
        live.last = last
        edge?.show(last)
        menu?.show(last)
        window.show(last)

        let notices = Notices.due(last, isOn: preferences.app.notifiesNewAsks)

        if !notices.isEmpty {
            Task { [banners] in
                for notice in notices {
                    await banners.post(notice)
                }
            }
        }
    }

    private func services() -> SettingsServices {
        SettingsServices(
            displays: {
                Displays.named.enumerated().map { DisplayChoice.Connected(id: $1.id, name: $1.name, isMain: $0 == 0) }
            },
            hasGlass: Self.hasGlass,
            pluginFolder: Plugin.folder.map { ($0 as NSString).abbreviatingWithTildeInPath },
            jump: { [works] in works.jump(to: $0) },
            sendTest: { [banners, live] in Task { await banners.post(Notices.test(live.last)) } },
            noticeLeave: { [banners] in await banners.leave() },
            askForNotices: { [banners] in await banners.ask() },
            login: { Leaves.login },
            chooseLogin: { [banners] in Leaves.chooseLogin(banners) },
            ghostty: { await Leaves.ghostty() },
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
