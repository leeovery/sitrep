import CoreGraphics
import SitRepCore
import SitRepPanel

/// The asks panel in the strip's run (DESIGN, "Answering from the panel", the strip): beside the tab a mark pours, as
/// the notch's is beside its row. Where it stands at each input, what a press is on there, the tab's arrow that opens
/// it, and what the strip is told of it.
extension StripRun {
    /// The asks panel as the last frame or input placed it, beside the tab, the part of it under the pointer lit; nil
    /// while it is closed.
    public var asksShown: AsksShown? { asking.shown }

    /// The tab's arrow, where it shows: the open tab's whose session the asks panel answers an ask of, by the session's
    /// mark's key (`Session.markID`), lit with the pointer on it, or with its asks panel open.
    public func arrow(in setting: Setting) -> (row: String, isLit: Bool)? {
        guard let row = arrowRow?.session.markID else {
            return nil
        }

        return (row, asking.row == row || frame.pointer.flatMap { arrow(at: $0, in: setting) } == row)
    }

    /// Whether a point on the stage is on the strip, an open tab or the asks panel: where the window takes clicks.
    public func hits(_ point: CGPoint) -> Bool {
        frame.hits(point) || asking.isOn(point)
    }

    /// Whether a trackpad's swipe across the asks panel is under way, the window taking clicks until it ends
    /// (`NotchRun.isSwiping`).
    public var isSwiping: Bool { asking.isSwiping }

    /// An answer's news, as the answers tell it (DESIGN, "Answering, with two seconds to undo"), as the notch's asks
    /// panel hears it (`NotchRun.heard`).
    /// The last ask's answer of a session gone, its tab's arrow goes, and its words give back the room they made.
    public func heard(_ news: AnswerNews, _ moment: Moment) {
        upToNow(moment)
        asking.heard(news)
        strip.reword(renote().arrows)
        placeAsks(in: moment.setting)
    }

    /// The note told again from the board and the asks panel, one source for the tab's arrow and the room its words
    /// make for it: the sessions whose tab takes it those the asks panel answers an ask of, an ask whose answer went
    /// left out. The note it was, and the marks, by their keys, whose tab's arrow came or went.
    func renote() -> (was: StripNote, arrows: Set<String>) {
        let was = said.note

        said.note = StripNote(board, arrows: asking.asked(on: board))
        return (was, Set(board.cardSessions.filter { note.hasArrow($0) != was.hasArrow($0) }.map(\.markID)))
    }

    /// The asks panel closed, as a snooze from it closes it.
    public func closeAsks(_ moment: Moment) {
        upToNow(moment)
        asking.close()
        placeAsks(in: moment.setting)
    }

    /// The open tab as the frame draws it, for the asks panel beside it.
    var tabRows: TabRows {
        TabRows(frame: frame)
    }

    /// The asks panel kept to what shows, closed as the tab draws back or glides to another mark, or its last ask
    /// goes, and placed beside the tab as the frame has it, kept inside the screen's visible frame, under the menu bar
    /// and above the Dock, as the notch's is.
    func placeAsks(in setting: Setting) {
        let ground = AsksGround(
            rows: tabRows, board: board, visible: setting.stage.menu ... setting.stage.visibleBottom,
            mirror: setting.mirror
        )

        asking.place(
            isOpen: tabRows.open != nil, on: ground, pointer: frame.pointer, at: time,
            offersSnooze: setting.offersSnooze
        )
    }

    /// A press on the asks panel (`AsksPanel.press`): Open in Claude jumps as the tab does, closing it.
    func pressAsks(at point: CGPoint, in setting: Setting) -> Press? {
        let press = asking.press(
            at: point, tabRows, board, mirror: setting.mirror, reducesMotion: setting.reducesMotion, at: time
        )

        switch press {
        case .paged?: return .asks
        case let .answer(answering)?: return .answer(answering)
        case .undo?: return .undo
        case let .snooze(ask, of: session, at: point)?: return .snooze(ask: ask, of: session, at: point)
        case let .open(row)?: return open(row)
        case nil: return nil
        }
    }

    /// The asks panel opened beside the tab of the session by this mark's key, or, open beside it, closed.
    func toggleAsks(_ row: String) {
        if let session = tabRows.session(ofRow: row) {
            asking.toggle(row, session, on: board)
        }
    }

    /// The session, by its mark's key, whose tab's arrow a point on the stage is on: at the tab's front end, its right
    /// on the left edge and its left on the right (`RowArrow.tabBox`).
    func arrow(at point: CGPoint, in setting: Setting) -> String? {
        guard let open = arrowRow, open.tab.contains(point) else {
            return nil
        }

        let own = open.tab.ownPoint(point, in: open.words, mirror: setting.mirror)
        let box = RowArrow.tabBox(in: open.words.frame.size, pointsLeft: setting.mirror.a < 0)

        return box.contains(own) ? open.session.markID : nil
    }

    /// The open tab where it has an arrow: a session's whose words make room for one (`StripNote.hasArrow`).
    private var arrowRow: TabRows.Open? {
        tabRows.open.flatMap { note.hasArrow($0.session) ? $0 : nil }
    }
}

/// The strip's open tab as a frame draws it: what the asks panel opens beside, level with its row and overlapping its
/// front. A row by its session's mark's key (`Session.markID`).
struct TabRows: AsksRows {
    let frame: StripFrame

    /// The open tab, its newest words and the session they show: a session's tab, poured out.
    struct Open {
        let tab: StripFrame.Tab
        let words: StripFrame.Words
        let session: Session
    }

    var open: Open? {
        guard let tab = frame.tabs.first(where: \.isLive), let words = tab.words.last, words.key == tab.key,
              case let .row(session) = words.content
        else {
            return nil
        }

        return Open(tab: tab, words: words, session: session)
    }

    func session(ofRow key: String) -> Session? {
        open.flatMap { $0.session.markID == key ? $0.session : nil }
    }

    func standing(ofRow key: String) -> (top: Double, front: Double)? {
        guard let open, open.session.markID == key else {
            return nil
        }

        return (open.tab.box.minY + open.words.frame.minY, open.tab.clip.maxX)
    }
}
