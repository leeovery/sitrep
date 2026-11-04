import Foundation
import SitRepCore

extension WindowRun {
    /// How many of its latest notes a project's view lists, as many as a session's board carries.
    private static let projectNotes = 8

    /// A project's page at this time, from its sessions' boards as last kept.
    func projectPage(_ project: Board.Project, on board: Board, at time: Date) -> ProjectPage {
        let needs = board.rows.filter { $0.project == project.key && $0.needsLee }
        let waiting = { (rows: [Board.Row]) in rows.map(\.lines.count).reduce(0, +) }
        let kept = project.sessions.compactMap { session in details.board(of: session.id).map { (session, $0) } }
        let named = project.sessions.count > 1
        let notes = Array(kept.flatMap { Note.notes($1.log, of: $0, named: named) }.sorted { $0.at > $1.at }.prefix(Self.projectNotes))
        let parked = kept.flatMap { Parked.items(of: $1, from: $0, named: named) }.sorted { $0.at < $1.at }

        return ProjectPage(
            key: project.key, name: project.name, waiting: waiting(needs), open: project.open,
            sessions: project.sessions.map { session in
                ProjectPage.Session(
                    id: session.id, name: session.name, mark: Mark(session.state, isAway: session.doing.isAway),
                    isAway: session.doing.isAway,
                    doing: session.doing,
                    waiting: waiting(needs.filter { $0.session == session.id }), since: session.since
                )
            },
            asksWaiting: project.sessions.map(\.waiting).reduce(0, +),
            asks: project.sessions.flatMap { session in
                details.cards(of: session, at: time).map { card in
                    ProjectPage.Ask(session: named ? session.name : nil, card: card, isOpened: details.isOpened(card.id))
                }
            }.sorted { $0.card.since > $1.card.since },
            notes: notes,
            parked: parked,
            opened: details.keepOpen(notes.map { .note($0.id) } + parked.map { .parked($0.id) })
        )
    }
}
