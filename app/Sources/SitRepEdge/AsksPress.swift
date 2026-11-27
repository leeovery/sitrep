import CoreGraphics
import SitRepCore
import SitRepPanel

/// What a press on the asks panel comes to, for the run holding it to act on.
enum AsksPress: Equatable {
    /// A page dot paged it, and nothing else.
    case paged
    /// An answer's row, or Ignore: the answer to hold.
    case answer(Answering)
    /// The sending line's Undo: the answer held taken back.
    case undo
    /// Snooze ▾: the ask it shows, by its id, and its session's, to snooze from a menu at this point on the stage.
    case snooze(ask: String, of: String, at: CGPoint)
    /// Open in Claude: the jump its row makes, the row by its key.
    case open(row: String)
}

extension AsksPanel {
    /// A press at a point on the stage on it as shown (DESIGN, "Answering from the panel"): a page dot slides to its ask
    /// at once, as it pages the same whatever ask shows, though not under the fingers; the rest once its asks have
    /// stopped sliding and what it shows has settled (`settle`). An answer's row, or Ignore, holds that answer, while
    /// none is held; Undo takes the held one back; Snooze ▾ offers the snooze of the ask shown; Open in Claude jumps as
    /// its row does. Nil off it, or on nothing of it that takes a press now.
    mutating func press(
        at point: CGPoint, _ rows: some AsksRows, _ board: PanelBoard, mirror: CGAffineTransform, reducesMotion: Bool,
        at time: Double
    ) -> AsksPress? {
        guard let asks = shown, asks.contains(point) else {
            return nil
        }

        let part = part(at: point, mirror: mirror)

        if case let .page(page)? = part, !isFollowing {
            self.page(to: page, rows, board, reducesMotion: reducesMotion)
            return .paged
        }
        guard !isSliding, isSettled(at: time), let part else {
            return nil
        }

        return pressed(part, of: asks, at: point)
    }

    /// A key pressing a part of it (DESIGN, "Keys"), on the ask shown wherever the pointer is, as a click on the part's
    /// middle does (`press`): nothing where the part doesn't show or takes no click now, as an answer's row or Ignore
    /// while an answer is held, Snooze ▾ while Snooze offers no time, or Undo with no sending line, nor while fingers
    /// carry its asks. A page dot pages it beat or none, as its click does, the beat after it holding the next key only
    /// where it paged within one; any other part waits out the beat after a change the keys didn't make
    /// (`isSettled(forKeysAt:)`), its asks sliding or not.
    mutating func key(
        _ part: AsksPart, _ rows: some AsksRows, _ board: PanelBoard, mirror: CGAffineTransform, reducesMotion: Bool,
        at time: Double
    ) -> AsksPress? {
        guard let asks = shown, !isFollowing, let middle = asks.middle(of: part),
              Self.part(of: asks, own: middle, holding: isHolding) == part
        else {
            return nil
        }
        if case let .page(page) = part {
            self.page(
                to: page, rows, board, reducesMotion: reducesMotion, byKeys: true, settled: isSettled(forKeysAt: time)
            )
            return .paged
        }

        return isSettled(forKeysAt: time) ? pressed(part, of: asks, at: asks.stagePoint(middle, mirror: mirror)) : nil
    }

    /// What a press on a part of the ask shown comes to, at this point on the stage; a page dot's paging aside.
    private func pressed(_ part: AsksPart, of asks: AsksShown, at point: CGPoint) -> AsksPress? {
        let ask = asks.ask, session = asks.session.id

        switch part {
        case let .answer(row):
            return .answer(Answering(.words(ask.answers[row]), to: ask.id, of: session, wanting: ask.wants.shape))
        case .ignore:
            return .answer(Answering(.ignore, to: ask.id, of: session, wanting: ask.wants.shape))
        case .undo:
            return .undo
        case .snooze:
            return .snooze(ask: ask.id, of: session, at: point)
        case .open:
            return .open(row: asks.row)
        case .page:
            return nil
        }
    }
}
