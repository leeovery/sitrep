import SitRepEdge
import SitRepMenu

/// What the shortcut opens on the notch's side: the panel, while the notch shows, and what its hold lets through.
@MainActor
protocol ShortcutNotch: AnyObject {
    /// The shortcut: whether the notch took it.
    func summon() -> Bool
    /// The shortcut's chord as macOS holds it, which the panel's hold lets through.
    func hotKey(_ chord: TapChord?)
    func closePanel()
}

/// The menu bar item's menu, as the shortcut opens and closes it.
@MainActor
protocol ShortcutMenu: AnyObject {
    var isOpen: Bool { get }
    /// Told as the menu opens.
    var onOpen: () -> Void { get set }
    func open()
    func close()
}

/// The shortcut joined to what it opens (DESIGN, "Keys"): the notch's hold told the chord macOS holds as it changes,
/// none while Settings records, it is cleared or macOS refused it; the notch's panel closed as the menu opens, which has
/// the keys from then; and each press routed: with the menu open, it closes the menu and does nothing else; else the
/// notch's panel, while the notch shows, or the menu, as under Nothing or with a full-screen app hiding the notch.
@MainActor
final class ShortcutWiring {
    private let notch: any ShortcutNotch
    private let menu: any ShortcutMenu

    init(_ hotKey: HotKey, notch: any ShortcutNotch, menu: any ShortcutMenu) {
        self.notch = notch
        self.menu = menu
        notch.hotKey(hotKey.registered?.tapChord)
        hotKey.onRegistered = { [weak notch] in notch?.hotKey($0?.tapChord) }
        menu.onOpen = { [weak notch] in notch?.closePanel() }
    }

    func press() {
        if menu.isOpen {
            menu.close()
        } else if !notch.summon() {
            menu.open()
        }
    }
}
