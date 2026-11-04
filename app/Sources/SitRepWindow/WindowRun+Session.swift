import Foundation
import SitRepCore
import struct SitRepEdge.PanelBoard

extension WindowRun {
    /// A session's page at this time, from its board as last kept.
    func sessionPage(_ session: Board.Session, of project: Board.Project, at time: Date) -> SessionPage {
        let kept = details.board(of: session.id)
        let isAway = session.doing.isAway
        let status = Status(now: session.now, next: session.next, updated: kept?.log.first { $0.kind == .status }?.at)
        let notes = kept.map { Details.notes($0.log, of: session, named: false) } ?? []
        let parked = kept?.parked.map { Parked(id: $0.id, session: nil, title: $0.title, where: $0.where, at: $0.at) } ?? []
        let resolved = details.resolved(of: session.id)
        let items = status.now.enumerated().map { Item.status($0.offset, $0.element) } + (status.next.map { [Item.next($0)] } ?? [])
            + notes.map { .note($0.id) } + parked.map { .parked($0.id) } + resolved.map { .resolved($0.id) }

        return SessionPage(
            id: session.id, projectKey: project.key, projectName: project.name, name: session.name,
            summary: session.summary, doing: session.doing, jumps: !isAway, waiting: session.waiting,
            snoozed: session.snoozed, asks: details.cards(of: session, at: time), status: status, notes: notes,
            parked: parked, resolved: resolved,
            finish: isAway ? details.finish(of: session.id) : nil,
            hasBoard: kept != nil,
            failure: details.failure(of: session.id) ?? (kept == nil ? unwatched : nil),
            opened: details.keepOpen(items)
        )
    }

    /// What a session's page with no board kept says while the board is stale, so no board can come: the head's
    /// words for it, and why.
    private var unwatched: String? {
        last.stale.map { "\(PanelBoard.unread.title). \($0)" }
    }
}
