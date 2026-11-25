import CoreGraphics
import SitRepCore
import SitRepPanel

/// The asks panel in the notch's run (DESIGN, "Answering from the panel"): where it stands at each input, what the
/// pointer and a press are on there, the rows' arrows that open it, and what the notch is told of it.
extension NotchRun {
    /// The asks panel as the last frame or input placed it, beside its row, the part of it under the pointer lit; nil
    /// while it is closed.
    public var asksShown: AsksShown? { asking.shown }

    /// The rows' arrows that show, by their rows' keys, each lit or not: the row under the pointer's, where the asks
    /// panel answers an ask of its session, lit with the pointer on it; and, lit, the arrow of the row whose asks
    /// panel is open. None while the panel is not open.
    public func arrows(in setting: Setting) -> [String: Bool] {
        guard notch.phase == .open else {
            return [:]
        }

        var arrows = asking.row.map { [$0: true] } ?? [:]

        if let point = seen, let index = item(at: point, in: setting), let key = arrowRow(index) {
            arrows[key] = arrows[key] == true || arrow(at: point, in: setting) == index
        }
        return arrows
    }

    /// Whether a point on the stage is on the black, the notch's hit area or the asks panel: where the window takes
    /// clicks.
    public func hits(_ point: CGPoint) -> Bool {
        frame.hits(point) || isOnAsks(point)
    }

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

    /// The asks panel kept to what shows, closed as the panel goes in, its row goes, or its last ask, and placed
    /// beside its row as the frame has it, once for all that reads it until the next.
    func placeAsks(in setting: Setting) {
        let ground = AsksGround(
            list: list, board: board, panel: frame.panel, scroll: scroll, stage: setting.stage, mirror: setting.mirror
        )

        asking.keep(isOpen: notch.phase == .open, list, board)
        asking.place(on: ground, pointer: seen, at: time) { self.layout($0, offersSnooze: setting.offersSnooze) }
    }

    func isOnAsks(_ point: CGPoint?) -> Bool {
        point.map { asksShown?.contains($0) == true } ?? false
    }

    /// A press on the asks panel, once what it shows has settled (`AsksPanel.settle`): an answer's row, or Ignore,
    /// holds that answer, while none is held; Undo takes the held one back; a page dot shows its ask; Snooze ▾ offers
    /// the snooze of the ask shown; Open in Claude jumps as the row does, closing it. Nowhere on it carries the notch.
    func pressAsks(_ asks: AsksShown, at point: CGPoint, in setting: Setting) -> Press? {
        let ask = asks.ask, session = asks.session.id

        guard asking.isSettled(at: time) else {
            return nil
        }

        switch asking.part(at: point, mirror: setting.mirror) {
        case let .answer(row)?:
            return .answer(Answering(.words(ask.answers[row]), to: ask.id, of: session, wanting: ask.wants.shape))
        case .ignore?:
            return .answer(Answering(.ignore, to: ask.id, of: session, wanting: ask.wants.shape))
        case .undo?:
            return .undo
        case let .page(page)?:
            asking.page(to: page, list, board)
            return .asks
        case .snooze?:
            return .snooze(ask: ask.id, of: session, at: point)
        case .open?:
            return list.index(of: asks.row).flatMap { jump($0) }
        case nil:
            return nil
        }
    }

    /// The asks panel opened beside the row at this index, moved to it, or closed.
    func toggleAsks(_ index: Int) {
        guard let row = list.item(index), let session = row.session else {
            return
        }

        asking.toggle(row.key, session, on: board)
    }

    /// The row whose arrow a point on the stage is on, by its index in the list, while the panel is open.
    func arrow(at point: CGPoint, in setting: Setting) -> Int? {
        guard notch.phase == .open, let content = contentPoint(point, in: setting),
              let index = list.content.item(at: content), arrowRow(index) != nil
        else {
            return nil
        }

        let row = list.content.laidFrame(index)

        return RowArrow.box(in: row.size).contains(CGPoint(x: content.x - row.minX, y: content.y - row.minY))
            ? index : nil
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

    /// An ask laid out as the drawing sets its words, Snooze ▾ in its foot where Snooze offers a time, the last one
    /// kept, as a frame lays it out more than once.
    func layout(_ ask: PanelAsk, offersSnooze: Bool) -> AsksLayout {
        if let laidOut, laidOut.ask == ask, laidOut.offersSnooze == offersSnooze {
            return laidOut.layout
        }

        let layout = AsksLayout(ask, measure: measure, offersSnooze: offersSnooze)

        laidOut = (ask, offersSnooze, layout)
        return layout
    }
}
