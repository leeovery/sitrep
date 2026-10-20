import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let banners = Banners()
    private let sitrep = Plugin.cli()
    private lazy var works = Works(banners: banners, sitrep: sitrep)
    private let feed = Feed()
    private var menu: StatusMenu?
    private var edge: Edge?
    private lazy var window = SitRepWindow(sitrep: sitrep, works: works)

    /// Banners are listened to before launching ends, so a click that starts the app is heard.
    func applicationWillFinishLaunching(_ notification: Notification) {
        banners.listen { [works] work in works.jump(to: work) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = AppMenu.make()

        let edge = Edge(
            jump: { [works] session, answered in works.jump(to: session, answered: answered) },
            isJumping: { [works] in works.isJumping }
        )

        menu = StatusMenu(works: works, banners: banners) { [window] in window.open() }
        self.edge = edge
        if let sitrep {
            feed.start(sitrep) { [window] in
                edge.show($0)
                window.show($0)
            }
        } else {
            edge.unrun(Plugin.unbuilt)
            window.unrun(Plugin.unbuilt)
        }
    }

    /// `watch` stops with the app.
    func applicationWillTerminate(_ notification: Notification) {
        feed.stop()
    }
}
