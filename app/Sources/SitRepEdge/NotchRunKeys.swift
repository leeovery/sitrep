import CoreGraphics
import SitRepPanel

/// Whether the panel holds the keys (DESIGN, "Keys"), and whose hold it is: the pointer's, which the pointer moving on
/// the panel starts and moving off it ends, or the shortcut's, which holds every key until the panel closes, the
/// pointer's moves aside. Each hold numbered, so the tap tells the hold a key it let go of ended from the next.
struct KeyHold {
    enum Kind {
        case pointer, shortcut
    }

    private(set) var kind: Kind?
    private(set) var number = 0

    var isOn: Bool { kind != nil }

    var isShortcut: Bool { kind == .shortcut }

    /// The pointer moved, on the open list or its asks panel or off them: on, it holds; off, it holds no more. A
    /// shortcut's hold stays the shortcut's.
    mutating func moved(onPanel: Bool) {
        guard !isShortcut else {
            return
        }

        if onPanel, !isOn {
            number += 1
        }
        kind = onPanel ? .pointer : nil
    }

    /// The shortcut opened the panel: a hold of its own.
    mutating func summoned() {
        number += 1
        kind = .shortcut
    }

    mutating func end() {
        kind = nil
    }
}

/// The panel's keys in the notch's run (DESIGN, "Keys"): the hold the pointer moving on the panel starts, the lit row
/// the keys move, and what each key does there, by the paths a click takes.
extension NotchRun {
    /// What the tap decides each key by: the panel's hold while it holds the keys, `⌘Z` its while the asks panel's
    /// sending line shows, every key its in the shortcut's; else nothing.
    public var keySnapshot: KeySnapshot {
        hold.isOn
            ? .panel(hold: hold.number, undoes: asking.shown?.sending != nil, takesAll: hold.isShortcut) : .none
    }

    /// Whether the panel holds the keys.
    public var holdsKeys: Bool { hold.isOn }

    /// A key the panel doesn't take, pressed in the hold of this number: it went through, and the panel holds none
    /// until the pointer moves again; in the shortcut's hold, a key with ⌘, ⌃ or ⌥, which closes the panel. A hold the
    /// pointer began since the key keeps the keys.
    public func letGoOfKeys(in number: Int, _ moment: Moment) {
        upToNow(moment)
        guard hold.number == number else {
            return
        }

        if hold.isShortcut {
            notch.clickElsewhere()
        }
        hold.end()
    }

    /// The panel holds the keys no more, whichever hold it is, until the pointer moves again: as the screens sleep or
    /// the session goes to another user.
    public func letGoOfKeys(_ moment: Moment) {
        upToNow(moment)
        hold.end()
    }

    /// The item lit, by its index: the row the keys lit, while it shows, else the item under the pointer, which an
    /// eyebrow may be, which never lifts.
    public func lit(in setting: Setting) -> Int? {
        keyLitIndex ?? seen.flatMap { item(at: $0, in: setting) }
    }

    /// A key of the set while the panel holds the keys, open, or in the shortcut's hold opening too, acting on the lit
    /// row as its click would: on the asks panel while it is open (`asksKey`), else on the list (`listKey`). A key with
    /// no use at the moment does nothing, as does one heard while a menu holds the card, the menu's. `o` ends the hold
    /// whether or not it jumps, as the tap ended it as it took `o` (`KeyReader`), so the keys typed after it go to the
    /// window in front, and the shortcut's panel closes where it didn't jump; but for `o` while the sending line shows,
    /// where it can't jump, which keeps the hold for `⌘Z`.
    public func key(_ key: PanelKey, _ moment: Moment) -> Press? {
        upToNow(moment)
        guard hold.isOn, notch.phase == .open || hold.isShortcut && isOut, menuAt == nil else {
            return nil
        }

        let undoes = asking.shown?.sending != nil, summoned = hold.isShortcut
        let press = asking.row == nil ? listKey(key, in: moment.setting) : asksKey(key, in: moment.setting)

        if key == .open, !undoes {
            if summoned, !press.isJump {
                notch.clickElsewhere()
            }
            endHold()
        }
        placeAsks(in: moment.setting)
        return press
    }

