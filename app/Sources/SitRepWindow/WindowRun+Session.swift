import Foundation
import SitRepCore
import struct SitRepEdge.PanelBoard

extension WindowRun {
    /// A session's page at this time, from its board as last kept: beside a place's list, led by the card of the line
    /// its list picked, where that is a line; or filling the window, where nothing is picked, so nothing leads.
    func sessionPage(
        _ session: Board.Session, of project: Board.Project, on board: Board, as mode: SessionPage.Mode,
        leading pick: ListPick? = nil, at time: Date
    ) -> SessionPage {
        let kept = details.board(of: session.id)
        let isAway = session.doing.isAway
        let status = Status(now: session.now, next: session.next, updated: kept?.log.first { $0.kind == .status }?.at)
        let notes = kept.map { Note.notes($0.log, of: session, named: false) } ?? []
        let cards = details.cards(of: session, at: time)
        let asked = mode == .full ? cards.map(SessionPage.Asked.init) : []
        let happened = SessionPage.happened(notes, asks: asked)
        let resolved = details.resolved(of: session.id)
        let items = status.now.enumerated().map { Item.status($0.offset, $0.element) } + (status.next.map { [Item.next($0)] } ?? [])
            + notes.map { .note($0.id) } + asked.map { .asked($0.id) } + resolved.map { .resolved($0.id) }
            + (resolved.isEmpty ? [] : [.resolvedFold])

        return SessionPage(
            id: session.id, mode: mode, projectKey: project.key, projectName: project.name, name: session.name,
            meta: mode == .full ? meta(of: session, on: board) : nil, doing: session.doing, jumps: !isAway,
            waiting: session.waiting, lead: lead(pick, of: session, on: board, among: cards), asks: cards,
            status: status, parked: session.parked, happened: happened, resolved: resolved,
            finish: isAway ? details.finish(of: session.id) : nil,
            hasBoard: kept != nil,
            failure: details.failure(of: session.id) ?? (kept == nil ? unwatched : nil),
            opened: details.keepOpen(items)
        )
    }

    /// Where its window is, from the board's windows and the last look at the screen, and when it started; away, the
    /// line saying no window holds it. Of several windows, the one a jump goes to first.
    private func meta(of session: Board.Session, on board: Board) -> SessionPage.Meta {
        guard !session.doing.isAway else {
            return SessionPage.Meta(
                terminal: nil, app: nil, onScreen: nil, started: nil, away: session.doing.line.lead
            )
        }

        let window = board.windows.filter { $0.session == session.id }.min(by: Self.jumpsFirst)

        return SessionPage.Meta(
            terminal: window?.where?.terminal, app: appShowing(session.id), onScreen: onScreen(of: session.id),
            started: session.created, away: nil
        )
    }

    /// Whether a jump tries this window before that one, as the CLI orders a session's windows (cli/screen.ts's
    /// `byJump`): one stopped on Lee first, then one working, then one on its own work, then the rest; within each, the
    /// latest to begin its state, then the one attached last.
    private static func jumpsFirst(_ one: Board.Window, _ other: Board.Window) -> Bool {
        let rank = { (window: Board.Window) -> Int in
            switch window.state?.kind {
            case .permission, .question: 0
            case .working: 1
            case .onItsWork: 2
            case .yourTurn, nil: 3
            }
        }
        let since = { (window: Board.Window) in window.state?.since ?? window.attachedAt }

        return (rank(one), since(other), other.attachedAt) < (rank(other), since(one), one.attachedAt)
    }

    /// The line of the session's row in Needs you with this key, while the row has it: a line, or an ask asleep under
    /// "N snoozed", whose key an ask keeps in both.
    private static func line(_ key: String, of session: Board.Session, on board: Board) -> Board.Row.Line? {
        board.rows.first { $0.session == session.id }?.lines.first { $0.key == key }
    }

    /// What leads the detail of a line picked in Needs you, or under its "N snoozed": the card of the ask it is, kept
    /// faint while the page holds as it closes; one built from the board's ask while the session's own board has yet
    /// to carry it, as on a first pick of a session not followed before; or the window's stop it is, while its line
    /// stands. None for a session's row.
    private func lead(
        _ pick: ListPick?, of session: Board.Session, on board: Board, among cards: [Card]
    ) -> SessionPage.Lead? {
        guard let key = pick?.lineKey else {
            return nil
        }

        let carried = session.asks.first { AskAddress(session: session.id, ask: $0.id).key == key }

        if let card = cards.first(where: { $0.id.key == key }) ?? carried.map({ details.card($0, of: session) }) {
            return .ask(card)
        }
        return Self.line(key, of: session, on: board).flatMap(SessionPage.Stop.init).map(SessionPage.Lead.stop)
    }

    /// What a session's page with no board kept says while the board is stale, so no board can come: the head's
    /// words for it, and why.
    private var unwatched: String? {
        last.stale.map { "\(PanelBoard.unread.title). \($0)" }
    }
}

extension ListPick {
    /// Its line's key, for a line or an ask asleep (`AskAddress.key`); none for a session's row or a parked item.
    var lineKey: String? {
        switch self {
        case let .line(key), let .snoozed(key): key
        case .session, .parked: nil
        }
    }
}
