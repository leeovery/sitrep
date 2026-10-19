import AppKit
import SitRepPanel

/// The spike's section of the menu bar's menu: Lee's dials, which form shows, what it is made of and which
/// notch, the strip's length and its longest, whether to reduce motion, whether anything needs him, a new ask to
/// watch land, and nothing running, for the strip.
@MainActor
final class PanelMenu: NSObject {
    private let panels: SidePanels
    private let dials: PanelDials
    private let settings: PanelSettingsWindow
    private let needsItem = NSMenuItem(title: "Something needs you", action: #selector(toggleNeeds), keyEquivalent: "")
    private let reduceMotionItem = NSMenuItem(
        title: "Reduce motion", action: #selector(toggleReduceMotion), keyEquivalent: ""
    )
    private let nothingItem = NSMenuItem(
        title: "Simulate nothing running", action: #selector(toggleNothing), keyEquivalent: ""
    )

    init(panels: SidePanels, dials: PanelDials, settings: PanelSettingsWindow) {
        self.panels = panels
        self.dials = dials
        self.settings = settings
        super.init()

        needsItem.target = self
        reduceMotionItem.target = self
        nothingItem.target = self
        needsItem.state = panels.needsLee ? .on : .off
    }

    private(set) lazy var items: [NSMenuItem] = [
        action("Panel settings…", #selector(showSettings)),
        choices("Show", PanelForm.allCases, \.name, #selector(chooseForm(_:))),
    ] + materials + [
        choices("Style", NotchStyle.allCases, \.name, #selector(chooseStyle(_:))),
        choices("Length", StripLength.allCases, \.name, #selector(chooseLength(_:))),
        longest,
        reduceMotionItem,
        needsItem,
        action("Simulate a new ask", #selector(simulateAsk)),
        nothingItem,
    ]

    /// What the form shown is made of, offered only where the Mac has glass.
    private var materials: [NSMenuItem] {
        guard PanelMaterial.isOffered else {
            return []
        }

        return [choices("Material", PanelMaterial.allCases, \.name, #selector(chooseMaterial(_:)))]
    }

    /// The strip's Max: Full, or as many marks as the screen holds short of it, made afresh as it opens, since the
    /// screen and Room decide how many that is.
    private lazy var longest: NSMenuItem = {
        let item = NSMenuItem(title: "Max", action: nil, keyEquivalent: "")
        item.submenu = NSMenu()
        item.submenu?.delegate = self
        return item
    }()

    /// A submenu of choices, ticked as the menu opens, since the settings window can choose too.
    private func choices<Choice>(
        _ title: String, _ all: [Choice], _ name: KeyPath<Choice, String>, _ selector: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()

        menu.items = options(all, name, selector)
        item.submenu = menu

        return item
    }

    private func options<Choice>(
        _ all: [Choice], _ name: KeyPath<Choice, String>, _ selector: Selector
    ) -> [NSMenuItem] {
        all.map { choice in
            let option = action(choice[keyPath: name], selector)

            option.representedObject = choice

            return option
        }
    }

    @objc private func showSettings() {
        settings.show()
    }

    @objc private func chooseForm(_ sender: NSMenuItem) {
        if let form = sender.representedObject as? PanelForm {
            dials.show = form
        }
    }

    @objc private func chooseMaterial(_ sender: NSMenuItem) {
        if let material = sender.representedObject as? PanelMaterial {
            dials.material = material
        }
    }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        if let style = sender.representedObject as? NotchStyle {
            dials.style = style
        }
    }

    @objc private func chooseLength(_ sender: NSMenuItem) {
        if let length = sender.representedObject as? StripLength {
            dials.strip.length = length
        }
    }

    @objc private func chooseMax(_ sender: NSMenuItem) {
        if let max = sender.representedObject as? StripMax {
            dials.strip.maxMarks = max.marks
        }
    }

    @objc private func toggleReduceMotion() {
        dials.reduceMotion.toggle()
    }

    @objc private func toggleNeeds() {
        panels.needsLee.toggle()
        needsItem.state = panels.needsLee ? .on : .off
    }

    @objc private func simulateAsk() {
        panels.newAsk()
        needsItem.state = .on
    }

    @objc private func toggleNothing() {
        panels.nothingRunning.toggle()
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")

        item.target = self

        return item
    }
}

/// One of Max's choices: Full, kept as 0, or a number of marks.
private struct StripMax {
    let marks: Double

    var name: String { StripDial.max.show(marks) }
}

extension PanelMenu: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        let most = dials.strip.longest(on: Display.edge.stripStage)
        let all = [StripMax(marks: 0)] + (5 ..< most).map { StripMax(marks: Double($0)) }
        menu.items = options(all, \.name, #selector(chooseMax(_:)))
    }
}

extension PanelMenu: NSMenuItemValidation {
    /// The form shown, its material, the notch chosen, the strip's length and Max, SitRep's own Reduce motion and
    /// nothing running are ticked; Max is the strip's at Grows alone.
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item === reduceMotionItem {
            item.state = dials.reduceMotion ? .on : .off
        }
        if item === nothingItem {
            item.state = panels.nothingRunning ? .on : .off
        }
        switch item.representedObject {
        case let form as PanelForm:
            item.state = form == dials.show ? .on : .off
        case let material as PanelMaterial:
            item.state = material == dials.material ? .on : .off
        case let style as NotchStyle:
            item.state = style == dials.style ? .on : .off
        case let length as StripLength:
            item.state = length == dials.strip.length ? .on : .off
        case let max as StripMax:
            item.state = max.marks == dials.strip.maxMarks ? .on : .off
            return dials.strip.length == .grows
        default:
            break
        }

        return true
    }
}
