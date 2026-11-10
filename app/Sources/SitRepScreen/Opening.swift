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
/// its driver, and the open command, empty until he gives one.
public struct OpenSettings: Sendable, Equatable {
    public var terminal: Driver
    public var command: String

    public init(terminal: Driver = .ghostty, command: String = "") {
        self.terminal = terminal
        self.command = command
    }
}

/// A window to open for a session no window shows, as a jump found it: the line to type, the open command filled and
/// fit to type, and the terminal it opens in. It opens apart from the jump, under a limit of its own, on the Space
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
    let driver: any TerminalDriver
    let workspace: any Workspace
    let clock: any JumpClock
    let openings: RecentOpenings

    /// Opens the window, once its terminal is known to be running, within `limit`: opened; refused in plain words;
    /// stopped, as its task is cancelled; or given up at the limit, where a window may yet come. The opening is
    /// remembered as it begins, and forgotten only where it failed before the window was asked for, so a window asked
    /// for is never opened twice.
    public func open() async -> JumpAnswer {
        guard await driver.canOpen() else {
            return .unopened(notRunning)
        }
        guard !Task.isCancelled else {
            return .stopped
        }

        let remembered = openings.remember(session)

        if let answered = await answer(within: Self.limit, on: clock, { await opened(remembered) }) {
            return answered
        }

        return Task.isCancelled ? .stopped : .unopened(
            "SitRep gave up waiting for \(terminal.name) to open a window for \(name) after "
                + "\(Self.limit.components.seconds) seconds; one may still appear."
        )
    }

    /// The app in front read as the opening begins, as a jump reads it, so the one it keeps the front from is never
    /// one the opening brought forward; then the window asked for. Where it failed before then, the opening remembered
    /// is forgotten, unless a later one has taken its place.
    private func opened(_ remembered: ContinuousClock.Instant) async -> JumpAnswer {
        let asked = Asked()
        let front = await workspace.frontmost()

        do {
            guard try await driver.openWindow(running: line, front: front, sending: asked.mark) else {
                openings.forget(session, remembered: remembered)
                return .unopened(notRunning)
            }

            return .opened
        } catch {
            if !asked.isMarked {
                openings.forget(session, remembered: remembered)
            }
            return error is CancellationError ? .stopped : .unopened(String(describing: error))
        }
    }

    private var notRunning: String {
        "SitRep opens a window only in a \(terminal.name) already running. Open \(terminal.name), then click \(name) "
            + "again."
    }
}

/// Whether the window was asked for: marked as the event asking for it is about to go.
private final class Asked: Sendable {
    private let marked = OSAllocatedUnfairLock(initialState: false)

    var isMarked: Bool { marked.withLock { $0 } }

    @Sendable func mark() {
        marked.withLock { $0 = true }
    }
}

/// The sessions a window was asked for a moment ago, opened or not yet, so a click on one again before its window shows
/// it opens no second: the window's shell takes 0.5 to 2 seconds to start and run the line, and only then is the
/// session's client on screen.
public final class RecentOpenings: Sendable {
    /// How long an opening is remembered.
    public static let lasts = Duration.seconds(10)

    private let now: @Sendable () -> ContinuousClock.Instant
    private let opened = OSAllocatedUnfairLock(initialState: [String: ContinuousClock.Instant]())

    /// `now` tells the time: the tests' own, in place of the real one.
    public init(now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }) {
        self.now = now
    }

    /// Remembers an opening for the session as of now, which it gives, to forget it by.
    @discardableResult
    func remember(_ session: String) -> ContinuousClock.Instant {
        let now = now()

        opened.withLock { $0[session] = now }
        return now
    }

    /// Forgets the session's opening remembered at the instant given; none remembered since.
    func forget(_ session: String, remembered: ContinuousClock.Instant) {
        opened.withLock { opened in
            if opened[session] == remembered {
                opened[session] = nil
            }
        }
    }

    /// Whether a window was asked for the session within `lasts`; those asked for longer ago forgotten.
    func isOpening(_ session: String) -> Bool {
        let now = now()

        return opened.withLock { opened in
            opened = opened.filter { now - $0.value < Self.lasts }
            return opened[session] != nil
        }
    }
}
