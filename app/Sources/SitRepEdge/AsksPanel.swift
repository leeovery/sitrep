import CoreGraphics
import SitRepCore
import SitRepPanel

/// The asks panel as the notch's run holds it (DESIGN, "Answering from the panel"): beside which row it is open, and
/// the ask it shows; the answer held, as the answers tell it; and the asks whose answers went, which it shows no more
/// until the board leaves them out. It shows one session's asks, one at a time, in its row's order, while the panel
/// is open; it closes as the panel goes in, as its row goes, or as its last ask does.
struct AsksPanel {
    /// Open beside a row, by its key, at an ask, by its id and its page.
    private struct Open {
        let row: String
        var ask: String
        var page: Int
    }

    /// An ask of a session, by their ids.
    private struct AskOf: Hashable {
        let session: String
        let ask: String

        init(session: String, ask: String) {
            self.session = session
            self.ask = ask
        }

        init(_ answering: Answering) {
            self.init(session: answering.session, ask: answering.ask)
        }
    }

    /// What it shows, for a press to tell a change of meaning by: beside which row, its session's ask as it reads, and
    /// whether an answer to it is held.
    private struct Look: Equatable {
        let row: String
        let session: String
        let ask: PanelAsk
        let isSending: Bool

        init(_ shown: AsksShown) {
            row = shown.row
            session = shown.session.id
            ask = shown.ask
            isSending = shown.sending != nil
        }

        /// Whether, shown after `was`, what sits under the pointer means something else: another ask, or the same one
        /// changed, in the same place; or the sending line gone, its Undo's place another part's. Not opening, nor
        /// moving to another row, where nothing of it sat under the pointer; nor a hold, the sending line coming where
        /// the foot was, whose Undo a fast press is meant for.
        func meansOther(than was: Look?) -> Bool {
            guard let was, was.row == row else {
                return false
            }

            return was.session != session || was.ask != ask || (was.isSending && !isSending)
        }
    }

    private var open: Open?
    private var held: HeldAnswer?
    private var gone: Set<AskOf> = []
    /// As the last frame placed it; nil while it is closed.
    private(set) var shown: AsksShown?
    /// Where it stands with the room to its row's arrow, and what the notch was last told of it, with the pointer then.
    private var room: CGPath?
    private var told: (room: CGPath, pointer: CGPoint?)?
    private var look: Look?
    private var lookedAt = -Double.infinity

    /// The row it is open beside, by its key; nil while it is closed.
    var row: String? { open?.row }

    /// Whether an answer is held, when it takes no other.
    var isHolding: Bool { held != nil }

    /// A row's session's asks the asks panel answers, those whose answers went aside: none but a Needs you row's.
    func asks(of session: Session, on board: PanelBoard) -> [PanelAsk] {
        guard session.needsLee else {
            return []
        }

        return (board.asks[session.id] ?? []).filter { !gone.contains(AskOf(session: session.id, ask: $0.id)) }
    }

    /// Opened beside the row `key`, at its session's first ask, or moved there; open beside it already, closed.
    mutating func toggle(_ key: String, _ session: Session, on board: PanelBoard) {
        guard open?.row != key else {
            return close()
        }

        open = asks(of: session, on: board).first.map { Open(row: key, ask: $0.id, page: 0) }
    }

    mutating func close() {
        open = nil
    }

    /// Kept to what shows: closed while the panel is not open, its row gone or none of its asks left; else at its
    /// ask, or, where that left, the one that took its page, or the last.
    mutating func keep(isOpen: Bool, _ list: PanelList, _ board: PanelBoard) {
        guard let open else {
            return
        }
        guard isOpen, let session = list.index(of: open.row).flatMap({ list.item($0)?.session }) else {
            return close()
        }

        let asks = asks(of: session, on: board)
        guard !asks.isEmpty else {
            return close()
        }

        let page = asks.firstIndex { $0.id == open.ask } ?? min(open.page, asks.count - 1)

        self.open = Open(row: open.row, ask: asks[page].id, page: page)
    }

    /// An answer's news: held, it shows sending until it is taken back or goes; gone, its ask leaves the asks panel,
    /// unless the CLI refuses it, when it is back.
    mutating func heard(_ news: AnswerNews) {
        switch news {
        case let .held(answer):
            held = answer
        case let .undone(answering):
            release(answering)
        case let .went(answering):
            release(answering)
            gone.insert(AskOf(answering))
        case let .ended(answering, .refused):
            gone.remove(AskOf(answering))
        case .ended:
            break
        }
    }

    /// A new board: an ask gone that it no longer lists is forgotten.
    mutating func take(_ board: PanelBoard) {
        gone = gone.filter { gone in board.asks[gone.session]?.contains { $0.id == gone.ask } == true }
    }

    /// Placed as a frame shows it (`shown`): beside its row as the panel and its scroll place the row on the stage,
    /// laid out by `layout`, kept on the screen, the answer held to its ask sending, and the part of it under `pointer`
    /// lit; with the room between it and its row's arrow; and, where what it shows changed, when, on the display's
    /// clock.
    mutating func place(
        on ground: AsksGround, pointer: CGPoint?, at time: Double, layout: (PanelAsk) -> AsksLayout
    ) {
        shown = placed(on: ground, pointer: pointer, layout: layout)
        room = shown.map { Self.room(of: $0, on: ground) }

        let look = shown.map(Look.init)

        if look?.meansOther(than: self.look) == true {
            lookedAt = time
        }
        self.look = look
    }

