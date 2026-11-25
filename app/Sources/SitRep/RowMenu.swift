import AppKit
import SitRepCore
import SitRepPanel

/// The menu a right-click on a session's row on the card brings up, as Paper's boards F and G have it: Jump to the
/// window, as a click on the row does, an away row's carrying its session on; then, after a separator, Snooze, its
/// times and Until it moves, on a Needs you row, its asks' or its turn's, which puts off everything the session needs
/// of Lee (13 November 2026), or Wake now on a row in Snoozed. A row of stops alone, or a working one, offers neither. The asks a snooze
/// names are those the row showed as it was drawn, never read again, so an ask that landed since is never snoozed
/// unseen: the CLI refuses it.
@MainActor
enum RowMenu {
    /// What a row offers.
    struct Row: Equatable {
        /// The asks its Snooze names, those it shows, none on a turn's row; nil where it offers neither Snooze nor Wake
        /// now, on a row of stops alone, or a working one.
        let asks: [String]?
        let isSnoozed: Bool
    }

    /// What each choice does: the snooze of the row's session, naming the asks it showed, until the time its item
    /// showed, worked out as the menu opened, or with none until it moves; the wake of its session.
    struct Actions {
        var jump: () -> Void
        var snooze: ([String], Date?) -> Void
        var wake: () -> Void
    }

    private static let jumpTitle = "Jump to the window"
    static let snoozeTitle = "Snooze"
    private static let wakeTitle = "Wake now"

    /// Its Snooze offers the choices `settings` offer at `now`.
    static func make(
        for row: Row, at now: Date, in calendar: Calendar, offering settings: SnoozeSettings, _ actions: Actions
    ) -> NSMenu {
        let menu = NSMenu()

        menu.autoenablesItems = false
        menu.addItem(ActionItem(jumpTitle, run: actions.jump))
        if let asks = row.asks {
            menu.addItem(.separator())
            menu.addItem(
                row.isSnoozed
                    ? ActionItem(wakeTitle, run: actions.wake)
                    : snooze(now, calendar, settings) { actions.snooze(asks, $0) }
            )
        }
        return menu
    }

    /// Snooze, its times offered at `now` as `settings` set them, in a menu of their own.
    private static func snooze(
        _ now: Date, _ calendar: Calendar, _ settings: SnoozeSettings, _ choose: @escaping (Date?) -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: snoozeTitle, action: nil, keyEquivalent: "")

        item.submenu = SnoozeMenu(offering: settings, at: now, in: calendar, choose: choose)
        return item
    }
}

extension RowMenu.Row {
    /// A row on the card: in Needs you, its asks', none on its turn's; in Snoozed, to wake; none on a row of stops alone
    /// or a working one.
    init(_ session: Session) {
        let offers = session.isSnoozed || session.isTurn || !session.asks.isEmpty

        self.init(asks: offers ? session.asks : nil, isSnoozed: session.isSnoozed)
    }
}

/// Snooze's times, each with when it would wake at the right, dimmer than its name, and brighter as it is highlighted
/// (board G), on a right tab stop, as AppKit's menus set no second label at the right of their own; on a row's,
/// Until it moves after a separator, with no time, or alone where Lee switched every time off. The menu is its own
/// delegate, to brighten the time highlighted. Each time is worked out once, as the menu opens: chosen, it hands on
/// the time it shows, none for Until it moves, so what is snoozed to is what Lee saw, though the clock or the zone
/// moved while the menu stood open.
@MainActor
final class SnoozeMenu: NSMenu, NSMenuDelegate {
    private let choices: [SnoozeTime]
    private let times: [String]

    /// The times `settings` offer at `now`, then Until it moves: a row's.
    convenience init(
        offering settings: SnoozeSettings, at now: Date, in calendar: Calendar, choose: @escaping (Date?) -> Void
    ) {
        let times = SnoozeTime.offered(at: now, in: calendar, settings: settings)

        self.init(times, settings, at: now, in: calendar, choose)
    }

    /// The times `settings` offer at `now` alone: one ask's, as the pane offers them, each snoozing until its time.
    static func forAsk(
        offering settings: SnoozeSettings, at now: Date, in calendar: Calendar, choose: @escaping (Date) -> Void
    ) -> SnoozeMenu {
        let times = SnoozeTime.offeredForAsk(at: now, in: calendar, settings: settings)

        return SnoozeMenu(times, settings, at: now, in: calendar) { $0.map(choose) }
    }

    private init(
        _ choices: [SnoozeTime], _ settings: SnoozeSettings, at now: Date, in calendar: Calendar,
        _ choose: @escaping (Date?) -> Void
    ) {
        let untils = choices.map { $0.wakes(after: now, in: calendar, settings: settings) }

        self.choices = choices
        times = zip(choices, untils).map { time, until in
            guard case let .at(choice) = time, let until else {
                return ""
            }

            return WakeTime.besideChoice(choice, wakes: until, in: calendar)
        }
        super.init(title: RowMenu.snoozeTitle)
        autoenablesItems = false
        delegate = self
        for (choice, until) in zip(choices, untils) {
            if choice == .untilItMoves, !items.isEmpty {
                addItem(.separator())
            }
            addItem(ActionItem(choice.title) { choose(until) })
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

    init(_ title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(chosen), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func chosen() {
        run()
    }
}
