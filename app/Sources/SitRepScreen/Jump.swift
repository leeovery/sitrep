import Foundation
import os
import SitRepCore

/// SitRep's jump: finds where a session's windows show, and brings the first that answers to the front, on whatever
/// Space it is, along two axes. A multiplexer adapter says which clients show a window, and tmux's selects the pane's
/// tmux window where none does; a driver per terminal app finds the window on a device and brings it forward, and an
/// app with no driver is brought forward whole, once found running, never launched.
///
/// It jumps from the watch's last line, the session's windows in core's order, and runs off the main thread, its steps
/// one after another: a jump stopped, by a later click or its limit, ends between them, letting go of any step it
/// cannot stop, an Apple Event in flight.
///
/// A session no terminal window shows, that a multiplexer holds alive, it answers can have a window opened for it
/// instead (`Opening`), in the Ghostty running: the multiplexer's attach command, as Lee sets it, checked fit to type,
/// to be typed into Lee's own shell there. The opening is apart from the jump, so where it opens can be asked of Lee
/// outside the jump's limit, and it never opens a second window for a session it opened one for a moment ago.
public struct Jump: Sendable {
    /// How long a whole jump may take, the wait for a board and for Lee's PATH among it. One takes under a second as
    /// Ghostty answers, a little over to a tab not selected, for its half second's pause, and one Ghostty does not
    /// answer at all, as with the screen locked, is refused at its first question, after 5s. Past this the Mac is too
    /// busy for a jump to land while Lee still wants it (4 November 2026).
    public static let limit = Duration.seconds(15)

    /// Why a jump to a session not on the board, as one finished since a banner told of it, is refused: the CLI's
    /// words for no such session, but for its id, which Lee never sees.
    static let noSuchSession = "There is no such session on the board, in any project."

    /// The app a window is opened in: Ghostty, the one terminal app with a driver.
    static let opensIn = Driver.ghostty

    let reader: ScreenReader
    let tmux: any TmuxProgram
    let drivers: [Driver: any TerminalDriver]
    let workspace: any Workspace
    let clock: any JumpClock
    let commands: AttachCommands
    let openings: RecentOpenings

    init(
        reader: ScreenReader, tmux: any TmuxProgram, drivers: [Driver: any TerminalDriver], workspace: any Workspace,
        clock: any JumpClock, commands: AttachCommands = AttachCommands(), openings: RecentOpenings = RecentOpenings()
    ) {
        self.reader = reader
        self.tmux = tmux
        self.drivers = drivers
        self.workspace = workspace
        self.clock = clock
        self.commands = commands
        self.openings = openings
    }

    /// The jump on this Mac, to the session's window: tmux and zmx found on Lee's PATH and run with his login shell's
    /// environment, as `environment` gives it, SitRep's keeping the shell's once found, asked for once the board is in
    /// hand, within the jump's limit; Ghostty asked by Apple Events. A session no window shows is answered openable,
    /// attached by Lee's commands, unless a window was asked for it a moment ago, among `openings`.
    public static func live(
        to session: String, on board: some JumpBoardSource,
        environment: @escaping @Sendable () async -> [String: String], commands: AttachCommands,
        openings: RecentOpenings
    ) async -> JumpOutcome {
        await run(to: session, on: board, clock: SystemClock()) {
            await live(environment: environment(), commands: commands, openings: openings)
        }
    }

    private static func live(
        environment: [String: String], commands: AttachCommands, openings: RecentOpenings
    ) -> Jump {
        let tmux = TmuxOnPath(environment: environment)
        let workspace = MacWorkspace()
        let clock = SystemClock()
        let ghostty = GhosttyDriver(scripting: GhosttyEvents(), workspace: workspace, clock: clock)

        return Jump(
            reader: ScreenReader(tmux: tmux, zmx: ZmxOnPath(environment: environment)), tmux: tmux, drivers: [.ghostty: ghostty],
            workspace: workspace, clock: clock, commands: commands, openings: openings
        )
    }

    /// Jumps to the session's window, on the board once there is one, within `limit`: stopped, as its task is
    /// cancelled; refused in plain words where no board came in time; unanswered at the limit.
    public func run(to session: String, on board: some JumpBoardSource) async -> JumpOutcome {
        await Self.run(to: session, on: board, clock: clock) { self }
    }

    /// The board read, then the jump `made` gives made and run: each step within `limit`, and stopped with the task,
    /// so a wait for the board or for what the jump is made with ends as a later click comes.
    static func run(
        to session: String, on board: some JumpBoardSource, clock: any JumpClock,
        made: @escaping @Sendable () async -> Jump
    ) async -> JumpOutcome {
        let isBoardRead = OSAllocatedUnfairLock(initialState: false)
        let answered = await answer(within: limit, on: clock) { () async -> JumpOutcome in
            switch await board.current() {
            case let .unread(why):
                return .answered(.refused(why))
            case let .board(read):
                isBoardRead.withLock { $0 = true }
                return await made().jump(to: session, on: read)
            }
        }

        if let answered {
            return answered
        }
        if Task.isCancelled {
            return .answered(.stopped)
        }
        return .answered(isBoardRead.withLock { $0 } ? .unanswered : .refused(await board.missing()))
    }

