import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow

/// `watch` as the window hears it, carrying a session's board only as the real CLI does (`cli/follow.ts`): as the
/// session is new to the set followed, and again only as its board changes, nothing while neither; a session let go of
/// is new once followed again, and every session followed is new to a run started again. With the app's part: the set
/// told after each move of Lee's, as the window's model tells it, and a look at once.
final class Watching {
    let run = WindowRun(wall: { printedAt })
    /// Each session's board as it stands, as the real CLI printed it, or null where `watch` finds none.
    private var boards: [String: String?] = [
        "sr-macapp": Lines.board, "sr-dash02": Lines.dashboard, "sr-rq7dgr": Lines.ledger, "sr-gs7kq2": Lines.away,
    ]
    /// What the run under way last carried of each session followed.
    private var carried: [String: String?] = [:]
    private var last = LastBoard()
    private var isRunning = true

    /// The window, not yet open, over `watch`'s first line.
    init() {
        last.begin()
        hear(Lines.watch[0], at: printedAt)
    }

    /// Lee moves in the window at this time: the app tells `watch` the set, and it looks.
    func after(_ move: (WindowRun) -> Void, at time: Date = printedAt) {
        move(run)
        look(at: time)
    }

    /// A session's board changes as it stands at this time, and `watch` looks, while it runs.
    func change(_ session: String, to board: String?, at time: Date = printedAt) {
        boards.updateValue(board, forKey: session)
        look(at: time)
    }

    /// `watch` ends at this time, and the board goes stale.
    func ends(at time: Date) {
        isRunning = false
        _ = last.hear(.exited(.status(1), stderr: ""), at: time)
        run.show(last, at: time, reducesMotion: false)
    }

    /// `watch` starts again at this time, told the set, its first line carrying every board followed.
    func startsAgain(at time: Date) {
        isRunning = true
        carried = [:]
        last.begin()
        look(at: time, isRunsFirst: true)
    }

    /// The window's set told, those let go of forgotten; then, while `watch` runs, a line carrying each board new to
    /// the set or changed, printed only where it carries one, or as a run's first.
    private func look(at time: Date, isRunsFirst: Bool = false) {
        let told = run.follow()

        guard isRunning else {
            return
        }

        var carrying: [String: String?] = [:]

        carried = carried.filter { told.contains($0.key) }
        for session in told {
            let board = boards[session] ?? nil

            if carried[session] != .some(board) {
                carrying.updateValue(board, forKey: session)
                carried.updateValue(board, forKey: session)
            }
        }
        if isRunsFirst || !carrying.isEmpty {
            hear(Lines.carrying(carrying, on: Lines.watch[0]), at: time)
        }
    }

    private func hear(_ line: String, at time: Date) {
        _ = last.hear(.line(line), at: time)
        run.show(last, at: time, reducesMotion: false)
    }
}
