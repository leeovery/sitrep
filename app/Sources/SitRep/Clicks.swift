import Foundation
import os
import SitRepCore

/// A click on a session, from any surface: the jump to its window, and, where none shows it, the window opened for it
/// next, apart from the jump; one at a time, the latest click winning (`OneJump`). A click on the same session before
/// either says it is still under way joins it, so a quick second click opens the same window, never a second. A jump
/// or an opening that fails posts its banner, once however many clicks joined it.
@MainActor
final class Clicks {
    /// Opens a window, as a jump found one could be.
    typealias Open = @Sendable () async -> JumpAnswer

    /// What a click's jump came to: an answer; or a window to open.
    enum Reached: Sendable {
        case answered(JumpAnswer)
        case openable(Open)
    }

    /// Every jump's and opening's news, after each click's own: the edge's caption.
    var heard: (JumpNews) -> Void = { _ in }

    private let oneJump: OneJump
    private let jump: (String) -> @Sendable () async -> Reached
    private let logger = Logger(sitrep: "jump")
    /// The window each session's last jump found could be opened, until its opening ends.
    private var openables: [String: Open] = [:]

    /// `jump` makes the jump to a session's window at the click, as Settings then stand; `post` posts a failure's
    /// banner.
    init(
        _ oneJump: OneJump = OneJump(), jump: @escaping (String) -> @Sendable () async -> Reached,
        post: @escaping (Banner) -> Void
    ) {
        self.oneJump = oneJump
        self.jump = jump
        oneJump.heard = { [weak self] news in
            if case let .ended(answer) = news, let banner = answer.banner {
                post(banner)
            }
            self?.heard(news)
        }
    }

    /// Jumps to the session's window, or, where none shows it, opens one. Tells `answered` how it ended, and hands
    /// the front back, `handBack`, where nothing of SitRep's comes forward: refused, as its banner says, or a window
    /// already opening.
    func click(_ session: String, answered: @escaping (JumpAnswer) -> Void, handBack: @escaping () -> Void) {
        let found = Found()
        let jumping = jump(session)

        oneJump.run(to: session, { [logger] in
            await logged("Jump to \(session)", stopped: "A jump", by: logger) {
                switch await jumping() {
                case let .answered(answer):
                    return answer
                case let .openable(open):
                    found.keep(open)
                    return .openable
                }
            }
        }, told: { [weak self] news in
            guard case let .ended(answer) = news, let self else {
                return
            }

            // The click that ran the jump hears first, so a click that joined it opens the same window.
            if let open = found.take(), answer == .openable {
                openables[session] = open
            }
            if answer == .openable, let open = openables[session] {
                self.open(open, for: session, answered: answered, handBack: handBack)
            } else {
                Self.tell(answer, answered, handBack)
            }
        })
    }

    /// Opens the window the jump found could be opened. A click on the same session before the opening says it is
    /// still under way joins it; any other stops it, as a jump is stopped.
    private func open(
        _ open: @escaping Open, for session: String, answered: @escaping (JumpAnswer) -> Void,
        handBack: @escaping () -> Void
    ) {
        oneJump.run(to: session, { [logger] in
            await logged("Opening for \(session)", stopped: "An opening", by: logger, open)
        }, told: { [weak self] news in
            guard case let .ended(answer) = news else {
                return
            }

            self?.openables[session] = nil
            Self.tell(answer, answered, handBack)
        })
    }

    private static func tell(_ answer: JumpAnswer, _ answered: (JumpAnswer) -> Void, _ handBack: () -> Void) {
        answered(answer)
        if answer.banner != nil || answer == .opening {
            handBack()
        }
    }
}

/// What a step came to, logged with how long it took; and, where a later click stopped it, that it was stopped.
private func logged(
    _ step: String, stopped what: String, by logger: Logger, _ run: @Sendable () async -> JumpAnswer
) async -> JumpAnswer {
    let clock = ContinuousClock()
    let started = clock.now
    let answer = await run()
    let took = (clock.now - started).formatted(.units(allowed: [.milliseconds], width: .narrow))
    let ended = String(describing: answer)

    logger.info("\(step, privacy: .public): \(ended, privacy: .public), in \(took, privacy: .public)")
    if Task.isCancelled {
        logger.notice("\(what, privacy: .public) was stopped: a later click took its place")
    }
    return answer
}

/// The window a jump found could be opened, kept for the click that ran it.
private final class Found: Sendable {
    private let open = OSAllocatedUnfairLock<Clicks.Open?>(initialState: nil)

    func keep(_ found: @escaping Clicks.Open) {
        open.withLock { $0 = found }
    }

    func take() -> Clicks.Open? {
        open.withLock { taken in
            defer { taken = nil }
            return taken
        }
    }
}