    /// The jump to the session's windows on the board, a refusal naming it as the board does; where none shows, the
    /// window to open for it, or, where one was asked for it a moment ago, that it is opening.
    private func jump(to session: String, on board: Board) async -> JumpOutcome {
        guard let name = board.name(of: session) else {
            return .answered(.refused(Self.noSuchSession))
        }

        do {
            let jumped = try await jump(to: board.jumpWindows(of: session))

            guard case let .openable(command) = jumped, let driver = drivers[Self.opensIn] else {
                return .answered(jumped.answer(named: name))
            }
            guard !openings.isOpening(session) else {
                return .answered(.opening)
            }

            return .openable(Opening(
                session: session, name: name, command: command, driver: driver, app: Self.opensIn.name,
                workspace: workspace, clock: clock, openings: openings
            ))
        } catch {
            return .answered(.stopped)
        }
    }

    /// Brings the first of the windows a jump can reach to the front, or, where none shows, says what would open a
    /// window attached to one. Which app is in front is read beside the screen, and settled before any select or
    /// focus, so it is never an app brought forward by the jump itself. Where what was asked gave no answer, nothing is
    /// openable.
    func jump(to windows: [Board.Window.Where]) async throws -> Jumped {
        try Task.checkCancellation()

        async let before = workspace.frontmost()
        let screen = await reader.read(windows)
        let front = await before

        try Task.checkCancellation()

        return switch screen.reach(of: windows) {
        case let .onScreen(places):
            try await bringFirst(places, front: front)
        case .offScreen:
            try await openable(screen.attachables(windows))
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
                selects[wanted] = selected
            }

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

    /// The command that would open a window attached to the first of the windows held whose session is still there,
    /// checked: the command and its values fit to type, then Ghostty running. Not on screen where no window is held,
    /// or each one's session has gone; refused, in plain words, otherwise.
    private func openable(_ held: [Attachable]) async throws -> Jumped {
        guard let driver = drivers[Self.opensIn] else {
            return .offScreen
        }

        for each in held {
            guard let multiplexer = reader.multiplexers.first(where: { $0.kind == each.kind }) else {
                continue
            }

            do {
                let command = try await commands.command(for: each.kind).line(attaching: each.where, in: multiplexer)

                try Task.checkCancellation()
                return await driver.canOpen() ? .openable(command: command) : .notRunning(Self.opensIn.name)
            } catch let stopped as CancellationError {
                throw stopped
            } catch is SessionGone {
                continue
            } catch {
                return .unattachable(String(describing: error))
            }
        }

        return .offScreen
    }

    private func bringWhole(_ app: RunningApp?) async -> Bool {
        guard let app else {
            return false
        }

        return await workspace.bringForward(app, on: clock)
    }

    /// Makes the select: the tmux window current in the tmux session, by their ids, within tmux's time limit.
    private func select(_ wanted: Select) async -> Selected {
        guard let ran = try? await tmux.run(
            on: wanted.socket, ["select-window", "-t", "\(wanted.session):\(wanted.window)"]
        ) else {
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

/// What a jump came to: the window brought forward; the command that would open a window attached to it, where none
/// showed it; no terminal window showing the session, nor any tmux could make show it, nor any multiplexer holding it
/// to attach to; its attach command not made, in plain words; the app windows open in not running, by its name; none
/// found, as what was asked gave no answer; devices showing it, in the apps named, where no window answered; tmux not
/// selecting the pane's window, in its words, or giving no answer; or its app unable to be asked.
enum Jumped: Equatable {
    case focused
    case openable(command: String)
    case offScreen
    case unattachable(String)
    case notRunning(String)
    case unknown([Unanswered])
    case unanswered(devices: [String], apps: [String])
    case unselected(said: String?)
    case failed(String)

    /// Why no place brought the window forward: what stopped the first, the one most wanted; where its window did not
    /// answer, every place whose window did not.
    init(_ missed: [Missed]) {
        switch missed.first {
        case let .failed(words)?:
            self = .failed(words)
        case let .unselected(said)?:
            self = .unselected(said: said)
        case .unanswered?:
            let unanswered = missed.compactMap { each in
                if case let .unanswered(place) = each { place } else { nil }
            }
            var named: Set<String> = []

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
        case .openable:
            .openable
        case .offScreen:
            .refused("\(name) is not on screen: no terminal window on this Mac shows it.")
        case let .unattachable(why):
            .unopened("\(name) is not on screen, and SitRep cannot open a window for it: \(why)")
        case let .notRunning(app):
            .unopened("\(name) is not on screen, and SitRep can open a window for it only in a \(app) already running.")
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
