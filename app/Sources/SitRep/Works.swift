import Foundation
import os
import SitRepCore
import SitRepMenu
import SitRepScreen

/// The jump to a session's window, SitRep's own (`Jump`), from the watch's last line, or a window opened for a session
/// no window shows: one at a time, the latest click winning (`OneJump`).
@MainActor
final class Works {
    private let logger = Logger(sitrep: "jump")
    private let oneJump = OneJump()
    private let board = JumpBoard()
    private let path: @Sendable () async -> String
    private let commands: () -> AttachCommands
    private let openings = RecentOpenings()
    /// The window each work's last jump found could be opened, until it opens or is refused.
    private var openables: [String: Opening] = [:]

    /// Every jump's news, once a jump, whichever surface asked for it, after each click's own `answered`: the edge's
    /// caption.
    var heard: (JumpNews) -> Void = { _ in }

    /// A jump that fails is told in a banner (`JumpAnswer.banner`); tmux is found on Lee's PATH, as `path` gives it,
    /// the login shell's found once and kept, asked for at each jump within its limit; a window opened attaches by
    /// the commands Lee sets, as `commands` gives them at the click.
    init(banners: Banners, path: @escaping @Sendable () async -> String, commands: @escaping () -> AttachCommands) {
        self.path = path
        self.commands = commands
        oneJump.heard = { [weak self, logger] news in
            guard let self else {
                return
            }

            if case let .ended(answer) = news {
                if let banner = answer.banner {
                    banners.post(banner)
                }
                if answer == .stopped {
                    logger.notice("A jump was stopped: a later one took its place")
                }
            }
            heard(news)
        }
    }

    /// Each look of the watch, the board a jump goes from.
    func show(_ last: LastBoard) {
        board.heard(last)
    }

    /// No plugin to run the watch, so no board to jump from, for the reason given.
    func unrun(_ why: String) {
        board.unrun(why)
    }

    /// The watch starts on the plugin found: a jump waits for its first line.
    func watchStarted() {
        board.watchStarted()
    }

    /// Jumps to the work's window, in place of any jump under way but one to the same work not yet still jumping, which
    /// this joins; where no window shows it, opens one (`open`). Tells `answered` how it ended, and `refused` when it
    /// failed, as its banner says.
    func jump(
        to work: String, answered: @escaping (JumpAnswer) -> Void = { _ in },
        refused: @escaping () -> Void = {}
    ) {
        let found = Found()
        let jump: @Sendable () async -> JumpAnswer = { [board, path, logger, openings, commands = commands()] in
            await logged("Jump to \(work)", by: logger) {
                switch await Jump.live(to: work, on: board, path: path, commands: commands, openings: openings) {
                case let .answered(answer):
                    return answer
                case let .openable(opening):
                    found.keep(opening)
                    return .openable
                }
            }
        }

        oneJump.run(to: work, jump) { [weak self] news in
            guard case let .ended(answer) = news, let self else {
                return
            }

            // The click that ran the jump hears first, so a click that joined it opens the same window.
            if let opening = found.take() {
                openables[work] = opening
            }
            if answer == .openable, let opening = openables[work] {
                open(opening, for: work, answered: answered, refused: refused)
            } else {
                Self.tell(answer, answered, refused)
            }
        }
    }

    /// Opens a window for a session no window shows, apart from the jump, which ended once it found one could be
    /// opened, so where it opens may be asked of Lee first, outside the jump's limit: today on the Space showing; the
    /// Space picker (stage 7, D) asks here. A click on the same work before it says it is still opening joins it; any
    /// other stops it, as a jump is stopped.
    private func open(
        _ opening: Opening, for work: String, answered: @escaping (JumpAnswer) -> Void,
        refused: @escaping () -> Void
    ) {
        let space = OpenOn.current

        oneJump.run(to: work, { [logger] in
            await logged("Opening for \(work)", by: logger) { await opening.open(on: space) }
        }, told: { [weak self] news in
            guard case let .ended(answer) = news else {
                return
            }

            self?.openables[work] = nil
            Self.tell(answer, answered, refused)
        })
    }

    private static func tell(_ answer: JumpAnswer, _ answered: (JumpAnswer) -> Void, _ refused: () -> Void) {
        answered(answer)
        if answer.banner != nil {
            refused()
        }
    }
}

/// What a step came to, logged with how long it took.
private func logged(
    _ step: String, by logger: Logger, _ run: @Sendable () async -> JumpAnswer
) async -> JumpAnswer {
    let clock = ContinuousClock()
    let started = clock.now
    let answer = await run()
    let took = (clock.now - started).formatted(.units(allowed: [.milliseconds], width: .narrow))
    let ended = String(describing: answer)

    logger.info("\(step, privacy: .public): \(ended, privacy: .public), in \(took, privacy: .public)")
    return answer
}

/// The window a jump found could be opened, kept for the click that ran it.
private final class Found: Sendable {
    private let opening = OSAllocatedUnfairLock<Opening?>(initialState: nil)

    func keep(_ found: Opening) {
        opening.withLock { $0 = found }
    }

    func take() -> Opening? {
        opening.withLock { taken in
            defer { taken = nil }
            return taken
        }
    }
}

extension AppSettings {
    /// The attach commands Lee set, each empty for SitRep's own.
    var attachCommands: AttachCommands {
        AttachCommands(zmx: zmxAttach, tmux: tmuxAttach)
    }
}
