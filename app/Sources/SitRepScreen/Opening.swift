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
/// (stage 7, D) adds a Space Lee picks, asked once a jump has answered openable, outside its limit, and gone to as the
/// opening begins.
public enum OpenOn: Sendable, Equatable {
    case current
}

/// A window to open for a session no window shows, as a jump found it: the command to type, fit to type, the session
/// there to attach to, and the app to open it in running. It opens apart from the jump, under a limit of its own, so
/// where it opens can be asked of Lee first; it is remembered once open (`RecentOpenings`).
public struct Opening: Sendable {
    /// How long an opening may take: its three events, 5 seconds each at most, and the second's watch of the front.
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

    /// Opens the window on the Space given, within `limit`: opened; refused in plain words; stopped, as its task is
    /// cancelled before the app answered; unanswered at the limit.
    public func open(on space: OpenOn) async -> JumpAnswer {
        if let answered = await answer(within: Self.limit, on: clock, { await opened(on: space) }) {
            return answered
        }

        return Task.isCancelled ? .stopped : .unanswered
    }

    /// The app in front read as the opening begins, as a jump reads it, so the one it keeps the front from is never
    /// one the opening brought forward.
    private func opened(on space: OpenOn) async -> JumpAnswer {
        let front = await workspace.frontmost()

        do {
            try await go(to: space)
            guard try await driver.openWindow(running: command, front: front) else {
                return Jumped.notRunning(app).answer(named: name)
            }

            openings.remember(session)
            return .opened
        } catch is CancellationError {
            return .stopped
        } catch {
            return .refused(String(describing: error))
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

/// The sessions a window was opened for a moment ago, so a click on one again before its window shows it opens no
/// second window: the window's shell takes 0.5 to 2 seconds to start and run the line, and only then is the session's
/// client on screen.
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
