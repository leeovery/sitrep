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
/// Which way a click goes is read at the click by the read of here (`HereReader`), not by the jump's own reading: a
/// session here is jumped to; one not here, held or away, it carries on instead: a Claude of it suspended where a
/// terminal here shows it is Lee's to bring back, the jump taking him there; otherwise a window is opened for it
/// (`Opening`), in the terminal Lee chose, typing his resume command, its placeholders filled from the window the
/// session is carried on from, checked fit to type. The opening is apart from the jump, and never opens a second window
/// for a session it opened one for a moment ago.
public struct Jump: Sendable {
    /// How long a whole jump may take, the wait for a board and for Lee's PATH among it. One takes under a second as
    /// Ghostty answers, a little over to a tab not selected, for its half second's pause, and one Ghostty does not
    /// answer at all, as with the screen locked, is refused at its first question, after 5s. Past this the Mac is too
    /// busy for a jump to land while Lee still wants it (4 November 2026).
    public static let limit = Duration.seconds(15)

    /// Why a jump to a session not on the board, as one finished since a banner told of it, is refused: the CLI's
    /// words for no such session, but for its id, which Lee never sees.
    static let noSuchSession = "There is no such session on the board, in any project."

    let reader: ScreenReader
    /// Whether the session is here, read from the jump's own table and tmux.
    let here: HereReader
    let tmux: any TmuxProgram
    let drivers: [Driver: any TerminalDriver]
    let workspace: any Workspace
    let clock: any JumpClock
    let opening: OpenSettings
    let openings: RecentOpenings

    init(
        reader: ScreenReader, tmux: any TmuxProgram, drivers: [Driver: any TerminalDriver], workspace: any Workspace,
        clock: any JumpClock, opening: OpenSettings = OpenSettings(), openings: RecentOpenings = RecentOpenings()
    ) {
        self.reader = reader
        here = HereReader(multiplexers: reader.multiplexers, table: reader.table)
        self.tmux = tmux
        self.drivers = drivers
        self.workspace = workspace
        self.clock = clock
        self.opening = opening
        self.openings = openings
    }

    /// The jump on this Mac, to the session's window: tmux found on Lee's PATH as `path` gives it, SitRep's keeping the
    /// login shell's once found, asked for once the board is in hand, within the jump's limit; Ghostty asked by Apple
    /// Events. A session no terminal here shows is carried on, as `opening` says, unless a window was asked for it a
    /// moment ago, among `openings`.
    public static func live(
        to session: String, on board: some JumpBoardSource, path: @escaping @Sendable () async -> String,
        opening: OpenSettings, openings: RecentOpenings
    ) async -> JumpOutcome {
        await run(to: session, on: board, clock: SystemClock()) {
            await live(path: path(), opening: opening, openings: openings)
        }
    }

