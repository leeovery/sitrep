import Foundation
import os
import SitRepCore

/// What a jump came to: an answer; or a window to open for a session no window shows, which the one who asked opens
/// next, apart from the jump.
public enum JumpOutcome: Sendable {
    case answered(JumpAnswer)
    case openable(Opening)
}

/// Where a window opened for a session no window shows goes: the Space showing, today the one choice. The Space picker
/// (stage 7, D) adds a Space Lee picks, asked as the opening begins, once the app is known to be running, before any
/// Space is gone to, and outside the opening's limit.
public enum OpenOn: Sendable, Equatable {
    case current
}

/// A window to open for a session no window shows, as a jump found it: the command to type, fit to type, and the
/// session there to attach to. It opens apart from the jump, under a limit of its own, where it opens asked of Lee
/// first; and it is remembered as the app is asked for it (`RecentOpenings`), so a click on its session meanwhile opens
/// no second.
public struct Opening: Sendable {
    /// How long an opening may take once where it opens is chosen: its three events, 5 seconds each at most, and the
    /// second's watch of the front.
    public static let limit = Duration.seconds(20)

    let session: String
    /// The session's name, as a refusal names it.
    let name: String
    let command: String
    let driver: any TerminalDriver
    /// The app it opens in, by name, as a refusal names it.
    let app: String
    let workspace: any Workspace
    let clock: any JumpClock
    let openings: RecentOpenings

    /// Opens the window: once its app is known to be running, where it opens is asked of `choosing`, which may wait on
    /// Lee as long as he takes, outside `limit`, nil for nowhere; then it opens there, within `limit`. Opened; refused
    /// in plain words, naming the session; stopped, as its task is cancelled before the app answered; given up at the
    /// limit, where a window may yet come.
    public func open(choosing: @Sendable () async -> OpenOn?) async -> JumpAnswer {
        guard await driver.canOpen() else {
            return Jumped.notRunning(app).answer(named: name)
        }
        guard let space = await choosing(), !Task.isCancelled else {
            return .stopped
        }
        if let answered = await answer(within: Self.limit, on: clock, { await opened(on: space) }) {
            return answered
        }

        return Task.isCancelled ? .stopped : .unopened(
            "SitRep gave up waiting for a window for \(name) after \(Self.limit.components.seconds) seconds; one may "
                + "still appear."
        )
    }

    /// The app in front read as the opening begins, as a jump reads it, so the one it keeps the front from is never
    /// one the opening brought forward; then the Space gone to, and the window asked for there.
    private func opened(on space: OpenOn) async -> JumpAnswer {
        let front = await workspace.frontmost()

        do {
            try await go(to: space)
            guard try await driver.openWindow(running: command, front: front, sending: { [openings, session] in
                openings.remember(session)
            }) else {
                return Jumped.notRunning(app).answer(named: name)
            }

            openings.remember(session)
            return .opened
        } catch is CancellationError {
            return .stopped
        } catch {
            return .unopened("SitRep was opening a window for \(name). \(error)")
        }
    }

    /// Goes to the Space the window opens on, as a new window opens on the Space showing: the current one is there.
    private func go(to space: OpenOn) async throws {
        switch space {
        case .current:
            return
        }
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

    func remember(_ session: String) {
        let now = now()

        opened.withLock { $0[session] = now }
    }

    /// Whether a window was opened for the session within `lasts`; those opened longer ago forgotten.
    func isOpening(_ session: String) -> Bool {
        let now = now()

        return opened.withLock { opened in
            opened = opened.filter { now - $0.value < Self.lasts }
            return opened[session] != nil
        }
    }
}
