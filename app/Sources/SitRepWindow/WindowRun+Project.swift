import Foundation
import SitRepCore

extension WindowRun {
    /// A project's page at this time, from the board and its sessions' boards as last kept: the lines waiting on Lee
    /// as Needs you lists them, an ask washed as it comes, and one closed while the page is held kept in its place; each
    /// session's status as its row and its board have it, the sessions in the order the page last listed them while it
    /// is held; and which of them no terminal shows, as the last look at the screen says.
    func projectPage(_ project: Board.Project, at time: Date) -> ProjectPage {
        let listed = Listed(last)
        let rows = listed.needsYou.filter { listed.homes[$0.id] == project.key }
        let cards = project.sessions.flatMap { details.cards(of: $0, at: time) }
        let waiting = (rows.flatMap { row in row.lines.map { waitingLine($0, of: row, cards: cards) } }
            + closedWhileHeld(cards, leaving: rows, of: project)).sorted { $0.order < $1.order }
        let sessions = Dictionary(project.sessions.map { ($0.id, $0) }) { first, _ in first }

        return ProjectPage(
            key: project.key, name: project.name,
            sessions: details.order(project.sessions.map(\.id)).compactMap { sessions[$0] }.map { session in
                projectSession(session, asks: waiting.filter { $0.session == session.id && !$0.isClosed && $0.line.ask != nil }.count)
            },
            waiting: waiting, parked: project.parked
        )
    }

    private func projectSession(_ session: Board.Session, asks: Int) -> ProjectPage.Session {
        let kept = details.board(of: session.id)

        return ProjectPage.Session(
            id: session.id, name: session.name, mark: Mark(session.state, isAway: session.doing.isAway),
            isAway: session.doing.isAway, isOffScreen: isOffScreen(session.id, isAway: session.doing.isAway),
            standing: ProjectPage.Standing(session.doing, asks: asks), since: session.since,
            now: session.now.first, next: session.next,
            updated: kept?.log.first { $0.kind == .status }?.at ?? session.updatedAt,
            log: kept.map { Array(Note.notes($0.log, of: session).prefix(ProjectPage.logLines)) } ?? []
        )
    }

    /// A line of a session's row in Needs you, an ask washed as its card is.
    private func waitingLine(_ line: Listed.Line, of row: Listed.Row, cards: [Card]) -> ProjectPage.Line {
        var shown = line

        shown.washed = line.ask.flatMap { ask in cards.first { $0.id == AskAddress(session: row.id, ask: ask) }?.washed }
        return ProjectPage.Line(
            line: shown, session: row.id, sessionName: row.name, isAway: row.isAway,
            isOffScreen: isOffScreen(row.id, isAway: row.isAway),
            isClosed: false
        )
    }

    /// The asks closed while the page is held, which their rows no longer have, each kept as a line, faint; not one
    /// that closed asleep, which was never among them.
    private func closedWhileHeld(_ cards: [Card], leaving rows: [Listed.Row], of project: Board.Project) -> [ProjectPage.Line] {
        let open = Set(rows.flatMap { row in row.lines.compactMap { $0.ask.map { AskAddress(session: row.id, ask: $0) } } })

        return cards.filter { $0.isClosed && $0.wakesAt == nil && !open.contains($0.id) }.compactMap { card in
            project.sessions.first { $0.id == card.id.session }.map { session in
                ProjectPage.Line(
                    line: Listed.Line(id: "ask:\(session.id):\(card.id.ask)", ask: card.id.ask, lead: card.title, code: nil, more: nil, since: card.since),
                    session: session.id, sessionName: session.name, isAway: card.isAway,
                    isOffScreen: isOffScreen(session.id, isAway: card.isAway),
                    isClosed: true
                )
            }
        }
    }

    /// The last look at the screen says no terminal shows the session, which a window holds; nothing where it says it
    /// does, it could not tell, or it has not looked, nor for an away session, which no terminal could show.
    private func isOffScreen(_ session: String, isAway: Bool) -> Bool {
        !isAway && onScreen(of: session) == .off
    }
}

extension ProjectPage.Standing {
    /// Where a session stands, its asks waiting on Lee given: a window's stop, or its asks, first; else what its window
    /// is doing.
    init(_ doing: Doing, asks: Int) {
        switch doing.kind {
        case .permission, .question: self = .waits(stop: doing.kind, asks: asks)
        case _ where asks > 0: self = .waits(stop: nil, asks: asks)
        case .working, .onItsWork: self = .doing(doing.kind, doing.line)
        case .yourTurn: self = .yourTurn
        case .away: self = .away
        }
    }
}

private extension ProjectPage.Line {
    /// Needs you's order (`PlaceList`): a session a window holds before one none does, then the newest first, then by
    /// key.
    var order: (Int, TimeInterval, String) { (isAway ? 1 : 0, -line.since.timeIntervalSince1970, line.id) }
}
