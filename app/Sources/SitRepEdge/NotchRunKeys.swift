import CoreGraphics
import SitRepPanel

/// Whether the panel holds the keys (DESIGN, "Keys"), each hold numbered, so the tap tells the hold a key it let go of
/// ended from the next.
struct KeyHold {
    private(set) var isOn = false
    private(set) var number = 0

    /// The pointer moved, on the open list or its asks panel or off them: on, it holds; off, it holds no more.
    mutating func moved(onPanel: Bool) {
        if onPanel, !isOn {
            number += 1
        }
        isOn = onPanel
    }

    mutating func end() {
        isOn = false
    }
}

/// The panel's keys in the notch's run (DESIGN, "Keys"): the hold the pointer moving on the panel starts, the lit row
/// the keys move, and what each key does there, by the paths a click takes.
extension NotchRun {
    /// What the tap decides each key by: the panel's hold while it holds the keys; else nothing.
    public var keySnapshot: KeySnapshot {
        hold.isOn ? .panel(hold: hold.number) : .none
    }

    /// Whether the panel holds the keys.
    public var holdsKeys: Bool { hold.isOn }

    /// A key the panel doesn't take, pressed in the hold of this number: it went through, and the panel holds none
    /// until the pointer moves again. A hold the pointer began since the key keeps the keys.
    public func letGoOfKeys(in number: Int, _ moment: Moment) {
        upToNow(moment)
        if hold.number == number {
            hold.end()
        }
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

    /// A key of the set while the panel holds the keys, open, acting on the lit row as its click would. While the asks
    /// panel is open, `↑` `↓` move the lit row and close it, `⏎` and `esc` close it, and every other key does nothing;
    /// otherwise each acts on the list (`listKey`). A key with no use at the moment does nothing, as does one heard
    /// while a menu holds the card, the menu's. `o` ends the hold whether or not it jumps, as the tap ended it as it
    /// took `o` (`KeyReader`), so the keys typed after it go to the window in front.
    public func key(_ key: PanelKey, _ moment: Moment) -> Press? {
        upToNow(moment)
        guard hold.isOn, notch.phase == .open, menuAt == nil else {
            return nil
        }
        defer {
            if key == .open {
                endHold()
            }
            placeAsks(in: moment.setting)
        }

        return asking.row == nil ? listKey(key, in: moment.setting) : asksKey(key, in: moment.setting)
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
        case .left, .right, .ignore, .digit:
            return nil
        }
    }

    private func asksKey(_ key: PanelKey, in setting: Setting) -> Press? {
        switch key {
        case .up, .down:
            move(key == .up ? -1 : 1, from: litRow(in: setting), in: setting)
        case .enter, .escape:
            break
        case .left, .right, .open, .snooze, .fold, .ignore, .digit:
            return nil
        }
        asking.close()
        return .asks
    }

    /// The keys held as the pointer moves: on the open panel, a move on its list or its asks panel holds them, and one
    /// off both holds them no more, the row the keys lit going back to the pointer either way. A panel opening under a
    /// resting pointer holds nothing, nor while a menu holds the card, nor while a jump is under way. Hidden, closing
    /// or closed, or while the Mac lets the panel take no keys, it holds nothing.
    func holdKeys(_ moment: Moment) {
        guard moment.isShown, notch.phase == .open, moment.setting.takesKeys else {
            endHold()
            felt = moment.pointer
            return
        }
        guard menuAt == nil, moment.pointer != felt else {
            return
        }

        let isJumping = frame.panel?.pressed != nil

        felt = moment.pointer
        keyLit = nil
        hold.moved(
            onPanel: !isJumping && moment.pointer.map { frame.panel?.contains($0) == true || asking.isOn($0) } ?? false
        )
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
