import AppKit

/// The spike's section of the menu bar's menu: Lee's dials, which notch, whether anything needs him, and a new ask to
/// watch land.
@MainActor
final class PanelMenu: NSObject {
    private let panel: PanelController
    private let dials: PanelDials
    private let settings: PanelSettingsWindow
    private let needsItem = NSMenuItem(title: "Something needs you", action: #selector(toggleNeeds), keyEquivalent: "")

    init(panel: PanelController, dials: PanelDials, settings: PanelSettingsWindow) {
        self.panel = panel
        self.dials = dials
        self.settings = settings
        super.init()

        needsItem.target = self
        needsItem.state = panel.needsLee ? .on : .off
    }

    private(set) lazy var items: [NSMenuItem] = [
        action("Panel settings…", #selector(showSettings)),
        styleItem,
        needsItem,
        action("Simulate a new ask", #selector(simulateAsk)),
    ]

    /// Meniscus or Card, ticked as the menu opens, since the settings window can choose too.
    private lazy var styleItem: NSMenuItem = {
        let item = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let menu = NSMenu()

        menu.items = NotchStyle.allCases.map { style in
            let choice = action(style.name, #selector(chooseStyle(_:)))

            choice.representedObject = style.rawValue

            return choice
        }
        item.submenu = menu

        return item
    }()

    @objc private func showSettings() {
        settings.show()
    }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        if let style = Self.style(of: sender) {
            dials.style = style
        }
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

    private static func style(of item: NSMenuItem) -> NotchStyle? {
        (item.representedObject as? String).flatMap(NotchStyle.init)
    }
}

extension PanelMenu: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if let style = Self.style(of: item) {
            item.state = style == dials.style ? .on : .off
        }

        return true
    }
}
