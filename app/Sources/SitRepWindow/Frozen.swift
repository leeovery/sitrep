import Foundation
import SitRepCore
import SitRepPanel

/// The asks of a session the page shows, kept in place while Lee reads it: in the order they first showed, the
/// newest first, as the pane's Asks list them; an ask closed meanwhile keeps its place, saying how it closed, until
/// it is let go; a new one lands at the top, washed.
struct Frozen: Equatable, Sendable {
    let session: String
    /// Its asks by id, in the order they show.
    private var order: [String] = []
    /// Each ask as its board last had it: a closed one shows as it last stood.
    private var known: [String: Board.Ask] = [:]
    /// Those closed since they first showed, and how.
    private var closed: [String: Card.Closed] = [:]
    /// Those new since the session first showed, washed from when they came, until their washes end.
    private(set) var washed: [String: Date] = [:]
    /// Its first board has come: the boards after it are compared against it.
    private var hasBoard = false

    /// Its asks laid out from its board as last kept, if there is one. A current board, its session followed without
    /// a break since it came, is its first, as `watch` carries no other until it changes; else its next board to come
    /// is, and lays them out again.
    init(session: String, kept board: SessionBoard?, isCurrent: Bool) {
        self.session = session
        if let board {
            layOut(board)
            hasBoard = isCurrent
        }
    }

    /// The asks as they show: each as its board last had it, and how it closed, if it has.
    var asks: [(ask: Board.Ask, closed: Card.Closed?)] {
        order.compactMap { id in known[id].map { ($0, closed[id]) } }
    }

    /// The asks closed since they showed, which Resolved leaves to Asks while they keep their places there.
    var kept: Set<String> { Set(closed.keys) }

    /// The session's board as a line carried it, what is new washed from this time, if one is given. Its first board
    /// lays its asks out, washing nothing and keeping nothing closed: Lee saw neither come nor go.
    mutating func take(_ board: SessionBoard, washingAt time: Date?) {
        guard hasBoard else {
            layOut(board)
            hasBoard = true
            return
        }

        let open = board.asks.reversed().map(\.id)
        let isOpen = Set(open)
        let new = open.filter { known[$0] == nil }

        for ask in board.asks {
            known[ask.id] = ask
        }
        for ask in order {
            closed[ask] = isOpen.contains(ask) ? nil : closed[ask] ?? Card.closed(ask, in: board)
        }
        order = new + order
        if let time {
            new.forEach { washed[$0] = time }
        }
    }

    /// The asks closed since they showed let go, but for those named, so they leave the asks for Resolved, as a page
    /// picked afresh shows them.
    mutating func letGoOfClosed(but staying: Set<String>) {
        let leaving = Set(closed.keys).subtracting(staying)

        order.removeAll(where: leaving.contains)
        for ask in leaving {
            known[ask] = nil
            closed[ask] = nil
            washed[ask] = nil
        }
    }

    /// Its asks as this board has them, the newest first.
    private mutating func layOut(_ board: SessionBoard) {
        order = board.asks.reversed().map(\.id)
        known = Dictionary(board.asks.map { ($0.id, $0) }) { first, _ in first }
    }

    /// The washes ended by this time let go.
    mutating func prune(at time: Date) {
        washed = Wash.live(washed, at: time)
    }
}