    private static func live(path: String, opening: OpenSettings, openings: RecentOpenings) -> Jump {
        let tmux = TmuxOnPath(path: path)
        let workspace = MacWorkspace()
        let clock = SystemClock()
        let ghostty = GhosttyDriver(scripting: GhosttyEvents(), workspace: workspace, clock: clock)

        return Jump(
            reader: ScreenReader(tmux: tmux), tmux: tmux, drivers: [.ghostty: ghostty], workspace: workspace,
            clock: clock, opening: opening, openings: openings
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
                return await made().click(session, on: read)
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

    /// A click on a session on the board, a refusal naming it as the board does.
    private func click(_ session: String, on board: Board) async -> JumpOutcome {
        guard let name = board.name(of: session) else {
            return .answered(.refused(Self.noSuchSession))
        }

        return await click(
            session, named: name, at: board.jumpWindows(of: session), from: board.resumeWindow(of: session),
            isHeld: board.isHeld(session)
        )
    }

    /// A click on a session: the jump to its windows, where it is here; else carried on from the window given, held or
    /// away; refused as not on screen where there is none to carry it on from, and in the jump's words where whether it
    /// is here is unknown.
    func click(
        _ session: String, named name: String, at windows: [Board.Window.Where], from window: Board.LastWindow?,
        isHeld: Bool
    ) async -> JumpOutcome {
        await stoppable {
            if let here = try await jumpIfHere(session, at: windows) {
                return .answered(here.answer(named: name))
            }
            guard let window else {
                return .answered(Jumped.offScreen.answer(named: name))
            }

            return try await carryOn(session, named: name, from: window, isHeld: isHeld)
        }
    }

    /// The jump to the session's windows where it is here, read afresh, which forgets any window opened for it; where
    /// whether it is here is unknown, which is never taken for not here, that unknown. Nil where it is not here. Here
    /// decides, so a session here the jump's own reading finds on no screen, as one in a terminal app whose
    /// `$TERM_PROGRAM` names none, is refused in the jump's words, never carried on.
    private func jumpIfHere(_ session: String, at windows: [Board.Window.Where]) async throws -> Jumped? {
        let read = await here.read(windows)

        try Task.checkCancellation()

        switch read {
        case .notHere:
            return nil
        case let .unknown(unanswered):
            return .unknown(unanswered)
        case .here:
            openings.shown(session)
            return try await jump(to: windows)
        }
    }

    /// A session no terminal on this Mac shows carried on from the window given, read now. First its Claude on the
    /// window's device, by the process table, as a heartbeat gone stale says only that its beat stopped, which a plugin
    /// no longer loading, or its process suspended, does too: one suspended where a terminal here shows it, Lee's own
    /// Ctrl-Z, is his to bring back, so the click takes him to it, starting nothing (`suspended`); the table giving no
    /// answer refuses. Otherwise the resume command; the default refused while the session's Claude may still be alive:
    /// a window holds it, or a Claude is suspended on its device, whoever was seen there after, or runs there, unless a
    /// later conversation was. A stopped Claude is never resumed beside, as a later conversation started in the shell
    /// it was suspended in leaves it there.
    private func carryOn(
        _ session: String, named name: String, from window: Board.LastWindow, isHeld: Bool
    ) async throws -> JumpOutcome {
        let there = claude(on: window.where?.device)

        switch there {
        case .unknown:
            return .answered(.unopened(
                "Could not tell whether \(name)'s Claude is still running: the process table gave no answer."
            ))
        case .stopped:
            if let shown = try await suspended(named: name, at: window.where) {
                return shown
            }
        case .running, .none:
            break
        }

        let isOnItsDevice = there == .stopped || (there != .none && window.ownsDevice != false)
        let tty = there != .none && window.ownsDevice == true ? window.where?.device : nil
        let alive: Alive? = isOnItsDevice ? .seen : isHeld ? .held : nil

        return try await resume(
            session, named: name, from: ResumeFacts(window: window, tty: tty, isHeld: isHeld), alive: alive,
            wasHeld: isHeld
        )
    }

    /// A Claude Code process on the device given, by the process table: one stopped, as Ctrl-Z leaves it, before one
    /// running; none, there or with no device to look on; unknown, the table giving no answer.
    private func claude(on device: String?) -> ClaudeThere {
        guard let device else {
            return .none
        }
        guard let processes = reader.table.read(arguments: { _ in false }) else {
            return .unknown
        }

        let there = processes.all.values.filter { $0.device == device && $0.isClaudeCode }

        return there.contains(where: \.isStopped) ? .stopped : there.isEmpty ? .none : .running
    }

    /// Takes Lee to the window a Claude of the session is suspended in, where its window is here, by the read of here,
    /// never the jump's `$TERM_PROGRAM`, which ssh carries from another Mac: SitRep starts nothing, nor types `fg`, as
    /// Lee may be busy in that shell, and says why. Nil where it is not here, so the session is carried on as any
    /// other; refused where whether it is here is unknown, in a jump's words, and where its window does not come
    /// forward, the jump finding it on no screen among them.
    private func suspended(named name: String, at where: Board.Window.Where?) async throws -> JumpOutcome? {
        guard let `where` else {
            return nil
        }

        switch await here.read([`where`]) {
        case .notHere:
            return nil
        case let .unknown(unanswered):
            return .answered(Jumped.unknown(unanswered).answer(named: name))
        case .here:
            break
        }

        switch try await jump(to: [`where`]) {
        case .focused:
            return .answered(.jumpedSaying("\(name) is suspended in this window: type fg to bring it back."))
        case let .unknown(unanswered):
            return .answered(Jumped.unknown(unanswered).answer(named: name))
        case .offScreen, .unanswered, .unselected, .failed:
            return .answered(.refused(
                "\(name) is suspended in its window, which SitRep could not bring forward: type fg there to bring it back."
            ))
        }
    }

    /// A jump stopped, as its task is cancelled, answers so.
    private func stoppable(_ jump: () async throws -> JumpOutcome) async -> JumpOutcome {
        do {
            return try await jump()
        } catch {
            return .answered(.stopped)
        }
    }

    /// The window to open for the session, typing the resume command filled with the facts given: none where one was
    /// asked for it a moment ago, which is opening; none where the command is the default and the session's Claude may
    /// still be alive, which the default would resume beside; and none where the line is not fit to type, refused in
    /// plain words. A command Lee wrote always runs: what it does is his.
    private func resume(
        _ session: String, named name: String, from facts: ResumeFacts, alive: Alive?, wasHeld: Bool
    ) async throws -> JumpOutcome {
        guard !openings.isOpening(session) else {
            return .answered(.opening)
        }
        guard let driver = drivers[opening.terminal] else {
            return .answered(Jumped.offScreen.answer(named: name))
        }

        let command = ResumeCommand(opening.resumeCommand)

        if let alive, command.isDefault {
            return .answered(.unopened(alive.refusal(named: name)))
        }

        do {
            let line = try await command.line(from: facts, named: name)

            try Task.checkCancellation()
            return .openable(Opening(
                session: session, name: name, line: line, terminal: opening.terminal, wasHeld: wasHeld, driver: driver,
                workspace: workspace, clock: clock, openings: openings
            ))
        } catch {
            try Task.checkCancellation()
            return .answered(.unopened(String(describing: error)))
        }
    }

    /// Brings the first of the live windows a jump can reach to the front. Which app is in front is read beside the
    /// screen, and settled before any select or focus, so it is never an app brought forward by the jump itself. Where
    /// what was asked gave no answer, none is found.
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

/// Why the default resume command would resume beside the session's Claude: a Claude seen on its device; or none seen
/// there, but a window still holding it, as one whose tab was closed holds it until its heartbeat goes stale.
enum Alive: Equatable {
    case seen, held

    /// Why the default refuses, in plain words, for the session named.
    func refusal(named name: String) -> String {
        switch self {
        case .seen:
            "\(name)'s Claude is still running where this Mac doesn't show it: set a resume command that can reach it, "
                + "in Settings."
        case .held:
            "\(name)'s window has just stopped answering: try again in a moment."
        }
    }
}

/// What runs on the device a session's Claude ran on: a Claude Code process stopped there, one running, none; or
/// unknown, the table giving no answer.
enum ClaudeThere: Equatable {
    case stopped, running, none, unknown
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
        case .offScreen:
            .refused("\(name) is not on screen: no terminal window on this Mac shows it.")
        case let .unknown(unanswered):
            .refused("Could not tell whether \(name) is on screen: \(Self.whyUnknown(unanswered)).")
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

    /// Why a jump could not tell, in words: what gave no answer, then, after a comma, what tmux said instead.
    private static func whyUnknown(_ unanswered: [Unanswered]) -> String {
        let silent = unanswered.compactMap(\.silent)
        let said = unanswered.compactMap(\.said)

        return [silent.isEmpty ? nil : "\(inWords(silent)) gave no answer", said.isEmpty ? nil : inWords(said)]
            .compactMap(\.self).joined(separator: ", and ")
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
    /// What gave no answer, as a refusal names it; none for tmux's error.
    var silent: String? {
        switch self {
        case .tmux: "tmux"
        case .processes: "the process table"
        case .tmuxSaid: nil
        }
    }

    /// tmux's error, as a refusal gives it, in its words.
    var said: String? {
        guard case let .tmuxSaid(said) = self else {
            return nil
        }

        return said.isEmpty ? "tmux failed without saying why" : "tmux said \"\(said)\""
    }
}

/// Things in words, as core's `inWords` puts them: `a`, `a and b`, `a, b and c`.
func inWords(_ things: [String], _ conjunction: String = "and") -> String {
    guard let last = things.last, things.count > 1 else {
        return things.joined()
    }

    return "\(things.dropLast().joined(separator: ", ")) \(conjunction) \(last)"
}
