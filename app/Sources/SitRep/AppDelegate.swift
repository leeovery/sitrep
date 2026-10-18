import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let banners = Banners()
    private lazy var works = Works(banners: banners)
    private let panelDials = PanelDials()
    private var menu: StatusMenu?
    private var panels: SidePanels?

    /// Banners are listened to before launching ends, so a click that starts the app is heard.
    func applicationWillFinishLaunching(_ notification: Notification) {
        banners.listen { [works] work in works.jump(to: work) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panels = SidePanels(dials: panelDials)
        let panelMenu = PanelMenu(panels: panels, dials: panelDials, settings: PanelSettingsWindow(dials: panelDials))

        menu = StatusMenu(works: works, banners: banners, panelMenu: panelMenu)
        self.panels = panels
    }
}
