import Foundation
import SitRepCore

/// SitRep's jump: finds where a session's windows show, and brings the first that answers to the front, on whatever
/// Space it is, along two axes. A multiplexer adapter says which clients show a window, and tmux's selects the pane's
/// tmux window where none does; a driver per terminal app finds the window on a device and brings it forward, and an
/// app with no driver is brought forward whole, once found running, never launched.
///
/// It jumps from the watch's last line, the session's windows in core's order, and runs off the main thread, its steps
/// one after another: a jump stopped, by a later click or its limit, ends between them, letting go of any step it
/// cannot stop, an Apple Event in flight.
public struct Jump: Sendable {
    /// How long a whole jump may take, the wait for the watch's first line among it. One takes under a second as
    /// Ghostty answers, a little over to a tab not selected, for its half second's pause, and one Ghostty does not
    /// answer at all, as with the screen locked, is refused at its first question, after 5s. Past this the Mac is too
    /// busy for a jump to land while Lee still wants it (4 November 2026).
    public static let limit = Duration.seconds(15)

    /// What a refusal names a session by that is not on the board, as one finished since a banner told of it.
    static let unnamed = "The session"

    let reader: ScreenReader
    let tmux: any TmuxProgram
    let drivers: [Driver: any TerminalDriver]
    let workspace: any Workspace
    let clock: any JumpClock

    init(
        reader: ScreenReader, tmux: any TmuxProgram, drivers: [Driver: any TerminalDriver], workspace: any Workspace,
        clock: any JumpClock
    ) {
        self.reader = reader
        self.tmux = tmux
        self.drivers = drivers
        self.workspace = workspace
        self.clock = clock
    }

    /// The jump on this Mac: tmux found on the PATH given, Lee's, and Ghostty asked by Apple Events.
    public static func live(path: String) -> Jump {
        let tmux = TmuxOnPath(path: path)
        let workspace = MacWorkspace()
        let clock = SystemClock()
        let ghostty = GhosttyDriver(scripting: GhosttyEvents(), workspace: workspace, clock: clock)

        return Jump(
            reader: ScreenReader(tmux: tmux), tmux: tmux, drivers: [.ghostty: ghostty], workspace: workspace,
            clock: clock
        )
    }

    /// Jumps to the session's window, on the board `board` gives once it has one, within `limit`: stopped, as its task
    /// is cancelled; unanswered at the limit.
    public func run(to session: String, on board: @escaping @Sendable () async -> JumpBoard.Read) async -> JumpAnswer {
        let answered = await answer(within: Self.limit, on: clock) {
            await jump(to: session, on: board())
        }

        return answered ?? (Task.isCancelled ? .stopped : .unanswered)
    }

    private func jump(to session: String, on read: JumpBoard.Read) async -> JumpAnswer {
        switch read {
        case let .unread(why):
            return .refused(why)
        case let .board(board):
            let name = board.name(of: session) ?? Self.unnamed

            do {
                return try await jump(to: board.jumpWindows(of: session)).answer(named: name)
            } catch {
                return .stopped
            }
        }
    }

    /// Brings the first of the windows a jump can reach to the front. Which app is in front is read beside the screen,
    /// and settled before any select or focus, so it is never an app brought forward by the jump itself.
    func jump(to windows: [Board.Window.Where]) async throws -> Jumped {
        async let before = workspace.frontmost()
        let screen = await reader.read(windows)
        let front = await before

        try Task.checkCancellation()

        return switch screen.reach(of: windows) {
        case let .onScreen(places):
            try await bringFirst(places, front: front)
        case .offScreen:
            .offScreen
        case let .unknown(unanswered):
            .unknown(unanswered)
        }
    }

    /// Brings forward the window at the first of the places that answers. A place that does not answer, or whose
    /// select tmux does not make, gives way to the next; an app that cannot be asked is passed over at its places
    /// after, so a Ghostty not answering costs its time once. Each select is made once however many places need it.
    /// The jump is refused once no place is left.
    private func bringFirst(_ places: [Place], front: String?) async throws -> Jumped {
        var selects: [Select: Selected] = [:]
        var passed: Set<TerminalApp> = []
        var missed: [Missed] = []

        for place in places where !passed.contains(place.app) {
            try Task.checkCancellation()

            guard let why = try await miss(place, front: front, selects: &selects) else {
                return .focused
            }

            if case .failed = why {
                passed.insert(place.app)
            }
            missed.append(why)
        }

        return Jumped(missed)
    }

