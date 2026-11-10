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
    /// this joins; tells `answered` whether it jumped once it ends, and `refused` when it failed, as its banner says.
    func jump(
        to work: String, answered: @escaping (Bool) -> Void = { _ in }, refused: @escaping () -> Void = {}
    ) {
        let jump: @Sendable () async -> JumpAnswer = { [board, path, logger, commands = commands()] in
            let clock = ContinuousClock()
            let started = clock.now
            let answer = await Jump.live(to: work, on: board, path: path, commands: commands)
            let took = (clock.now - started).formatted(.units(allowed: [.milliseconds], width: .narrow))
            let ended = String(describing: answer)

            logger.info("Jump to \(work, privacy: .public): \(ended, privacy: .public), in \(took, privacy: .public)")
            return answer
        }

        oneJump.run(to: work, jump) { news in
            if case let .ended(answer) = news {
                answered(answer == .jumped)
                if answer.banner != nil {
                    refused()
                }
            }
        }
    }
}

extension AppSettings {
    /// The attach commands Lee set, each empty for SitRep's own.
    var attachCommands: AttachCommands {
        AttachCommands(zmx: zmxAttach, tmux: tmuxAttach)
    }
}
