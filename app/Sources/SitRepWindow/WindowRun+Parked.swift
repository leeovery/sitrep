import Foundation
import SitRepCore

extension WindowRun {
    /// The page of an item parked, by its id, of its session, from the board and the session's board as last kept, the
    /// session followed as the item is picked; a line saying so where the board no longer has it.
    func parkedPage(_ id: String, of session: String, on board: Board) -> Page {
        guard let found = board.session(session), let item = found.session.parkedItems.first(where: { $0.id == id })
        else {
            return .noLongerParked
        }

        let kept = details.board(of: session)
        let since = ParkedPage.since(kept.map { Note.notes($0.log, of: found.session) } ?? [], parkedAt: item.at)

        return .parked(ParkedPage(
            item: item, projectKey: found.project.key, projectName: found.project.name,
            from: ParkedPage.From(found.session), since: since.lines, isSinceCut: since.isCut,
            looked: YouLooked(looked[session], over: since.lines.map(\.at)), hasBoard: kept != nil,
            failure: details.failure(of: session) ?? (kept == nil ? unwatched : nil),
            opened: details.keepOpen(since.lines.map { .note($0.id) })
        ))
    }
}