    /// The room the notch is told the pointer is on (`Input.beside`): the asks panel and the room to its row's arrow;
    /// or, where they went from under a pointer that has not moved since, as the asks panel closed or shrank, the room
    /// they had, so that is no leave until the pointer moves.
    mutating func beside(_ pointer: CGPoint?) -> CGPath? {
        if let told, let pointer, told.pointer == pointer, told.room.contains(pointer),
           room?.contains(pointer) != true {
            return told.room
        }

        told = room.map { (room: $0, pointer: pointer) }
        return room
    }

    /// What a press, or the pointer, at a point on the stage is on, on the asks panel as shown: while an answer is
    /// held, no answer's row nor Ignore, as it takes no other.
    func part(at point: CGPoint, mirror: CGAffineTransform) -> AsksPart? {
        shown.flatMap { Self.part(of: $0, at: point, mirror: mirror, holding: isHolding) }
    }

    private static func part(
        of shown: AsksShown, at point: CGPoint, mirror: CGAffineTransform, holding: Bool
    ) -> AsksPart? {
        guard shown.contains(point) else {
            return nil
        }

        let part = shown.layout.part(at: shown.ownPoint(point, mirror: mirror), sending: shown.sending != nil)

        switch part {
        case .answer?, .ignore?:
            return holding ? nil : part
        case .inClaude?, .snooze?, .open?, .undo?, nil:
            return part
        }
    }

    /// Whether what it shows has stood long enough to take a press (`settle`) since what sits under the pointer last
    /// changed meaning (`Look.meansOther`): a press meant for the ask, or the sending line's Undo, it showed a moment
    /// before never lands on what took its place.
    func isSettled(at time: Double) -> Bool {
        time - lookedAt >= Self.settle
    }

    /// How long, ms, what it shows stands before it takes a press.
    static let settle = 300.0

    private func placed(
        on ground: AsksGround, pointer: CGPoint?, layout: (PanelAsk) -> AsksLayout
    ) -> AsksShown? {
        guard let open, let panel = ground.panel, let page = page(in: ground.list, ground.board) else {
            return nil
        }

        let ask = page.asks[open.page], laid = layout(ask)
        let rowTop = panel.frame.minY + ground.list.content.laidFrame(page.index).minY - ground.scroll
        let frame = laid.frame(besideRowAt: rowTop, on: ground.stage)
        let sending = held.flatMap { Sending($0, to: ask, of: page.session.id) }
        var shown = AsksShown(
            row: open.row, session: page.session, ask: ask, page: open.page, pages: page.asks.count, layout: laid,
            frame: frame, sending: sending, hover: nil
        )

        shown.hover = pointer.flatMap { Self.part(of: shown, at: $0, mirror: ground.mirror, holding: isHolding) }
        return shown
    }

    /// The asks panel and the room between it and its row's arrow, as Mac submenus have a safe triangle: the hull of
    /// the asks panel's near side and the arrow's span, at the arrow's height and as far from the list's front as the
    /// arrow stands on the left edge, so a pointer on its way from the arrow crosses it past the list's corner. On
    /// the right edge, where the arrow stands at the row's other end, the same wedge: the list holds the way there.
    /// Internal only for the tests.
    static func room(of asks: AsksShown, on ground: AsksGround) -> CGPath {
        let room = CGMutablePath(), near = asks.frame.minX

        room.addRect(asks.frame)
        if let arrow = arrowSpan(of: asks, on: ground), arrow.x < near {
            room.addLines(between: [
                CGPoint(x: arrow.x, y: arrow.top), CGPoint(x: near, y: asks.frame.minY),
                CGPoint(x: near, y: asks.frame.maxY), CGPoint(x: arrow.x, y: arrow.bottom),
            ])
            room.closeSubpath()
        }
        return room
    }

    /// The near end of its row's arrow on the stage, as far from the list's front as on the left edge, and its top
    /// and bottom, as the panel and its scroll place it.
    private static func arrowSpan(
        of asks: AsksShown, on ground: AsksGround
    ) -> (x: Double, top: Double, bottom: Double)? {
        guard let panel = ground.panel, let index = ground.list.index(of: asks.row) else {
            return nil
        }

        let row = ground.list.content.laidFrame(index)
        let box = RowArrow.box(in: row.size).offsetBy(dx: row.minX, dy: row.minY)
        let top = panel.frame.minY + box.minY - ground.scroll

        return (panel.frame.minX + box.minX, top, top + box.height)
    }

    /// Its row, by its index in the list, its session and that session's asks, while it is open at a page they hold.
    private func page(in list: PanelList, _ board: PanelBoard) -> (index: Int, session: Session, asks: [PanelAsk])? {
        guard let open, let index = list.index(of: open.row), let session = list.item(index)?.session else {
            return nil
        }

        let asks = asks(of: session, on: board)

        return asks.indices.contains(open.page) && asks[open.page].id == open.ask ? (index, session, asks) : nil
    }

    private mutating func release(_ answering: Answering) {
        if held?.answering == answering {
            held = nil
        }
    }
}

/// Where the asks panel stands at a frame: the list and the board it shows them from, the open panel and its scroll,
/// and the screen and the edge's mirror.
struct AsksGround {
    let list: PanelList
    let board: PanelBoard
    let panel: Frame.Panel?
    let scroll: Double
    let stage: Stage
    let mirror: CGAffineTransform
}