    /// The shortcut (DESIGN, "Keys"): out, the panel closes, as a click elsewhere closes it; else it pours open as a
    /// hover opens it, with no reach toward the pointer, and stays open wherever the pointer is until the pointer has
    /// come onto it and left (`Notch.summon`). Where the Mac lets it take keys, it holds every key until it closes, its
    /// lit row the first in Needs you, else the first row; else it holds nothing, and no row is lit.
    public func summon(_ moment: Moment) {
        upToNow(moment)
        guard !isOut else {
            notch.clickElsewhere()
            endHold()
            return
        }
        guard notch.summon(), moment.isShown, moment.setting.takesKeys else {
            return
        }

        hold.summoned()
        keyLit = firstRow.flatMap { list.item($0)?.key }
    }

    /// The first row in Needs you, else the first row, by its index; none on a card with no rows.
    private var firstRow: Int? {
        let rows = list.content.entries.indices.filter { list.content.entries[$0].jumps }

        return rows.first { list.item($0)?.session?.section == .needsYou } ?? rows.first
    }

    /// On the list: `↑` `↓` move the lit row; `⏎` opens the lit row's asks panel where it has the arrow; `o` jumps to
    /// its window; `z` offers its snooze, or in Snoozed wakes it; `s` folds Snoozed or unfolds it; `esc` closes the
    /// panel, which stays closed until the pointer leaves the notch and comes back.
    private func listKey(_ key: PanelKey, in setting: Setting) -> Press? {
        let row = litRow(in: setting)

        switch key {
        case .up, .down:
            move(key == .up ? -1 : 1, from: row, in: setting)
            return nil
        case .enter:
            guard let row, arrowRow(row) != nil else {
                return nil
            }

            toggleAsks(row)
            return .asks
        case .open:
            return row.flatMap { jump($0) }
        case .snooze:
            return row.flatMap { snooze($0, in: setting) }
        case .fold:
            return snoozedEyebrow.flatMap { click($0, in: setting) }
        case .escape:
            notch.clickElsewhere()
            hold.end()
            return nil
        case .left, .right, .ignore, .digit, .undo:
            return nil
        }
    }

    /// On the asks panel, wherever the pointer is on the panel: `↑` `↓` move the lit row and close it, as a menu's
    /// arrows close its submenu; `⏎` and `esc` close it; `s` does nothing; every other key presses its part of it as a
    /// click on the part does (`AsksPanel.key`).
    private func asksKey(_ key: PanelKey, in setting: Setting) -> Press? {
        switch key {
        case .up, .down:
            move(key == .up ? -1 : 1, from: litRow(in: setting), in: setting)
        case .enter, .escape:
            break
        case .fold:
            return nil
        case .left, .right, .open, .snooze, .ignore, .digit, .undo:
            return asksPart(pressedBy: key).flatMap { keyAsks($0, in: setting) }
        }
        asking.close()
        return .asks
    }

    /// The part of the asks panel a key presses: `1`–`9` an answer's row, `x` Ignore, `z` Snooze ▾, `o` Open in Claude,
    /// `⌘Z` the sending line's Undo, and `←` `→` the dot of the ask before the one shown and of the next.
    private func asksPart(pressedBy key: PanelKey) -> AsksPart? {
        switch key {
        case let .digit(number): .answer(number - 1)
        case .ignore: .ignore
        case .snooze: .snooze
        case .open: .open
        case .undo: .undo
        case .left, .right: asking.shown.map { .page($0.page + (key == .left ? -1 : 1)) }
        case .up, .down, .enter, .escape, .fold: nil
        }
    }

