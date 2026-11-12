import Foundation
import os
import SitRepCore

/// What a jump came to: an answer; or a window to open for a session no window shows, which the one who asked opens
/// next, apart from the jump.
public enum JumpOutcome: Sendable {
    case answered(JumpAnswer)
    case openable(Opening)
}

/// How SitRep opens a window for a session no window shows, as Lee sets it in Settings: the terminal it opens in, by
/// its driver; the open command; and the resume command, for an away session nothing is left of; each empty until he
/// gives one.
public struct OpenSettings: Sendable, Equatable {
    public var terminal: Driver
    public var command: String
    public var resumeCommand: String

    public init(terminal: Driver = .ghostty, command: String = "", resumeCommand: String = "") {
        self.terminal = terminal
        self.command = command
        self.resumeCommand = resumeCommand
    }
}

/// A window to open for a session no window shows, as a jump found it: the line to type, the open command or the resume
/// command filled and fit to type, and the terminal it opens in. It opens apart from the jump, under a limit of its own, on the Space
/// showing, only into a terminal already running; and it is remembered as it begins (`RecentOpenings`), so a click on
/// its session meanwhile opens no second.
public struct Opening: Sendable {
    /// How long an opening may take: its two events, 5 seconds each at most, the focus's, and the second's watch of the
    /// front.
    public static let limit = Duration.seconds(20)

    let session: String
    /// The session's name, as a refusal names it.
    let name: String
    let line: String
    let terminal: Driver
    /// What the line is, which says how long the opening is remembered.
    let kind: RecentOpenings.Kind
    let driver: any TerminalDriver
    let workspace: any Workspace
    let clock: any JumpClock
    let openings: RecentOpenings

    /// Opens the window, once its terminal is known to be running, within `limit`: opened; refused in plain words;
    /// stopped, as its task is cancelled; or given up at the limit, where, once the window was asked for, one may yet
    /// come. The opening is remembered as it begins and again as the window is asked for, and forgotten only where it
    /// failed before then, so a window asked for is never opened twice.
    public func open() async -> JumpAnswer {
        guard await driver.canOpen() else {
            return .unopened(notRunning)
        }
        guard !Task.isCancelled else {
            return .stopped
        }

        let asked = Remembered(session, as: kind, among: openings)

        if let answered = await answer(within: Self.limit, on: clock, { await opened(asked) }) {
            return answered
        }

        let gaveUp = "SitRep gave up waiting for \(terminal.name) to open a window for \(name) after "
            + "\(Self.limit.components.seconds) seconds"

        return Task.isCancelled ? .stopped : .unopened(asked.isAsked ? gaveUp + "; one may still appear." : gaveUp + ".")
    }

    /// The app in front read as the opening begins, as a jump reads it, so the one it keeps the front from is never
    /// one the opening brought forward; then the window asked for. Where it failed before then, the opening is
    /// forgotten.
    private func opened(_ asked: Remembered) async -> JumpAnswer {
        let front = await workspace.frontmost()

        do {
            guard try await driver.openWindow(running: line, front: front, sending: asked.ask) else {
                asked.forgetUnasked()
                return .unopened(notRunning)
            }

            return .opened
        } catch {
            asked.forgetUnasked()
            return error is CancellationError ? .stopped : .unopened(String(describing: error))
        }
    }

    private var notRunning: String {
        "SitRep opens a window only in a \(terminal.name) already running. Open \(terminal.name), then click \(name) "
            + "again."
    }
}

/// An opening, remembered among the openings as it begins, and again as its window is asked for, the event asking for
/// it about to go, so a slow first event costs none of the time it is remembered. Forgotten only where its window was
/// never asked for, and never in place of a later opening of its session.
private final class Remembered: Sendable {
    private let session: String
    private let kind: RecentOpenings.Kind
    private let openings: RecentOpenings
    private let state: OSAllocatedUnfairLock<(remembered: ContinuousClock.Instant, isAsked: Bool)>

    init(_ session: String, as kind: RecentOpenings.Kind, among openings: RecentOpenings) {
        self.session = session
        self.kind = kind
        self.openings = openings
        state = OSAllocatedUnfairLock(initialState: (openings.remember(session, as: kind), false))
    }

    var isAsked: Bool { state.withLock(\.isAsked) }

    @Sendable func ask() {
        let remembered = openings.remember(session, as: kind)

        state.withLock { $0 = (remembered, true) }
    }

    func forgetUnasked() {
        let (remembered, isAsked) = state.withLock { $0 }

        if !isAsked {
            openings.forget(session, remembered: remembered)
        }
    }
}

/// The sessions a window was asked for a moment ago, opened or not yet, so a click on one again before its window shows
/// it, or its Claude is back on the board, opens no second.
public final class RecentOpenings: Sendable {
    /// What an opening's window runs, which says how long it is remembered.
    public enum Kind: Sendable {
        /// The open command: the window's shell takes 0.5 to 2 seconds to start and run it, and then the session's
        /// client is on screen, which makes the next click a jump. Remembered 10 seconds.
        case attach
        /// The resume command: its Claude reaches the board only once the command has made its terminal session,
        /// Claude has started, the plugin loaded and taken the session up and beaten, and the watch printed, which can
        /// run past those seconds. Remembered until the board shows a window holding the session (`heard`), 2 minutes
        /// at most.
        case resume

        /// How long an opening of it is remembered at most.
        public var lasts: Duration {
            switch self {
            case .attach: .seconds(10)
            case .resume: .seconds(120)
            }
        }
    }

    private struct Asked: Sendable {
        let at: ContinuousClock.Instant
        let kind: Kind
    }

    private let now: @Sendable () -> ContinuousClock.Instant
    private let opened = OSAllocatedUnfairLock(initialState: [String: Asked]())

    /// `now` tells the time: the tests' own, in place of the real one.
    public init(now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }) {
        self.now = now
    }

    /// Remembers an opening of the kind for the session as of now, which it gives, to forget it by.
    @discardableResult
    func remember(_ session: String, as kind: Kind = .attach) -> ContinuousClock.Instant {
        let now = now()

        opened.withLock { $0[session] = Asked(at: now, kind: kind) }
        return now
    }

    /// Forgets the session's opening remembered at the instant given; none remembered since.
    func forget(_ session: String, remembered: ContinuousClock.Instant) {
        opened.withLock { opened in
            if opened[session]?.at == remembered {
                opened[session] = nil
            }
        }
    }

    /// Forgets the resume of each session a window holds on the board, its Claude back: a click on it is a jump now,
    /// and one once it is away again carries it on afresh.
    public func heard(_ board: Board) {
        let held = Set(board.windows.map(\.session))

        opened.withLock { opened in
            opened = opened.filter { $0.value.kind != .resume || !held.contains($0.key) }
        }
    }

    /// Whether a window was asked for the session within its kind's `lasts`; those asked for longer ago forgotten.
    func isOpening(_ session: String) -> Bool {
        let now = now()

        return opened.withLock { opened in
            opened = opened.filter { now - $0.value.at < $0.value.kind.lasts }
            return opened[session] != nil
        }
    }
}
