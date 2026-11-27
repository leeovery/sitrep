import CoreGraphics
import SitRepPanel

/// Whether the panel holds the keys (DESIGN, "Keys"), and whose hold it is: the pointer's, which the hover's panel
/// coming open under the pointer or the pointer moving on the panel starts, and moving off it ends; or the shortcut's,
/// which holds every key until the panel closes, the pointer's moves aside. Each hold numbered, so the tap tells the hold a key it let go of ended from the next.
struct KeyHold {
    enum Kind {
        case pointer, shortcut
    }

    private(set) var kind: Kind?
    private(set) var number = 0

    var isOn: Bool { kind != nil }

    var isShortcut: Bool { kind == .shortcut }

    /// The pointer moved, or the hover's panel came open under it, on the panel's black or its asks panel or off them:
    /// on, it holds; off, it holds no more. A shortcut's hold stays the shortcut's.
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

/// The panel's keys in the notch's run (DESIGN, "Keys"): the hold the hover's panel coming open under the pointer or
/// the pointer moving on the panel starts, the lit row the keys move, and what each key does there, by the paths a
/// click takes.
extension NotchRun {
    /// What the tap decides each key by: the panel's hold while it holds the keys, `⌘Z` its while the asks panel takes
    /// it (`AsksPanel.takesUndo`), every key its in the shortcut's; else nothing.
    public var keySnapshot: KeySnapshot {
        hold.isOn ? .panel(hold: hold.number, undoes: asking.takesUndo(at: time), takesAll: hold.isShortcut) : .none
    }

    /// Whether the panel holds the keys.
    public var holdsKeys: Bool { hold.isOn }

    /// A key the panel doesn't take, pressed in the hold of this number: it went through, and that hold is let go
    /// (`letGo(of:)`); in the shortcut's hold, a key with ⌘, ⌃ or ⌥, which closes the panel.
    public func letGoOfKeys(in number: Int, _ moment: Moment) {
        upToNow(moment)
        letGo(of: number)
    }

    /// The panel holds the keys no more, whichever hold it is, until the pointer moves again: as the screens sleep, the
    /// session goes to another user or a window takes secure input. The shortcut's panel stays open, no row lit, and
    /// a panel the hover pours comes open holding nothing, the move before forgotten.
    public func letGoOfKeys(_ moment: Moment) {
        upToNow(moment)
        letGo()
        lastMoveIn = nil
    }

    /// The item lit, by its index: the row the keys lit, while it shows, else the item under the pointer, which an
    /// eyebrow may be, which never lifts.
    public func lit(in setting: Setting) -> Int? {
        keyLitIndex ?? seen.flatMap { item(at: $0, in: setting) }
    }

    /// A key of the set while the panel holds the keys, open, or in the shortcut's hold out, acting on the lit row as
    /// its click would: on the asks panel while it is open (`asksKey`), else on the list (`listKey`). A key with no use
    /// at the moment does nothing, as does one heard while a menu holds the card, the menu's. A key the tap took as
    /// `ending` a hold, as it takes `o` and `⏎` whether or not they jump (`KeyReader`), lets that hold go here too,
    /// acting or not, so the panel holds what the tap holds: the tap alone decides it. So the keys typed after it go to
    /// the window in front, and the shortcut's panel closes where it didn't jump. `o` or `⏎` the tap took ending none,
    /// as `⌘Z` was the asks panel's, where it can't act, acts on nothing, though the beat has passed by the time it is
    /// heard. A held arrow's repeat, `again`, only pages the asks panel: it never opens it nor closes it.
    public func key(_ key: PanelKey, ending number: Int? = nil, again: Bool = false, _ moment: Moment) -> Press? {
        upToNow(moment)

        let press = key.jumps && number == nil ? nil : acted(on: key, again: again, in: moment.setting)

        if let number {
            letGo(of: number)
        }
        placeAsks(in: moment.setting)
        return press
    }

    /// What a key does while it acts: while the panel holds the keys, open, or out in the shortcut's hold, and no menu
    /// holds the card.
    private func acted(on key: PanelKey, again: Bool, in setting: Setting) -> Press? {
        guard hold.isOn, notch.phase == .open || hold.isShortcut && isOut, menuAt == nil else {
            return nil
        }

        return asking.row == nil ? listKey(key, again: again, in: setting) : asksKey(key, again: again, in: setting)
    }

