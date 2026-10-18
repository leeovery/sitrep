import AppKit

/// The spike's section of the menu bar's menu: Lee's dials, which form shows and which notch, whether anything needs
/// him, and a new ask to watch land.
@MainActor
final class PanelMenu: NSObject {
    private let panels: SidePanels
    private let dials: PanelDials
    private let settings: PanelSettingsWindow
    private let needsItem = NSMenuItem(title: "Something needs you", action: #selector(toggleNeeds), keyEquivalent: "")

    init(panels: SidePanels, dials: PanelDials, settings: PanelSettingsWindow) {
        self.panels = panels
        self.dials = dials
        self.settings = settings
        super.init()

        needsItem.target = self
        needsItem.state = panels.needsLee ? .on : .off
    }

    private(set) lazy var items: [NSMenuItem] = [
        action("Panel settings…", #selector(showSettings)),
        choices("Show", PanelForm.allCases, \.name, #selector(chooseForm(_:))),
        choices("Style", NotchStyle.allCases, \.name, #selector(chooseStyle(_:))),
        needsItem,
        action("Simulate a new ask", #selector(simulateAsk)),
    ]

    /// A submenu of choices, ticked as the menu opens, since the settings window can choose too.
    private func choices<Choice>(
        _ title: String, _ all: [Choice], _ name: KeyPath<Choice, String>, _ selector: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()

        menu.items = all.map { choice in
            let option = action(choice[keyPath: name], selector)

            option.representedObject = choice

            return option
        }
        item.submenu = menu

        return item
    }

    @objc private func showSettings() {
        settings.show()
    }

    @objc private func chooseForm(_ sender: NSMenuItem) {
        if let form = sender.representedObject as? PanelForm {
            dials.show = form
        }
    }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        if let style = sender.representedObject as? NotchStyle {
            dials.style = style
        }
    }

    @objc private func toggleNeeds() {
        panels.needsLee.toggle()
        needsItem.state = panels.needsLee ? .on : .off
    }

    @objc private func simulateAsk() {
        panels.newAsk()
        needsItem.state = .on
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")

        item.target = self

        return item
    }
}

extension PanelMenu: NSMenuItemValidation {
    /// The form shown and the notch chosen are ticked.
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.representedObject {
        case let form as PanelForm:
            item.state = form == dials.show ? .on : .off
        case let style as NotchStyle:
            item.state = style == dials.style ? .on : .off
        default:
            break
        }

        return true
    }
}
