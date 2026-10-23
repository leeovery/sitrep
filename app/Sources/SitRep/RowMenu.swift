import AppKit
import SitRepPanel
import enum SitRepWindow.Words

/// The menu a right-click on a session's row brings up, on the card as Paper's boards F and G have it, and in the
/// sidebar as board H's: Open in SitRep, on the card, which opens the session in the SitRep window as its button does;
/// Jump to the window, as a click on the card's row does, disabled on an away row, which no window holds; then, after a
/// separator, Snooze and its times on a row whose lines hold asks, or Wake now on a row in Snoozed. A row of stops
/// alone offers neither. What it snoozes or wakes is the asks the row showed as it was drawn, never read again, so an
/// ask that landed since is never snoozed unseen.
@MainActor
enum RowMenu {
    /// What a row offers.
    struct Row: Equatable {
        let jumps: Bool
        /// The asks its lines show, by their ids.
        let asks: [String]
        let isSnoozed: Bool
    }

    /// What each choice does: the snooze with the time chosen, worked out as it is pressed.
    struct Actions {
        /// None in the SitRep window, where the row is its page already.
        var open: (() -> Void)?
        var jump: () -> Void
        var snooze: (SnoozeChoice) -> Void
        var wake: () -> Void
    }

    static func make(for row: Row, at now: Date, in calendar: Calendar, _ actions: Actions) -> NSMenu {
        let menu = NSMenu()

        menu.autoenablesItems = false
        if let open = actions.open {
            menu.addItem(ActionItem(Words.openInSitRep, run: open))
        }
        menu.addItem(ActionItem(Words.jumpToWindow, isEnabled: row.jumps, run: actions.jump))
        if !row.asks.isEmpty {
            menu.addItem(.separator())
            menu.addItem(row.isSnoozed ? ActionItem(Words.wakeNow, run: actions.wake) : snooze(now, calendar, actions.snooze))
        }
        return menu
    }

    /// Snooze, its times in a menu of their own.
    private static func snooze(_ now: Date, _ calendar: Calendar, _ choose: @escaping (SnoozeChoice) -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: Words.snooze, action: nil, keyEquivalent: "")

        item.submenu = SnoozeMenu(at: now, in: calendar, choose: choose)
        return item
    }
}

extension RowMenu.Row {
    /// A row on the card.
    init(_ session: Session) {
        self.init(jumps: session.jumps, asks: session.asks, isSnoozed: session.isSnoozed)
    }
}

/// Snooze's times, each with when it would wake at the right, dimmer than its name, and brighter as it is highlighted
/// (board G), on a right tab stop, as AppKit's menus set no second label at the right of their own. The menu is its own
/// delegate, to brighten the time highlighted.
@MainActor
final class SnoozeMenu: NSMenu, NSMenuDelegate {
    private let times: [String]

    init(at now: Date, in calendar: Calendar, choose: @escaping (SnoozeChoice) -> Void) {
        times = SnoozeChoice.allCases.map { WakeTime.words($0.wakes(after: now, in: calendar), at: now, in: calendar) }
        super.init(title: Words.snooze)
        autoenablesItems = false
        delegate = self
        for choice in SnoozeChoice.allCases {
            addItem(ActionItem(choice.title) { choose(choice) })
        }
        highlight(nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        highlight(item)
    }

    /// Each choice's name and time, the time brighter on the one highlighted.
    private func highlight(_ lit: NSMenuItem?) {
        let names = SnoozeChoice.allCases.map(\.title)
        let paragraph = NSMutableParagraphStyle()

        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: Self.widest(names) + Self.gap + Self.widest(times))]
        for (item, (name, time)) in zip(items, zip(names, times)) {
            let words = [NSAttributedString.Key.font: Self.font, .paragraphStyle: paragraph]
            let title = NSMutableAttributedString(string: "\(name)\t", attributes: words)

            title.append(NSAttributedString(
                string: time, attributes: words.merging([.foregroundColor: item === lit ? Self.lit : Self.dim]) { $1 }
            ))
            item.attributedTitle = title
        }
    }

    private static let font = NSFont.menuFont(ofSize: 0)

    private static func widest(_ words: [String]) -> CGFloat {
        words.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
    }

    /// Between the longest name and the widest time.
    private static let gap = 24.0

    /// A time, white at 45% on the menu's dark, and black at 45% on its light; highlighted, white at 70% on the accent.
    static let dim = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        return (isDark ? NSColor.white : NSColor.black).withAlphaComponent(0x73 / 255.0)
    }

    static let lit = NSColor.white.withAlphaComponent(0xB3 / 255.0)
}

/// A menu's item that runs what it is given when chosen.
@MainActor
final class ActionItem: NSMenuItem {
    private let run: () -> Void

    init(_ title: String, isEnabled: Bool = true, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(chosen), keyEquivalent: "")
        target = self
        self.isEnabled = isEnabled
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func chosen() {
        run()
    }
}