    /// The shortcut (DESIGN, "Keys"): out, the panel closes, as a click elsewhere closes it; closing, nothing; closed,
    /// it pours open as a hover opens it, with no reach toward the pointer, and stays open wherever the pointer is
    /// until the pointer has come onto it and left (`Notch.summon`). Where the Mac lets it take keys, it holds every
    /// key until it closes, its lit row the first in Needs you, else the first row; else it holds nothing, and no row
    /// is lit.
    public func summon(_ moment: Moment) {
        upToNow(moment)
        guard !isOut else {
            return closePanel()
        }
        guard notch.summon() else {
            return
        }

        lastMoveIn = nil
        guard moment.isShown, moment.setting.takesKeys else {
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

    /// On the list: `↑` `↓` move the lit row; `⏎` and `o` jump to its window; the arrow pointing away from the notch
    /// opens its asks panel where it has the arrow, as a click on the arrow does, at its first ask, but not `again` as
    /// it repeats, and the arrow pointing back does nothing; `z` offers its snooze, or in Snoozed wakes it; `s` folds
    /// Snoozed or unfolds it; `esc` closes the panel, which stays closed until the pointer leaves the notch and comes
    /// back.
    private func listKey(_ key: PanelKey, again: Bool, in setting: Setting) -> Press? {
        let row = litRow(in: setting)

        switch key {
        case .up, .down:
            move(key == .up ? -1 : 1, from: row, in: setting)
            return nil
        case .left, .right:
            guard !again, isOutward(key, in: setting), let row, arrowRow(row) != nil else {
                return nil
            }

            toggleAsks(row)
            return .asks
        case .enter, .open:
            return row.flatMap { jump($0) }
        case .snooze:
            return row.flatMap { snooze($0, in: setting) }
        case .fold:
            return snoozedEyebrow.flatMap { click($0, in: setting) }
        case .escape:
            closePanel()
            return nil
        case .ignore, .digit, .undo:
            return nil
        }
    }

    /// On the asks panel, wherever the pointer is on the panel: `↑` `↓` move the lit row and close it, as a menu's
    /// arrows close its submenu; `esc` closes it; `←` `→` step along its asks (`stepAsks`); `⏎` and `o` go to the lit
    /// row (`goes`); `s` does nothing; every other key presses its part of it as a click on the part does
    /// (`AsksPanel.key`).
    private func asksKey(_ key: PanelKey, again: Bool, in setting: Setting) -> Press? {
        switch key {
        case .up, .down:
            move(key == .up ? -1 : 1, from: litRow(in: setting), in: setting)
        case .escape:
            break
        case .left, .right:
            return stepAsks(outward: isOutward(key, in: setting), again: again, in: setting)
        case .fold:
            return nil
        case .enter, .open:
            return goes(in: setting)
        case .snooze, .ignore, .digit, .undo:
            return asksPart(pressedBy: key).flatMap { keyAsks($0, in: setting) }
        }
        asking.close()
        return .asks
    }

    /// `⏎` or `o` with the asks panel open goes to the lit row: on the asks panel's own row, its Open in Claude, with
    /// every rule that has (`AsksPanel.key`); on another row the pointer lights, that row's window, as a click on its
    /// words, so it never moves the screen to a session the pointer isn't on.
    private func goes(in setting: Setting) -> Press? {
        guard let row = litRow(in: setting), list.item(row)?.key != asking.row else {
            return keyAsks(.open, in: setting)
        }

        return jump(row)
    }

    /// An arrow on the asks panel: pointing away from the notch, the next ask, nothing past the last; pointing back,
    /// the one before, each as its dot pages it, or from the first the asks panel closed, its row left lit, as a
    /// menu's `←` closes its submenu, but not `again` as it repeats, nor within the beat after a change the keys
    /// didn't make, which holds a key on it (`AsksPanel.isSettled(forKeysAt:)`). While fingers carry its asks, it
    /// lands on nothing, as a page there does.
    private func stepAsks(outward: Bool, again: Bool, in setting: Setting) -> Press? {
        guard let page = asking.shown?.page, !asking.isFollowing else {
            return nil
        }

        let to = page + (outward ? 1 : -1)

        guard to < 0 else {
            return keyAsks(.page(to), in: setting)
        }
        guard !again, asking.isSettled(forKeysAt: time) else {
            return nil
        }

        keyLit = asking.row
        asking.close()
        return .asks
    }

    /// Whether an arrow points away from the notch, along the line the list, the asks panel and its asks lie on out
    /// from it: `→` on the left edge, `←` on the right, mirrored there.
    private func isOutward(_ key: PanelKey, in setting: Setting) -> Bool {
        (key == .right) == (setting.mirror.a > 0)
    }

    /// The part of the asks panel a key presses: `1`–`9` an answer's row, `x` Ignore, `z` Snooze ▾, and `⌘Z` the
    /// sending line's Undo.
    private func asksPart(pressedBy key: PanelKey) -> AsksPart? {
        switch key {
        case let .digit(number): .answer(number - 1)
        case .ignore: .ignore
        case .snooze: .snooze
        case .undo: .undo
        case .up, .down, .left, .right, .enter, .open, .escape, .fold: nil
        }
    }

    /// The keys held as the pointer moves: on the open panel, a move on its black (`Frame.shape`), the flares by the
    /// screen's edge as much as the rows, or on its asks panel holds them, and one off both holds them no more, the row
    /// the keys lit going back to the pointer either way; a move is the pointer elsewhere than it was felt, or one the
    /// Mac heard (`pointerMoved`). A panel coming open within `hoverWindow` of the pointer's last move holds them as it
    /// comes open with the pointer on it, the hover that opened it counting wherever the pointer rests. None holds
    /// while a menu holds the card, nor while a jump is under way. The shortcut's hold holds on, from its opening,
    /// wherever the pointer goes, a move on the panel taking the lit row back. Hidden, closing or closed, or while the
    /// Mac lets the panel take no keys, it holds nothing.
    func holdKeys(_ moment: Moment) {
        let isHeld = notch.phase == .open || hold.isShortcut && notch.phase == .opening
        let isFeltMove = moment.pointer != felt || movedSinceFelt

        if notch.phase != .open, isFeltMove, !hold.isShortcut {
            lastMoveIn = time
        }
        guard moment.isShown, isHeld, moment.setting.takesKeys else {
            letGo()
            feel(moment)
            return
        }

        // read at the first open frame the keys may be held in: the Card opens at once under Reduce motion, before
        // the Mac's tap is made
        let isHoverOpening = notch.phase == .open && lastMoveIn.map { time - $0 <= Self.hoverWindow } ?? false

        if notch.phase == .open {
            lastMoveIn = nil
        }
        guard menuAt == nil, isFeltMove || isHoverOpening else {
            return
        }

        let isJumping = frame.panel?.pressed != nil
        let onPanel = !isJumping && moment.pointer.map { frame.shape.contains($0) || asking.isOn($0) } ?? false

        feel(moment)
        if onPanel || !hold.isShortcut {
            keyLit = nil
        }
        hold.moved(onPanel: onPanel)
    }

    /// The Mac heard the pointer move: the next moment is a move for the keys' hold, though it gives the pointer where
    /// it was felt, as pushed on against the screen's edge, where AppKit keeps it in place (Lee's live run, 27
    /// November 2026).
    public func pointerMoved() {
        movedSinceFelt = true
    }

    private func feel(_ moment: Moment) {
        felt = moment.pointer
        movedSinceFelt = false
    }

    /// The hold ended, whichever it was, and the row the keys lit let go: the one way the panel lets go of the keys, as
    /// a jump takes them, a key lets go of them, or the panel can hold none.
    func letGo() {
        hold.end()
        keyLit = nil
    }

    /// The hold of this number let go, while it is the hold still: the shortcut's closes the panel, any other holds
    /// none until the pointer moves again. A hold the pointer began since keeps the keys. While a menu holds the card,
    /// the shortcut's panel stays open under it, holding nothing, as a key racing the menu's opening never drains it.
    private func letGo(of number: Int) {
        guard hold.number == number else {
            return
        }

        if hold.isShortcut, menuAt == nil {
            closePanel()
        } else {
            letGo()
        }
    }

    /// The panel closed, as a click elsewhere closes it, and the keys let go, so the window in front has them as it
    /// closes: the one way the keys, the shortcut and a click elsewhere close it.
    func closePanel() {
        notch.clickElsewhere()
        letGo()
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
    /// terminal view moves its band, and scrolled into view; with none lit, the first lit going down, the last going
    /// up.
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