    /// Brings forward the window at a place, tmux selecting its pane's window first where it must: nil once forward,
    /// else why not.
    private func miss(_ place: Place, front: String?, selects: inout [Select: Selected]) async throws -> Missed? {
        if let wanted = place.select {
            let selected: Selected

            if let made = selects[wanted] {
                selected = made
            } else {
                selected = await select(wanted)
            }
            selects[wanted] = selected

            guard case .done = selected else {
                return .unselected(said: selected.said)
            }
            try Task.checkCancellation()
        }

        do {
            return try await bring(place, front: front) ? nil : .unanswered(place)
        } catch let stopped as CancellationError {
            throw stopped
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// The window at the place brought forward: by its app's driver, on its device; an app with no driver whole, once
    /// found running.
    private func bring(_ place: Place, front: String?) async throws -> Bool {
        switch place.app {
        case let .driven(driver):
            guard let device = place.device, let driving = drivers[driver] else {
                return false
            }

            return try await driving.bringForward(on: device, front: front)
        case let .bundled(_, bundles):
            return await bringWhole(workspace.running(bundles))
        case let .atPath(_, path):
            return await bringWhole(workspace.running(at: path))
        }
    }

    private func bringWhole(_ app: RunningApp?) async -> Bool {
        guard let app else {
            return false
        }

        return await workspace.bringForward(app, on: clock)
    }

    /// Makes the select: the tmux window current in the tmux session, by their ids, within tmux's time limit.
    private func select(_ wanted: Select) async -> Selected {
        guard let ran = await tmux.run(on: wanted.socket, ["select-window", "-t", "\(wanted.session):\(wanted.window)"])
        else {
            return .undone(said: nil)
        }

        return ran.status == 0 ? .done : .undone(said: ran.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// How a select went: done; or not, in tmux's words, none where it gave no answer.
enum Selected: Equatable {
    case done
    case undone(said: String?)

    var said: String? {
        if case let .undone(said) = self { said } else { nil }
    }
}

/// Why a place brought nothing forward: its window not answering; tmux not making its select, in its words; or its
/// app unable to be asked, in plain words.
enum Missed: Equatable {
    case unanswered(Place)
    case unselected(said: String?)
    case failed(String)
}

/// What a jump came to: the window brought forward; no terminal window showing the session, nor any tmux could make
/// show it; none found, as what was asked gave no answer; devices showing it, in the apps named, where no window
/// answered; tmux not selecting the pane's window, in its words, or giving no answer; or its app unable to be asked.
enum Jumped: Equatable {
    case focused
    case offScreen
    case unknown([Unanswered])
    case unanswered(devices: [String], apps: [String])
    case unselected(said: String?)
    case failed(String)

    /// Why no place brought the window forward: what stopped the first, the one most wanted; where its window did not
    /// answer, every place whose window did not.
    init(_ missed: [Missed]) {
        let unanswered = missed.compactMap { each in
            if case let .unanswered(place) = each { place } else { nil }
        }
        var named: Set<String> = []

        switch missed.first {
        case let .failed(words)?:
            self = .failed(words)
        case let .unselected(said)?:
            self = .unselected(said: said)
        case .unanswered?:
            self = .unanswered(
                devices: unanswered.compactMap(\.device),
                apps: unanswered.map(\.app.name).filter { named.insert($0).inserted }
            )
        case nil:
            self = .offScreen
        }
    }

    /// What it came to, a refusal in plain words naming the session, as the CLI's jump said each.
    func answer(named name: String) -> JumpAnswer {
        switch self {
        case .focused:
            .jumped
        case .offScreen:
            .refused("\(name) is not on screen: no terminal window on this Mac shows it.")
        case let .unknown(unanswered):
            .refused("Could not tell whether \(name) is on screen: \(inWords(unanswered.map(\.words))) gave no answer.")
        case let .unanswered(devices, apps) where devices.isEmpty:
            .refused("\(name) shows in \(inWords(apps)), which did not come forward.")
        case let .unanswered(devices, apps):
            .refused("\(name) shows on \(inWords(devices)), but no \(inWords(apps, "or")) window there answered.")
        case let .unselected(said):
            .refused("\(name) is in a tmux window no terminal shows, and \(Self.whyUnselected(said))")
        case let .failed(words):
            .refused(words)
        }
    }

    /// Why tmux did not select a pane's window, in words: in tmux's, where it said any.
    private static func whyUnselected(_ said: String?) -> String {
        guard let said else {
            return "tmux gave no answer when asked to select it."
        }

        return said.isEmpty ? "tmux would not select it." : "tmux would not select it: \(said)"
    }
}

extension Unanswered {
    /// What gave no answer, as a refusal names it.
    var words: String {
        switch self {
        case .tmux: "tmux"
        case .processes: "the process table"
        }
    }
}

/// Things in words, as core's `inWords` puts them: `a`, `a and b`, `a, b and c`.
func inWords(_ things: [String], _ conjunction: String = "and") -> String {
    guard let last = things.last, things.count > 1 else {
        return things.joined()
    }

    return "\(things.dropLast().joined(separator: ", ")) \(conjunction) \(last)"
}
