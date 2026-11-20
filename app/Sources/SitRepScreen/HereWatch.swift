import SitRepCore

/// The continuous read of here (DESIGN, stage 8, "How it is read"), for the rows and for `here.json`: every held
/// session on the watch's last board read at each line and every `every` between them, one read at a time, off the main
/// thread. It keeps who was last seen viewing each held session, and each multiplexer tty (`Sightings`); the sessions
/// whose viewers hold no `mac` are the not here the rows draw dimmed, and each settling is told, for `HereFile`. A
/// session read as unknown keeps the viewers it last read, and one never read has none, so it is here; one no window
/// holds any more keeps none, so a look never outlives its session's hold. A read whose table gave no answer keeps the
/// ttys too. A session read as here forgets the window opened for it (`RecentOpenings.shown`).
@MainActor
public final class HereWatch {
    /// How often it reads between the watch's lines. A read of 46 sessions, 33 of them in zmx, over 1,336 processes
    /// took 23ms in a release build on Lee's Mac, which runs no tmux, the table's own look 5ms of it (13 November
    /// 2026): so a row's look lags the screen by 3 seconds at most, at under 1% of a core.
    public static let every = Duration.seconds(3)

    /// A read of who views each session, by the windows a jump tries for it, and each multiplexer tty.
    public typealias Read = @Sendable ([String: [Board.Window.Where]]) async -> HereRead

    private let read: Read
    private let openings: RecentOpenings
    private let clock: any JumpClock
    private var board: Board?
    /// The read under way, until its answer is taken: internal only for the tests, which wait on it.
    private(set) var reading: Task<Void, Never>?
    /// A line came while a read was under way, so another follows it, of the board as it then is.
    private var isAskedAgain = false
    private var ticking: Task<Void, Never>?

    /// Who was last seen viewing each held session, and each multiplexer tty.
    public private(set) var sightings = Sightings()
    /// Each change of `notHere`.
    public var changed: (Set<String>) -> Void = { _ in }
    /// Each settling of `sightings`, changed or not, after `changed` where `notHere` changed: at each line, which may
    /// drop sessions with no read, and at each read taken.
    public var settled: (Sightings) -> Void = { _ in }

    public init(openings: RecentOpenings, clock: any JumpClock = SystemClock(), read: @escaping Read) {
        self.openings = openings
        self.clock = clock
        self.read = read
    }

    /// The sessions a window holds that were last read as not on this Mac's screen.
    public var notHere: Set<String> {
        sightings.notHere
    }

    /// The read on this Mac: tmux found on Lee's PATH as `path` gives it, at each read, as a jump finds it.
    public static func live(path: @escaping @Sendable () async -> String, openings: RecentOpenings) -> HereWatch {
        HereWatch(openings: openings) { sessions in
            await HereReader(tmux: TmuxOnPath(path: path())).read(sessions)
        }
    }

    /// Each board the watch prints: a session no window holds now drops its viewers at once, and the held ones are
    /// read, now or as the read under way ends. The first starts the reads between lines.
    public func heard(_ board: Board) {
        self.board = board
        keep(Sightings(sessions: sightings.sessions.filter { board.isHeld($0.key) }, ttys: sightings.ttys))
        if reading == nil {
            readNow()
        } else {
            isAskedAgain = true
        }
        if ticking == nil {
            ticking = Task { [weak self, clock] in
                while (try? await clock.sleep(for: Self.every)) != nil {
                    guard let self else {
                        return
                    }

                    tick()
                }
            }
        }
    }

    /// Stops reading.
    public func stop() {
        ticking?.cancel()
        reading?.cancel()
        ticking = nil
        reading = nil
    }

    /// Between lines, a read, unless one is under way.
    private func tick() {
        if reading == nil {
            readNow()
        }
    }

    private func readNow() {
        guard let board else {
            return
        }

        let held = Set(board.windows.map(\.session))

        guard !held.isEmpty else {
            return
        }

        let sessions = Dictionary(uniqueKeysWithValues: held.map { ($0, board.jumpWindows(of: $0)) })

        reading = Task { [self, read] in
            let answer = await read(sessions)

            guard !Task.isCancelled else {
                return
            }

            take(answer)
            reading = nil
            if isAskedAgain {
                isAskedAgain = false
                readNow()
            }
        }
    }

    /// A read's sessions as they read, of those a window still holds: their viewers seen; unknown, as last read. Its
    /// ttys, unless its table gave no answer.
    private func take(_ read: HereRead) {
        let held = board.map { Set($0.windows.map(\.session)) } ?? []
        var sessions = sightings.sessions

        read.sessions.filter { $0.value.here == .here }.keys.forEach(openings.shown)
        for case let (session, .seen(viewers)) in read.sessions {
            sessions[session] = viewers
        }
        keep(Sightings(sessions: sessions.filter { held.contains($0.key) }, ttys: read.ttys ?? sightings.ttys))
    }

    private func keep(_ sightings: Sightings) {
        let wasNotHere = notHere

        self.sightings = sightings
        if notHere != wasNotHere {
            changed(notHere)
        }
        settled(sightings)
    }
}
