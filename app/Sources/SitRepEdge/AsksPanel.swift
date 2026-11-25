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

    /// What it shows, for a press to tell a change of meaning by: beside which row, which holds its session, where on
    /// the stage and when, on the display's clock, its ask as it reads, and whether an answer to it is held.
    private struct Look {
        let row: String
        let place: CGPoint
        let time: Double
        let ask: PanelAsk
        let isSending: Bool

        init(_ shown: AsksShown, at time: Double) {
            row = shown.row
            place = shown.frame.origin
            self.time = time
            ask = shown.ask
            isSending = shown.sending != nil
        }

        /// Whether, shown after `was`, what sits under the pointer means something else: another ask, or the same one
        /// changed, in the same place; the sending line gone, its Undo's place another part's; or, with the pointer on
        /// it, it moved under the pointer, as a row landing above its own slides it down. Not opening, nor moving to
        /// another row, where nothing of it sat under the pointer; nor a hold, the sending line coming where the foot
        /// was, whose Undo a fast press is meant for.
        func meansOther(than was: Look?, pointerOn: Bool) -> Bool {
            guard let was, was.row == row else {
                return false
            }

            let moved = hypot(place.x - was.place.x, place.y - was.place.y)
                > max(Self.snap, Self.settling * (time - was.time) / 1000)

            return was.ask != ask || (was.isSending && !isSending) || (pointerOn && moved)
        }

        /// How fast, pt/s, it moves as the panel's springs settle, which is no move: half a point a frame at 60Hz,
        /// where a row landing above slides it at up to 300.
        private static let settling = 30.0
        /// How far, pt, a spring snaps as it comes to rest, which is no move, though two placings share a time.
        private static let snap = 0.01
    }

    private var open: Open?
    private var held: HeldAnswer?
    private var gone: Set<AskOf> = []
    /// As the last frame placed it; nil while it is closed.
    private(set) var shown: AsksShown?
    /// Where the notch was last told it stands, with the pointer then (`beside`).
    private var told: (room: CGRect, pointer: CGPoint?)?
    /// The way to it from the list.
    private var way = SafeTriangle()
    /// A horizontal swipe on it, which pages it.
    private var swipe = AsksSwipe()
    private var look: Look?
    private var lookedAt = -Double.infinity
    /// The row it opened beside, and how far the list was scrolled then.
    private var opened: (row: String, scroll: Double)?

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

    /// The list scrolled this far: closed once that moves it more than `scrollMost` from where it was as it opened, as
    /// a Mac menu's scroll closes its submenu.
    mutating func scrolled(to scroll: Double) {
        if let opened, abs(scroll - opened.scroll) > Self.scrollMost {
            close()
        }
    }

    /// The list's scroll moved by this much with no scroll, kept within the list as it shrank: how far a scroll has
    /// moved it since it opened stays as it was.
    mutating func listShifted(by shift: Double) {
        opened?.scroll += shift
    }

    /// How far, pt, the list scrolls under it before it closes: the few points of a sideways swipe's drift or a
    /// brush on a Magic Mouse leave it open; a third of a row's height is a scroll meant.
    static let scrollMost = 10.0

    /// Whether the way to it from the list holds the pointer, which must be judged frame by frame until it ends.
    var isFindingWay: Bool { way.holds }

    /// Kept to what shows: closed while the panel is not open, its row gone or none of its asks left; else at its
    /// ask, or, where that left, the one that took its page, or the last.
    mutating func keep(isOpen: Bool, _ list: PanelList, _ board: PanelBoard) {
        guard let open else {
            return
        }
        guard isOpen, let asks = asks(of: open.row, in: list, board), !asks.isEmpty else {
            return close()
        }

        let page = asks.firstIndex { $0.id == open.ask } ?? min(open.page, asks.count - 1)

        self.open = Open(row: open.row, ask: asks[page].id, page: page)
    }

    /// At the ask on this page of its row's session's, where it has one (DESIGN, "Paging").
    mutating func page(to page: Int, _ list: PanelList, _ board: PanelBoard) {
        guard let open, let asks = asks(of: open.row, in: list, board), asks.indices.contains(page) else {
            return
        }

        self.open = Open(row: open.row, ask: asks[page].id, page: page)
    }

    /// A scroll on it: a horizontal swipe's gesture steps to the next ask or the previous one, once (`AsksSwipe`).
    mutating func swiped(_ scroll: Scroll, at time: Double, _ list: PanelList, _ board: PanelBoard) {
        if let step = swipe.step(scroll, at: time), let open {
            page(to: open.page + step, list, board)
        }
    }

    /// The asks the asks panel answers of the session of the row `key`, while the list holds it.
    private func asks(of key: String, in list: PanelList, _ board: PanelBoard) -> [PanelAsk]? {
        list.index(of: key).flatMap { list.item($0)?.session }.map { asks(of: $0, on: board) }
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
    /// lit; and, where what sits under the pointer changed meaning (`Look.meansOther`), when, on the display's clock.
    mutating func place(
        on ground: AsksGround, pointer: CGPoint?, at time: Double, layout: (PanelAsk) -> AsksLayout
    ) {
        shown = placed(on: ground, pointer: pointer, layout: layout)
        if opened?.row != shown?.row {
            opened = shown.map { ($0.row, ground.scroll) }
        }

        let look = shown.map { Look($0, at: time) }, pointerOn = pointer.map { shown?.contains($0) == true } ?? false

        if look?.meansOther(than: self.look, pointerOn: pointerOn) == true {
            lookedAt = time
        }
        self.look = look
    }

    /// The room the notch is told the pointer is on (`Input.beside`): the asks panel, or, where it went from under a
    /// pointer that has not moved since, as it closed or shrank, the room it had, so that is no leave until the pointer
    /// moves; and the way to it from the list while that holds the pointer (`SafeTriangle`).
    mutating func beside(_ pointer: CGPoint?, onList: Bool, at time: Double) -> CGPath? {
        let room = kept(pointer), triangle = way.holding(pointer, onList: onList, toward: shown?.frame, at: time)

        guard let room else {
            return triangle
        }

        let beside = CGMutablePath()

        beside.addRect(room)
        triangle.map { beside.addPath($0) }
        return beside
    }

    private mutating func kept(_ pointer: CGPoint?) -> CGRect? {
        let room = shown?.frame

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

        let part = shown.layout.part(
            at: shown.ownPoint(point, mirror: mirror), sending: shown.sending != nil, page: shown.page, of: shown.pages
        )

        switch part {
        case .answer?, .ignore?:
            return holding ? nil : part
        case .page?, .snooze?, .open?, .undo?, nil:
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
        let frame = laid.frame(besideRowAt: rowTop, front: panel.frame.maxX, on: ground.stage)
        let sending = held.flatMap { Sending($0, to: ask, of: page.session.id) }
        var shown = AsksShown(
            row: open.row, session: page.session, ask: ask, page: open.page, pages: page.asks.count, layout: laid,
            frame: frame, sending: sending, hover: nil
        )

        shown.hover = pointer.flatMap { Self.part(of: shown, at: $0, mirror: ground.mirror, holding: isHolding) }
        return shown
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
