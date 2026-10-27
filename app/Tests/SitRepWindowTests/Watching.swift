import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow

/// `watch` as the window hears it, carrying a session's board only as the real CLI does (`cli/follow.ts`): as the
/// session is new to the set it was told, and again only as its board changes, nothing while neither; a session let go
/// of is new once told again, and every session told is new to a run started again. Each line is from a look at the
/// time given, and may be held in flight, so the window hears it after a set told since. With the app's part: the
/// window's set told after each move of Lee's and each line heard, as the window's model tells it.
final class Watching {
    let run = WindowRun(wall: { printedAt })
    /// The board's line as it stands, but for its time and the boards it carries.
    private var line = Lines.watch[0]
    /// Each session's board as it stands, as the real CLI printed it, or null where `watch` finds none.
    private var boards: [String: String?] = [
        "sr-macapp": Lines.board, "sr-dash02": Lines.dashboard, "sr-rq7dgr": Lines.ledger, "sr-gs7kq2": Lines.away,
    ]
    /// The set `watch` was last told, and what its run under way last carried of each session in it.
    private var told: Set<String> = []
    private var carried: [String: String?] = [:]
    private var last = LastBoard()
    private var isRunning = true
    /// The lines printed and not yet heard, in order, each with the time of its look, while lines are held in flight.
    private var inFlight: [(line: String, at: Date)] = []
    /// Lines printed from now on stay in flight until they land.
    var isHolding = false

    /// The window, not yet open, over `watch`'s first line.
    init() {
        last.begin()
        prints(carrying: [:], at: printedAt)
    }

    /// Lee moves in the window at this time: the app tells `watch` the set.
    func after(_ move: (WindowRun) -> Void, at time: Date = printedAt) {
        move(run)
        tell(at: time)
    }

    /// A session's board changes as it stands at this time, the board's line too, if another is given, and `watch`
    /// looks, while it runs.
    func change(_ session: String, to board: String?, line: String? = nil, at time: Date = printedAt) {
        boards.updateValue(board, forKey: session)
        self.line = line ?? self.line
        look(at: time)
    }

    /// The lines in flight land, the first so many of them, or all.
    func lands(_ count: Int? = nil) {
        let landing = inFlight.prefix(count ?? inFlight.count)

        inFlight.removeFirst(landing.count)
        landing.forEach { hear($0.line, at: $0.at) }
    }

    /// `watch` ends at this time, and the board goes stale.
    func ends(at time: Date) {
        isRunning = false
        _ = last.hear(.exited(.status(1), stderr: ""), at: time)
        run.show(last, at: time, reducesMotion: false)
        tell(at: time)
    }

    /// `watch` starts again at this time, told the set, its first line carrying every board in it.
    func startsAgain(at time: Date) {
        isRunning = true
        carried = [:]
        last.begin()
        look(at: time, isRunsFirst: true)
    }

    /// The window's set, told where it changed: `watch` lets go of those left out, and looks at once.
    private func tell(at time: Date) {
        let set = run.follow()

        guard set != told else {
            return
        }

        told = set
        carried = carried.filter { set.contains($0.key) }
        look(at: time)
    }

    /// While `watch` runs, a line carrying each board told that is new to it or changed, printed only where it
    /// carries one, or as a run's first.
    private func look(at time: Date, isRunsFirst: Bool = false) {
        guard isRunning else {
            return
        }

        var carrying: [String: String?] = [:]

        for session in told {
            let board = boards[session] ?? nil

            if carried[session] != .some(board) {
                carrying.updateValue(board, forKey: session)
                carried.updateValue(board, forKey: session)
            }
        }
        if isRunsFirst || !carrying.isEmpty {
            prints(carrying: carrying, at: time)
        }
    }

    private func prints(carrying: [String: String?], at time: Date) {
        let looked = edited(line) { $0["at"] = Int64((time.timeIntervalSince1970 * 1000).rounded()) }
        let printed = Lines.carrying(carrying, on: looked)

        if isHolding {
            inFlight.append((printed, time))
        } else {
            hear(printed, at: time)
        }
    }

    /// The window hears the line, and the app tells `watch` the set, as it does after each line.
    private func hear(_ printed: String, at time: Date) {
        _ = last.hear(.line(printed), at: time)
        run.show(last, at: time, reducesMotion: false)
        tell(at: time)
    }
}
