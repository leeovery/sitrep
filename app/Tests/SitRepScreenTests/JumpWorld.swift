import Darwin
import Foundation
import SitRepCore
@testable import SitRepScreen

/// The session a refusal names.
let named = "Dashboard redesign"

/// The device of the Ghostty window showing Claude's tmux window, and of Lee's phone.
let window = "/dev/ttys000"
let phone = "/dev/ttys067"

/// Claude's tmux window, another of its tmux session, and one of another session.
let claudes = "@45"
let beside = "@46"
let kit = "@52"

/// Ghostty's terminals: one in the window Claude runs in outside tmux, one in the window showing its tmux window, and
/// another.
let kitTerminal = FakeTerminal(id: "KIT-TERMINAL", device: "/dev/ttys041")
let switchboardTerminal = FakeTerminal(id: "SWITCHBOARD-TERMINAL", device: window)
let terminals = ownWindows(kitTerminal, switchboardTerminal, FakeTerminal(id: "HOME-TERMINAL", device: "/dev/ttys090"))

/// Terminal's bundle, as its clients' ancestry finds it.
let terminalApp = "/System/Applications/Utilities/Terminal.app"

/// The words of a session no terminal shows.
let offScreen = JumpAnswer.refused("\(named) is not on screen: no terminal window on this Mac shows it.")

extension Jump {
    /// The jump to the session on the board, in the words it answers in: `.openable` where a window would be opened.
    func answer(to session: String, on board: some JumpBoardSource) async -> JumpAnswer {
        await run(to: session, on: board).answer
    }
}

extension JumpOutcome {
    /// Its answer: `.openable` for a window to open.
    var answer: JumpAnswer {
        switch self {
        case let .answered(answer): answer
        case .openable: .openable
        }
    }

    var opening: Opening? {
        if case let .openable(opening) = self { opening } else { nil }
    }
}

/// The words of a jump no place answered, naming the devices and apps tried.
func noneAnswered(_ devices: String, _ apps: String = "Ghostty") -> JumpAnswer {
    .refused("\(named) shows on \(devices), but no \(apps) window there answered.")
}

extension Mac {
    /// A tmux client in a Ghostty window on the device, showing the tmux window, attached to the tmux session given,
    /// else the one named for its window.
    mutating func ghosttyClient(_ device: String, showing window: String, in session: String? = nil) -> FakeClient {
        FakeClient(device: device, pid: inGhostty(device), window: window, session: session)
    }

    /// A tmux client in a Terminal window on the device.
    mutating func terminalClient(_ device: String, showing window: String, in session: String? = nil) -> FakeClient {
        FakeClient(device: device, pid: inTerminal(device), window: window, session: session)
    }

    mutating func phoneClient(_ device: String, showing window: String, in session: String? = nil) -> FakeClient {
        FakeClient(device: device, pid: onPhone(device), window: window, session: session)
    }

    mutating func sshClient(_ device: String, showing window: String) -> FakeClient {
        FakeClient(device: device, pid: overSsh(device), window: window)
    }

    /// A control-mode client started from a Ghostty window's shell: tmux gives it no device, and it is on none.
    mutating func controlClient(showing window: String, in session: String? = nil) -> FakeClient {
        FakeClient(device: "", pid: inGhostty("/dev/ttys070", own: ""), window: window, session: session)
    }
}

/// Claude's tmux server: its pane `%148` on Claude's tmux window, in the tmux sessions given, and a pane of another
/// session; its clients as given.
func server(_ clients: [FakeClient], sessions: [String] = ["$45"], select: Ran? = Ran(status: 0, stdout: "", stderr: ""))
    -> FakeTmux
{
    let panes = sessions.flatMap { session in
        [FakePane(pane: "%148", window: claudes, session: session), FakePane(pane: "%149", window: beside, session: session)]
    }

    return FakeTmux([socket: FakeServer(panes: panes + [FakePane(pane: "%54", window: kit, session: "$52")], clients: clients)], select: select)
}

/// Claude's tmux window shown by a Ghostty window, and another tmux window by another Ghostty window.
func shown() -> (FakeTmux, FakeTable) {
    var mac = Mac()
    let clients = [mac.ghosttyClient(kitTerminal.device, showing: kit), mac.ghosttyClient(window, showing: claudes)]

    return (server(clients), FakeTable(mac.tree))
}

/// A jump on a Mac of doubles: tmux, the process table, Ghostty, the apps and the clock, Ghostty telling the apps of
/// what it is told; a window opened as the settings given say, none with no command as by default, and remembered among
/// the openings given.
struct Jumping {
    let tmux: FakeTmux
    let table: FakeTable
    let ghostty: FakeGhostty
    let workspace: FakeWorkspace
    let clock: TestClock
    let opening: OpenSettings
    let openings: RecentOpenings
    private let program: any TmuxProgram

    init(
        _ tmux: FakeTmux = FakeTmux(), _ table: FakeTable = FakeTable(Mac().tree), terminals: [FakeWindow] = terminals,
        running: Bool = true, failing: GhosttyFailure? = nil, windowFailing: GhosttyFailure? = nil,
        windowHeld: Gate? = nil, ghosttyHeld: Gate? = nil,
        workspace: FakeWorkspace = FakeWorkspace(), clock: TestClock = TestClock(), tmuxHeld: Gate? = nil,
        command: String = "", openings: RecentOpenings = RecentOpenings()
    ) {
        self.tmux = tmux
        self.table = table
        self.workspace = workspace
        self.clock = clock
        opening = OpenSettings(command: command)
        self.openings = openings
        ghostty = FakeGhostty(
            terminals, running: running, failing: failing, held: ghosttyHeld, windowFailing: windowFailing,
            windowHeld: windowHeld, onTold: workspace.told
        )
        program = tmuxHeld.map { HeldTmux(tmux, at: $0) } ?? tmux
    }

    var driver: GhosttyDriver {
        GhosttyDriver(scripting: ghostty, workspace: workspace, clock: clock)
    }

    var jump: Jump {
        Jump(
            reader: ScreenReader(tmux: program, table: table), tmux: program, drivers: [.ghostty: driver],
            workspace: workspace, clock: clock, opening: opening, openings: openings
        )
    }

    /// The jump to the windows, in the words it answers in: `.openable` where a window would be opened.
    func run(_ windows: [Where]) async -> JumpAnswer {
        (try? await jump.jump(to: windows))?.answer(named: named) ?? .stopped
    }

    /// The jump to `sr-a`'s windows, as a click makes it: an answer, or the window to open for it.
    func outcome(_ windows: [Where]) async -> JumpOutcome {
        await jump.jump(to: "sr-a", named: named, at: windows)
    }

    /// The jump to `sr-a`'s windows, then the window it finds can be opened opened, as SitRep opens one once the jump
    /// has answered.
    func open(_ windows: [Where]) async -> JumpAnswer {
        switch await outcome(windows) {
        case let .answered(answer): answer
        case let .openable(opening): await opening.open()
        }
    }

    /// The opening of a window for `sr-a` typing the line.
    func opening(_ line: String) -> Opening {
        Opening(
            session: "sr-a", name: named, line: line, terminal: .ghostty, driver: driver, workspace: workspace,
            clock: clock, openings: openings
        )
    }

    /// The selects tmux was asked for, each by the tmux session and window it names.
    var selects: [String] {
        tmux.selects.map { $0.last ?? "" }
    }
}
