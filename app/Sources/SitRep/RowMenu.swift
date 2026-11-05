import AppKit
import SitRepCore
import SitRepPanel

/// The menu a right-click on a session's row on the card brings up, as Paper's boards F and G have it: Jump to the
/// window, as a click on the row does, disabled on an away row, which no window holds; then, after a separator, Snooze
/// and its times on a row whose lines hold asks, those and Until it moves on a your-turn row, as board I's menu has
/// it, or Wake now on a row in Snoozed. A row of stops alone, or a working one, offers neither. What it snoozes or
/// wakes is what the row showed as it was drawn, never read again: its asks, so an ask that landed since is never
/// snoozed unseen, or its turn by the turn's end, so a turn ended since is never snoozed in its place.
@MainActor
enum RowMenu {
    /// What a row offers.
    struct Row: Equatable {
        let jumps: Bool
        /// What its Snooze puts off, or its Wake now brings back; none on a row of stops alone, or a working one.
        let snoozable: Snoozable?
        let isSnoozed: Bool
    }

    /// What each choice does: the snooze of what the row showed, with the time chosen, worked out as it is pressed;
    /// the wake of what it showed asleep.
    struct Actions {
        var jump: () -> Void
        var snooze: (Snoozable, SnoozeTime) -> Void
        var wake: (Snoozable) -> Void
    }

    private static let jumpTitle = "Jump to the window"
    static let snoozeTitle = "Snooze"
    private static let wakeTitle = "Wake now"

    static func make(for row: Row, at now: Date, in calendar: Calendar, _ actions: Actions) -> NSMenu {
        let menu = NSMenu()

        menu.autoenablesItems = false
        menu.addItem(ActionItem(jumpTitle, isEnabled: row.jumps, run: actions.jump))
        if let snoozable = row.snoozable {
            menu.addItem(.separator())
            menu.addItem(
                row.isSnoozed
                    ? ActionItem(wakeTitle) { actions.wake(snoozable) }
                    : snooze(SnoozeTime.offered(forTurn: snoozable.isTurn), now, calendar) { actions.snooze(snoozable, $0) }
            )
        }
        return menu
    }

    /// Snooze, its times in a menu of their own.
    private static func snooze(
        _ times: [SnoozeTime], _ now: Date, _ calendar: Calendar, _ choose: @escaping (SnoozeTime) -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: snoozeTitle, action: nil, keyEquivalent: "")

        item.submenu = SnoozeMenu(times, at: now, in: calendar, choose: choose)
        return item
    }
}

extension RowMenu.Row {
    /// A row on the card: its turn, by the turn's end, its time, on Your turn or in Snoozed; else its asks.
    init(_ session: Session) {
        let ended = Date(timeIntervalSince1970: session.since / 1000)

        self.init(
            jumps: session.jumps, snoozable: .of(isTurn: session.isTurn, ended: ended, asks: session.asks),
            isSnoozed: session.isSnoozed
        )
    }
}

/// Snooze's times, each with when it would wake at the right, dimmer than its name, and brighter as it is highlighted
/// (board G), on a right tab stop, as AppKit's menus set no second label at the right of their own; Until it moves, a
/// turn's, after a separator, with no time. The menu is its own delegate, to brighten the time highlighted.
@MainActor
final class SnoozeMenu: NSMenu, NSMenuDelegate {
    private let choices: [SnoozeTime]
    private let times: [String]

    init(_ choices: [SnoozeTime], at now: Date, in calendar: Calendar, choose: @escaping (SnoozeTime) -> Void) {
        self.choices = choices
        times = choices.map { $0.wakes(after: now, in: calendar).map { WakeTime.words($0, at: now, in: calendar) } ?? "" }
        super.init(title: RowMenu.snoozeTitle)
        autoenablesItems = false
        delegate = self
        for choice in choices {
            if choice == .untilItMoves {
                addItem(.separator())
            }
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

    /// Each choice's name and time, the time brighter on the one highlighted; Until it moves its name alone.
    private func highlight(_ lit: NSMenuItem?) {
        let names = choices.map(\.title)
        let paragraph = NSMutableParagraphStyle()

        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: Self.widest(names) + Self.gap + Self.widest(times))]
        for (item, (name, time)) in zip(items.filter { !$0.isSeparatorItem }, zip(names, times)) {
            let words = [NSAttributedString.Key.font: Self.font, .paragraphStyle: paragraph]
            let title = NSMutableAttributedString(string: time.isEmpty ? name : "\(name)\t", attributes: words)

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
