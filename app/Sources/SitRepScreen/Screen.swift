import SitRepCore

/// Reads where windows show: a window in a multiplexer shows in every terminal window of this Mac holding a client of
/// its session (for tmux, on the tmux window holding its pane, or which a select could make show it), each seated by
/// one step (`Processes.seat`); one outside any, in its own, when its terminal app is known. One is made for each read,
/// as its tmux is found once, on Lee's PATH as it stands (`TmuxOnPath`).
public struct ScreenReader: Sendable {
    let multiplexers: [any Multiplexer]
    let table: any ProcessTable

    /// Every multiplexer a window may run in, tmux first, beside the process table.
    public init(tmux: any TmuxProgram, table: any ProcessTable = KernelProcesses()) {
        self.init(multiplexers: [TmuxAdapter(tmux), ZmxAdapter()], table: table)
    }

    init(multiplexers: [any Multiplexer], table: any ProcessTable) {
        self.multiplexers = multiplexers
        self.table = table
    }

    /// The screen for the windows, read once however many sessions they hold, so each tmux socket is asked once and
    /// the table read once: each multiplexer read for the windows in it, and the table beside, where any runs in one,
    /// with the command lines the multiplexers tell their clients by. Nothing that fails here fails the read: what
    /// gives no answer shows nothing, and is named.
    public func read(_ windows: [Board.Window.Where]) async -> Screen {
        let isMultiplexed = windows.contains { each in multiplexers.contains { $0.isIn(each) } }
        async let processes = isMultiplexed
            ? table.read { process in multiplexers.contains { $0.tellsBy(process) } }
            : nil
        let readings = await withTaskGroup(of: (Int, any Reading).self) { group in
            for (order, multiplexer) in multiplexers.enumerated() {
                group.addTask { (order, await multiplexer.read(windows.filter(multiplexer.isIn))) }
            }

            return await group.reduce(into: []) { $0.append($1) }.sorted { $0.0 < $1.0 }.map(\.1)
        }

        return await Screen(readings: readings, processes: processes)
    }
}

/// What tells where windows show: what each multiplexer read, and the process table, nil where it gave no answer or
/// none was needed.
public struct Screen: Sendable {
    let readings: [any Reading]
    let processes: Processes?

    /// Where any of the windows can be brought forward, each device once, the first window's first; an app with no
    /// driver and no device once.
    public func places(showing windows: [Board.Window.Where]) -> [Place] {
        var seen: Set<PlaceKey> = []

        return windows.flatMap(places(of:)).filter { seen.insert(PlaceKey($0)).inserted }
    }

    /// Whether a jump can reach the windows: the places it can bring them forward at; none, nothing showing them; or
    /// none found, as what was asked of them gave no answer, which is never taken for none.
    public func reach(of windows: [Board.Window.Where]) -> Reach {
        let places = places(showing: windows)

        guard places.isEmpty else {
            return .onScreen(places)
        }

        let unanswered = unanswered(for: windows)

        return unanswered.isEmpty ? .offScreen : .unknown(unanswered)
    }

    /// What gave no answer of the windows: what a multiplexer they run in asked, as tmux for a socket one runs under;
    /// and the table, where their clients are told only by it. A window in no multiplexer asks neither.
    public func unanswered(for windows: [Board.Window.Where]) -> [Unanswered] {
        let asked = windows.flatMap { each in readings.flatMap { $0.unanswered(each) } }
        let isTableUnanswered = processes == nil
            && windows.contains { each in readings.contains { $0.needsProcesses(each) } }
        var seen: Set<Unanswered> = []

        return (asked + (isTableUnanswered ? [.processes] : [])).filter { seen.insert($0).inserted }
    }

    /// Where one window can be brought forward: in a multiplexer, the places the innermost it runs in finds for its
    /// clients; outside any, its own device, in the app its `$TERM_PROGRAM` names.
    private func places(of where: Board.Window.Where) -> [Place] {
        guard readings.contains(where: { $0.isIn(`where`) }) else {
            return TerminalApp(program: `where`.terminal)
                .flatMap { $0.reaches(`where`.tty) ? [Place(app: $0, device: `where`.tty)] : nil } ?? []
        }

        return innermost(of: `where`).flatMap { $0.places(`where`, processes ?? Processes([:])) }
    }

    /// The readings of the multiplexer a window is innermost in: of those it runs in, the one whose own pty is its
    /// device; where none says so, each that cannot tell. A multiplexer run inside another passes its variables on
    /// (tmux started in zmx keeps `$ZMX_SESSION`, zmx started in tmux `$TMUX`), so the outer one's would name a
    /// session the window is not on.
    private func innermost(of where: Board.Window.Where) -> [any Reading] {
        let inIt = readings.filter { $0.isIn(`where`) }

        guard inIt.count > 1 else {
            return inIt
        }

        let onIts = inIt.filter { $0.isOnItsPty(`where`) == true }

        return onIts.isEmpty ? inIt.filter { $0.isOnItsPty(`where`) == nil } : onIts
    }
}

/// Whether a jump can reach windows.
public enum Reach: Sendable, Equatable {
    case onScreen([Place])
    case offScreen
    case unknown([Unanswered])

    /// The terminal app showing them, the first place a jump would bring forward: in a multiplexer the app its client
    /// descends from, which `$TERM_PROGRAM`, `tmux` in tmux, cannot tell. None where they are not on screen.
    public var app: TerminalApp? {
        guard case let .onScreen(places) = self else {
            return nil
        }

        return places.first?.app
    }
}

/// What tells places apart: the device, else, for an app with no driver, the app.
private enum PlaceKey: Hashable {
    case device(String)
    case app(TerminalApp)

    init(_ place: Place) {
        self = place.device.map(PlaceKey.device) ?? .app(place.app)
    }
}
