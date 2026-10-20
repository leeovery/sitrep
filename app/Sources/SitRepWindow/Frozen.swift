import Foundation
import SitRepCore
import SitRepPanel

/// The asks of a session the page shows, kept in place while Lee reads it: in the order they first showed, the
/// newest first, as the pane's Asks list them; an ask closed meanwhile keeps its place, saying how it closed, until
/// another page is picked; a new one lands at the top, washed.
struct Frozen: Equatable, Sendable {
    let session: String
    /// Its asks by id, in the order they show.
    private var order: [String] = []
    /// Each ask as last read: a closed one shows as it last stood.
    private var known: [String: Board.Ask] = [:]
    /// Those closed since they first showed, and how.
    private var closed: [String: Card.Closed] = [:]
    /// Those new since the session first showed, washed from when they came, until their washes end.
    private(set) var washed: [String: Date] = [:]
    private var hasRead = false

    /// Its asks laid out from its board as last read, if it has been, until a fresh read lands.
    init(session: String, read board: SessionBoard?) {
        self.session = session
        if let board {
            take(board, washingAt: nil)
        }
    }

    /// The asks as they show: each as last read, and how it closed, if it has.
    var asks: [(ask: Board.Ask, closed: Card.Closed?)] {
        order.compactMap { id in known[id].map { ($0, closed[id]) } }
    }

    /// The asks closed since they showed, which Resolved leaves to Asks while they keep their places there.
    var kept: Set<String> { Set(closed.keys) }

    /// The session's board as read, what is new washed from this time, if one is given. The first read lays its asks
    /// out.
    mutating func take(_ board: SessionBoard, washingAt time: Date?) {
        let open = board.asks.reversed().map(\.id)
        let isOpen = Set(open)
        let new = hasRead ? open.filter { known[$0] == nil } : []

        for ask in board.asks {
            known[ask.id] = ask
        }
        for ask in order {
            closed[ask] = isOpen.contains(ask) ? nil : closed[ask] ?? Card.closed(ask, in: board)
        }
        order = hasRead ? new + order : open
        hasRead = true
        if let time {
            new.forEach { washed[$0] = time }
        }
    }

    /// The washes ended by this time let go.
    mutating func prune(at time: Date) {
        washed = Wash.live(washed, at: time)
    }
}
