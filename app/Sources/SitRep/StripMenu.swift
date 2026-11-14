import AppKit
import SitRepPanel

/// The menus a right-click on the strip brings up (14 November 2026): on a session's mark, or its row on a tab, the
/// menu its row gives on the card (`RowMenu`), with the fold of the section the strip has it in at its foot after a
/// separator, Collapse it, or Expand it where it is folded, as on its folded count's tab; on a section's count folded,
/// Expand the section; on a count past its section's room, Collapse it. Collapsing or expanding folds the section on
/// the card as well.
@MainActor
enum StripMenu {
    static func make(
        for target: StripTarget, at now: Date, in calendar: Calendar, row actions: (Session) -> RowMenu.Actions,
        fold: @escaping (BoardSection, Bool) -> Void
    ) -> NSMenu {
        switch target {
        case let .session(session, section, isFolded):
            let menu = RowMenu.make(for: RowMenu.Row(session), at: now, in: calendar, actions(session))

            menu.addItem(.separator())
            menu.addItem(item(section, folds: !isFolded, fold))
            return menu
        case let .count(section, isFolded):
            let menu = NSMenu()

            menu.autoenablesItems = false
            menu.addItem(item(section, folds: !isFolded, fold))
            return menu
        }
    }

    /// Collapse a section, or Expand it.
    private static func item(
        _ section: BoardSection, folds: Bool, _ fold: @escaping (BoardSection, Bool) -> Void
    ) -> NSMenuItem {
        ActionItem("\(folds ? "Collapse" : "Expand") \(section.title)") { fold(section, folds) }
    }
}
