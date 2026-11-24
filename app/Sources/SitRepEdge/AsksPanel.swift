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

    private var open: Open?
    private var held: HeldAnswer?
    private var gone: Set<AskOf> = []

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

    /// The ask it shows, in its row's session, while it is open.
    func shownAsk(in list: PanelList, _ board: PanelBoard) -> PanelAsk? {
        page(in: list, board)?.asks[open?.page ?? 0]
    }

    /// As a frame shows it: beside its row as the panel and its scroll place the row on the stage, laid out by
    /// `layout`, kept on the screen, the answer held to its ask sending, and the part of it under `pointer` lit.
    func shown(
        in list: PanelList, _ board: PanelBoard, panel: Frame.Panel?, scroll: Double, pointer: CGPoint?,
        on stage: Stage, mirror: CGAffineTransform, layout: (PanelAsk) -> AsksLayout
    ) -> AsksShown? {
        guard let open, let panel, let page = page(in: list, board) else {
            return nil
        }

        let ask = page.asks[open.page], laid = layout(ask)
        let rowTop = panel.frame.minY + list.content.itemFrame(page.index).minY - scroll
        let frame = laid.frame(besideRowAt: rowTop, on: stage)
        let sending = held.flatMap { Sending($0, to: ask, of: page.session.id) }
        let hover = pointer.flatMap { point in
            AsksShown.contains(point, in: frame)
                ? laid.part(at: AsksShown.ownPoint(point, in: frame, mirror: mirror), sending: sending != nil) : nil
        }

        return AsksShown(
            row: open.row, session: page.session, ask: ask, page: open.page, pages: page.asks.count, layout: laid,
            frame: frame, sending: sending, hover: hover
        )
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
