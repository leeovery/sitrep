import AppKit

/// The app's main menu, which an accessory app never shows: it is there for its key equivalents, which AppKit sends
/// along the responder chain from whichever SitRep window is key. The app's own Settings… to the app's delegate,
/// which brings the Settings window forward; Edit's to the first responder; Go's to the SitRep window's own, which
/// goes back and forward as its toolbar's Back and Forward do; Window's to the window. No About SitRep, which the menu
/// bar item's header opens, and no Quit: ⌘Q aimed at another app must not quit SitRep through its window, and Quit
/// stays in the menu bar item's menu.
enum AppMenu {
    /// An item, as data: its title, what it sends, and its key with the modifiers beyond ⌘.
    struct Item: Equatable {
        let title: String
        let action: Selector
        let key: String
        var modifiers: NSEvent.ModifierFlags = []
    }

    static let app = [
        Item(title: "Settings…", action: #selector(AppDelegate.showSettings(_:)), key: ","),
    ]

    static let edit = [
        Item(title: "Undo", action: Selector(("undo:")), key: "z"),
        Item(title: "Redo", action: Selector(("redo:")), key: "z", modifiers: .shift),
        Item(title: "Cut", action: #selector(NSText.cut(_:)), key: "x"),
        Item(title: "Copy", action: #selector(NSText.copy(_:)), key: "c"),
        Item(title: "Paste", action: #selector(NSText.paste(_:)), key: "v"),
        Item(title: "Select All", action: #selector(NSText.selectAll(_:)), key: "a"),
    ]

    static let go = [
        Item(title: "Back", action: #selector(SitRepWindow.goBack(_:)), key: "["),
        Item(title: "Forward", action: #selector(SitRepWindow.goForward(_:)), key: "]"),
    ]

    static let window = [
        Item(title: "Close", action: #selector(NSWindow.performClose(_:)), key: "w"),
        Item(title: "Minimise", action: #selector(NSWindow.performMiniaturize(_:)), key: "m"),
    ]

    /// The menu, its items sent along the responder chain. AppKit takes the first submenu for the app's own, so
    /// SitRep's stands there, ahead of Edit.
    @MainActor
    static func make() -> NSMenu {
        let menu = NSMenu()

        for (title, items) in [("SitRep", app), ("Edit", edit), ("Go", go), ("Window", window)] {
            let submenu = NSMenu(title: title)

            for item in items {
                let made = NSMenuItem(title: item.title, action: item.action, keyEquivalent: item.key)

                made.keyEquivalentModifierMask = item.modifiers.union(.command)
                submenu.addItem(made)
            }
            menu.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = submenu
        }
        return menu
    }
}
