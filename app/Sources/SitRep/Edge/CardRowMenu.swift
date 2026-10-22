import AppKit
import SitRepPanel
import enum SitRepWindow.Words

/// The menu a right-click on a card's row brings up, as Paper's board F has it: Open in SitRep, which opens its
/// session in the SitRep window, as its button does; and Jump to the window, as a click on it does, disabled on an away
/// row, which no window holds. Each item carries the session, by its id.
@MainActor
enum CardRowMenu {
    static func make(for session: Session, target: AnyObject, open: Selector, jump: Selector) -> NSMenu {
        let menu = NSMenu()

        menu.autoenablesItems = false
        menu.addItem(item(Words.openInSitRep, session, target, open, isEnabled: true))
        menu.addItem(item(Words.jumpToWindow, session, target, jump, isEnabled: session.jumps))
        return menu
    }

    private static func item(
        _ title: String, _ session: Session, _ target: AnyObject, _ action: Selector, isEnabled: Bool
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")

        item.target = target
        item.representedObject = session.id
        item.isEnabled = isEnabled
        return item
    }
}