    /// The keys held as the pointer moves: on the open panel, a move on its list or its asks panel holds them, and one
    /// off both holds them no more, the row the keys lit going back to the pointer either way. A panel opening under a
    /// resting pointer holds nothing, nor while a menu holds the card, nor while a jump is under way. The shortcut's
    /// hold holds on, from its opening, wherever the pointer goes, a move on the panel taking the lit row back. Hidden,
    /// closing or closed, or while the Mac lets the panel take no keys, it holds nothing.
    func holdKeys(_ moment: Moment) {
        let isHeld = notch.phase == .open || hold.isShortcut && notch.phase == .opening

        guard moment.isShown, isHeld, moment.setting.takesKeys else {
            endHold()
            felt = moment.pointer
            return
        }
        guard menuAt == nil, moment.pointer != felt else {
            return
        }

        let isJumping = frame.panel?.pressed != nil
        let onPanel = !isJumping && moment.pointer.map { frame.panel?.contains($0) == true || asking.isOn($0) } ?? false

        felt = moment.pointer
        if onPanel || !hold.isShortcut {
            keyLit = nil
        }
        hold.moved(onPanel: onPanel)
    }

    /// The hold ended, and the row the keys lit let go: a jump took the panel's keys, or the panel can hold none.
    func endHold() {
        hold.end()
        keyLit = nil
    }

    /// The row lit, by its index: the one the keys lit, else the row under the pointer, else the row whose asks panel
    /// is open; none with the pointer on an eyebrow or the black between rows.
    private func litRow(in setting: Setting) -> Int? {
        keyLitIndex
            ?? seen.flatMap { item(at: $0, in: setting) }.flatMap { list.item($0)?.session == nil ? nil : $0 }
            ?? asking.row.flatMap { list.index(of: $0) }
    }

    private var keyLitIndex: Int? {
        keyLit.flatMap { list.index(of: $0) }
    }

    /// The lit row moved this many rows over the rows, past the eyebrows, within the first and the last, as the
    /// terminal view moves its band, and scrolled into view; with none lit, the first lit going down, the last going up.
    private func move(_ step: Int, from row: Int?, in setting: Setting) {
        let rows = list.content.entries.indices.filter { list.content.entries[$0].jumps }

        guard !rows.isEmpty else {
            return
        }

        let at = row.flatMap { rows.firstIndex(of: $0) }
        let to = rows[at.map { min(max($0 + step, 0), rows.count - 1) } ?? (step > 0 ? 0 : rows.count - 1)]

        keyLit = list.item(to)?.key
        scrollIntoView(to)
    }

    /// The content scrolled as little as shows the whole of the item at this index.
    private func scrollIntoView(_ index: Int) {
        guard let shown = frame.panel?.frame.height else {
            return
        }

        let row = list.content.laidFrame(index)
        let to = row.minY < scroll ? row.minY : row.maxY > scroll + shown ? row.maxY - shown : scroll

        scroll = list.content.scrolled(to, by: 0, showing: shown)
    }

    /// `z` on the row at this index: on a Needs you row of asks or of Lee's turn, its snooze; on a row in Snoozed, its
    /// wake; on a row of stops alone, or a working one, nothing, as its right-click menu offers neither.
    private func snooze(_ index: Int, in setting: Setting) -> Press? {
        guard let session = list.item(index)?.session, session.snoozes else {
            return nil
        }
        guard !session.isSnoozed else {
            return .wake(session)
        }

        return rowBox(index, in: setting).map { .snoozeRow(session, row: $0) }
    }

    /// Where the row at this index stands on the stage, while the panel shows it.
    private func rowBox(_ index: Int, in setting: Setting) -> CGRect? {
        guard let panel = frame.panel else {
            return nil
        }

        let row = list.content.laidFrame(index)
        let corner = panel.stagePoint(row.origin, mirror: setting.mirror, scroll: scroll)
        let across = panel.stagePoint(CGPoint(x: row.maxX, y: row.maxY), mirror: setting.mirror, scroll: scroll)

        return CGRect(x: corner.x, y: corner.y, width: across.x - corner.x, height: across.y - corner.y).standardized
    }

    /// Snoozed's eyebrow, by its index, while the list has it.
    private var snoozedEyebrow: Int? {
        list.content.entries.firstIndex { entry in
            guard case let .eyebrow(eyebrow) = entry.item else {
                return false
            }

            return eyebrow.section == .snoozed
        }
    }
}

extension Optional<NotchRun.Press> {
    /// Whether it is a jump.
    fileprivate var isJump: Bool {
        guard case .jump? = self else {
            return false
        }

        return true
    }
}
