import CoreGraphics
import SitRepCore
import SitRepPanel

/// The asks panel in the notch's run (DESIGN, "Answering from the panel"): where it stands at each input, what a press
/// is on there, the rows' arrows that open it, and what the notch is told of it.
extension NotchRun {
    /// The asks panel as the last frame or input placed it, beside its row, the part of it under the pointer lit, its
    /// answers showing their keycaps while the panel holds the keys and no answer is held, when the digits answer; nil
    /// while it is closed.
    public var asksShown: AsksShown? {
        asking.shown.map { shown in
            var shown = shown

            shown.keycaps = hold.isOn && !asking.isHolding
            return shown
        }
    }

    /// The rows' arrows that show, by their rows' keys, each lit or not: the lit row's, where the asks panel answers an
    /// ask of its session, lit with the pointer on it; and, lit, the arrow of the row whose asks panel is open. None
    /// while the panel is not open.
    public func arrows(in setting: Setting) -> [String: Bool] {
        guard notch.phase == .open else {
            return [:]
        }

        var arrows = asking.row.map { [$0: true] } ?? [:]

        if let index = lit(in: setting), let key = arrowRow(index) {
            let pointed = seen.flatMap { arrow(at: $0, in: setting) } == index

            arrows[key] = arrows[key] == true || pointed
        }
        return arrows
    }

    /// Whether a point on the stage is on the black, the notch's hit area or the asks panel: where the window takes
    /// clicks.
    public func hits(_ point: CGPoint) -> Bool {
        frame.hits(point) || asking.isOn(point)
    }

    /// Whether a trackpad's swipe across the asks panel is under way: the window takes clicks wherever the pointer is
    /// until it ends, so the rest of its gesture comes to the asks panel, though the asks panel shrank from under a
    /// still pointer as it slid to a shorter ask.
    public var isSwiping: Bool { asking.isSwiping }

    /// An answer's news, as the answers tell it (DESIGN, "Answering, with two seconds to undo"): held, the asks panel
    /// shows it sending; taken back, as it was; gone, the asks panel steps to the session's next ask, closing after its
    /// last; refused by the CLI, the ask is back.
    public func heard(_ news: AnswerNews, _ moment: Moment) {
        upToNow(moment)
        asking.heard(news)
        placeAsks(in: moment.setting)
    }

    /// The asks panel closed, as a snooze from it closes it.
    public func closeAsks(_ moment: Moment) {
        upToNow(moment)
        asking.close()
        placeAsks(in: moment.setting)
    }

    /// The panel's rows as the frame lays them out, for the asks panel beside them.
    var panelRows: PanelRows {
        PanelRows(list: list, panel: frame.panel, scroll: scroll)
    }

    /// The asks panel kept to what shows, closed as the panel goes in, its row goes, or its last ask, and placed
    /// beside its row as the frame has it, once for all that reads it until the next.
    func placeAsks(in setting: Setting) {
        let stage = setting.stage
        let ground = AsksGround(
            rows: panelRows, board: board, scroll: scroll, visible: stage.visibleTop ... stage.visibleBottom,
            mirror: setting.mirror
        )

        asking.place(
            isOpen: notch.phase == .open, on: ground, pointer: seen, at: time, offersSnooze: setting.offersSnooze
        )
    }

    /// A press on the asks panel (`AsksPanel.press`): Open in Claude jumps as the row does, closing it. Nowhere on it
    /// carries the notch.
    func pressAsks(at point: CGPoint, in setting: Setting) -> Press? {
        pressed(asking.press(
            at: point, panelRows, board, mirror: setting.mirror, reducesMotion: setting.reducesMotion, at: time
        ))
    }

    /// A key pressing a part of the asks panel (`AsksPanel.key`), coming to what a press on the part does.
    func keyAsks(_ part: AsksPart, in setting: Setting) -> Press? {
        pressed(asking.key(
            part, panelRows, board, mirror: setting.mirror, reducesMotion: setting.reducesMotion, at: time
        ))
    }

    private func pressed(_ press: AsksPress?) -> Press? {
        switch press {
        case .paged?: return .asks
        case let .answer(answering)?: return .answer(answering)
        case .undo?: return .undo
        case let .snooze(ask, of: session, at: point)?: return .snooze(ask: ask, of: session, at: point)
        case let .open(row)?: return list.index(of: row).flatMap { jump($0) }
        case nil: return nil
        }
    }

    /// The asks panel opened beside the row at this index, moved to it, or closed.
    func toggleAsks(_ index: Int) {
        guard let row = list.item(index), let session = row.session else {
            return
        }

        asking.toggle(row.key, session, on: board)
    }

    /// The row whose arrow a point on the stage is on, by its index in the list, while the panel is open: at the row's
    /// end toward the asks panel, its right on the left edge and its left on the right (`RowArrow.box`).
    func arrow(at point: CGPoint, in setting: Setting) -> Int? {
        guard notch.phase == .open, let content = contentPoint(point, in: setting),
              let index = list.content.item(at: content), arrowRow(index) != nil
        else {
            return nil
        }

        let row = list.content.laidFrame(index), box = RowArrow.box(in: row.size, pointsLeft: setting.mirror.a < 0)

        return box.contains(CGPoint(x: content.x - row.minX, y: content.y - row.minY)) ? index : nil
    }

    /// The key of the row at this index where it has an arrow: a Needs you row, not folding away, whose session the
    /// asks panel answers an ask of.
    func arrowRow(_ index: Int) -> String? {
        let entry = list.content.entries[index]

        guard !entry.isGoing, let session = entry.item.session, !asking.asks(of: session, on: board).isEmpty else {
            return nil
        }

        return entry.item.key
    }
}

/// The notch's panel rows as a frame lays them out, the list scrolled this far in the open panel: what the asks panel
/// opens beside, level with its row and overlapping the panel's front.
struct PanelRows: AsksRows {
    let list: PanelList
    let panel: Frame.Panel?
    let scroll: Double

    func session(ofRow key: String) -> Session? {
        list.index(of: key).flatMap { list.item($0)?.session }
    }

    func standing(ofRow key: String) -> (top: Double, front: Double)? {
        guard let panel, let index = list.index(of: key) else {
            return nil
        }

        return (panel.frame.minY + list.content.laidFrame(index).minY - scroll, panel.frame.maxX)
    }
}
