import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let banners = Banners()
    private let sitrep = Plugin.cli()
    private lazy var works = Works(banners: banners, sitrep: sitrep)
    private let feed = Feed()
    private var menu: StatusMenu?
    private var edge: Edge?

    /// Banners are listened to before launching ends, so a click that starts the app is heard.
    func applicationWillFinishLaunching(_ notification: Notification) {
        banners.listen { [works] work in works.jump(to: work) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let edge = Edge { [works] session, answered in works.jump(to: session, answered: answered) }

        menu = StatusMenu(works: works, banners: banners)
        self.edge = edge
        if let sitrep {
            feed.start(sitrep) { edge.show($0) }
        }
    }

    /// `watch` stops with the app.
    func applicationWillTerminate(_ notification: Notification) {
        feed.stop()
    }
}
