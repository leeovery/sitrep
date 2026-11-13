import Foundation
import os
import SitRepCore

/// What a jump came to: an answer; or a window to open for a session no terminal on this Mac shows, which the one who
/// asked opens next, apart from the jump.
public enum JumpOutcome: Sendable {
    case answered(JumpAnswer)
    case openable(Opening)
}

/// How SitRep opens a window for a session no terminal on this Mac shows, as Lee sets it in Settings: the terminal it
/// opens in, by its driver; and the resume command, the default until he gives another.
public struct OpenSettings: Sendable, Equatable {
    /// The resume command Settings starts with: Claude Code resuming the conversation in the folder it ran in.
    public static let defaultResumeCommand = "cd {dir} && claude --resume {claude}"

    public var terminal: Driver
    public var resumeCommand: String

    public init(terminal: Driver = .ghostty, resumeCommand: String = defaultResumeCommand) {
        self.terminal = terminal
        self.resumeCommand = resumeCommand
    }
}

/// A window to open for a session no terminal on this Mac shows, as a jump found it: the line to type, the resume
/// command filled and fit to type, and the terminal it opens in. It opens apart from the jump, under a limit of its
/// own, on the Space showing, only into a terminal already running; and it is remembered as it begins
/// (`RecentOpenings`), so a click on its session meanwhile opens no second.
public struct Opening: Sendable {
    /// How long an opening may take: its two events, 5 seconds each at most, the focus's, and the second's watch of the
    /// front.
    public static let limit = Duration.seconds(20)

    let session: String
    /// The session's name, as a refusal names it.
    let name: String
    let line: String
    let terminal: Driver
    /// Whether a live window held the session at the click, so the board holding it tells nothing of the opening.
    let wasHeld: Bool
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

        let asked = Remembered(session, wasHeld: wasHeld, among: openings)

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
    private let wasHeld: Bool
    private let openings: RecentOpenings
    private let state: OSAllocatedUnfairLock<(remembered: ContinuousClock.Instant, isAsked: Bool)>

    init(_ session: String, wasHeld: Bool, among openings: RecentOpenings) {
        self.session = session
        self.wasHeld = wasHeld
        self.openings = openings
        state = OSAllocatedUnfairLock(initialState: (openings.remember(session, wasHeld: wasHeld), false))
    }

    var isAsked: Bool { state.withLock(\.isAsked) }

    @Sendable func ask() {
        let remembered = openings.remember(session, wasHeld: wasHeld)

        state.withLock { $0 = (remembered, true) }
    }

    func forgetUnasked() {
        let (remembered, isAsked) = state.withLock { $0 }

        if !isAsked {
            openings.forget(session, remembered: remembered)
        }
    }
}

/// The sessions a window was asked for a moment ago, opened or not yet, so a click on one again before it shows on this
/// Mac, or its Claude is back on the board, opens no second. The resume command's Claude reaches the board only once
/// the command has made its terminal session, Claude has started, the plugin loaded and taken the session up and
/// beaten, and the watch printed, which can take a while: so an opening is remembered until its session reads as here
/// (`shown`), or the board shows a window holding it where none did at the click (`heard`), 2 minutes at most. A
/// session a window held at the click is held already, so only being shown forgets its opening.
public final class RecentOpenings: Sendable {
    /// How long an opening is remembered at most.
    public static let lasts = Duration.seconds(120)

    private struct Asked: Sendable {
        let at: ContinuousClock.Instant
        let wasHeld: Bool
    }

    private let now: @Sendable () -> ContinuousClock.Instant
    private let opened = OSAllocatedUnfairLock(initialState: [String: Asked]())

    /// `now` tells the time: the tests' own, in place of the real one.
    public init(now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }) {
        self.now = now
    }

    /// Remembers an opening for the session as of now, which it gives, to forget it by, and whether a live window held
    /// the session at the click.
    @discardableResult
    func remember(_ session: String, wasHeld: Bool = false) -> ContinuousClock.Instant {
        let now = now()

        opened.withLock { $0[session] = Asked(at: now, wasHeld: wasHeld) }
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

    /// Forgets the session's opening, the session read as here, at a click or between them (`HereWatch`): a click on it
    /// is a jump, and one once it is here no more carries it on afresh.
    func shown(_ session: String) {
        opened.withLock { $0[session] = nil }
    }

    /// Forgets the opening of each session a window holds on the board that none held at the click, its Claude back:
    /// a click once it is away again carries it on afresh.
    public func heard(_ board: Board) {
        let held = Set(board.windows.map(\.session))

        opened.withLock { opened in
            opened = opened.filter { $0.value.wasHeld || !held.contains($0.key) }
        }
    }

    /// Whether a window was asked for the session within `lasts`; those asked for longer ago forgotten.
    func isOpening(_ session: String) -> Bool {
        let now = now()

        return opened.withLock { opened in
            opened = opened.filter { now - $0.value.at < Self.lasts }
            return opened[session] != nil
        }
    }
}
