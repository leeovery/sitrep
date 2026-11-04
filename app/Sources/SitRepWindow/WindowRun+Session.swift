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
        let happened = SessionPage.happened(notes, asks: kept?.asks ?? [], of: session.id)
        let resolved = details.resolved(of: session.id)
        let cards = details.cards(of: session, at: time)
        let items = status.now.enumerated().map { Item.status($0.offset, $0.element) } + (status.next.map { [Item.next($0)] } ?? [])
            + notes.map { .note($0.id) } + resolved.map { .resolved($0.id) } + (resolved.isEmpty ? [] : [.resolvedFold])

        return SessionPage(
            id: session.id, mode: mode, projectKey: project.key, projectName: project.name, name: session.name,
            meta: meta(of: session, on: board), doing: session.doing, jumps: !isAway, waiting: session.waiting,
            lead: Self.lead(pick, of: session, among: cards, on: board), asks: cards,
            status: status, parked: session.parked, happened: happened, resolved: resolved,
            finish: isAway ? details.finish(of: session.id) : nil,
            hasBoard: kept != nil,
            failure: details.failure(of: session.id) ?? (kept == nil ? unwatched : nil),
            opened: details.keepOpen(items)
        )
    }

    /// Where its window is, from the board's windows and the last look at the screen, and when it started; away, the
    /// line saying no window holds it.
    private func meta(of session: Board.Session, on board: Board) -> SessionPage.Meta {
        guard !session.doing.isAway else {
            return SessionPage.Meta(terminal: nil, onScreen: nil, started: nil, away: session.doing.line.lead)
        }

        let window = board.windows.first { $0.session == session.id }

        return SessionPage.Meta(
            terminal: window?.where?.terminal, onScreen: onScreen(of: session.id), started: session.created, away: nil
        )
    }

    /// What leads the detail of a line picked in Needs you, or under its "N snoozed": the card of the ask it is, kept
    /// faint while the page holds as it closes; or the window's stop it is, while it stands. None for a session's row.
    private static func lead(
        _ pick: ListPick?, of session: Board.Session, among cards: [Card], on board: Board
    ) -> SessionPage.Lead? {
        let key: String? = switch pick {
        case let .line(key), let .snoozed(key): key
        case .session, .parked, nil: nil
        }
        guard let key else {
            return nil
        }

        if let card = cards.first(where: { $0.key == key }) {
            return .ask(card)
        }

        let isStop = board.rows.contains { row in
            row.session == session.id
                && row.lines.contains { $0.key == key && [.permission, .question].contains($0.kind) }
        }

        return isStop && session.doing.isStopped ? .stop : nil
    }

    /// What a session's page with no board kept says while the board is stale, so no board can come: the head's
    /// words for it, and why.
    private var unwatched: String? {
        last.stale.map { "\(PanelBoard.unread.title). \($0)" }
    }
}
