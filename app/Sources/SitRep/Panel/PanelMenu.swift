import AppKit

/// The spike's section of the menu bar's menu: Lee's dials, whether anything needs him, and a new ask to watch land.
@MainActor
final class PanelMenu: NSObject {
    private let panel: PanelController
    private let settings: PanelSettingsWindow
    private let needsItem = NSMenuItem(title: "Something needs you", action: #selector(toggleNeeds), keyEquivalent: "")

    init(panel: PanelController, settings: PanelSettingsWindow) {
        self.panel = panel
        self.settings = settings
        super.init()

        needsItem.target = self
        needsItem.state = panel.needsLee ? .on : .off
    }

    private(set) lazy var items: [NSMenuItem] = [
        action("Panel settings…", #selector(showSettings)),
        needsItem,
        action("Simulate a new ask", #selector(simulateAsk)),
    ]

    @objc private func showSettings() {
        settings.show()
    }

    @objc private func toggleNeeds() {
        panel.needsLee.toggle()
        needsItem.state = panel.needsLee ? .on : .off
    }

    @objc private func simulateAsk() {
        panel.newAsk()
        needsItem.state = .on
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")

        item.target = self

        return item
    }
}
