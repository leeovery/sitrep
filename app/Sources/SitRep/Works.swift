import Foundation
import SitRepCore
import SitRepMenu
import SitRepScreen

/// The jump to a session's window, SitRep's own (`Jump`), from the watch's last line, or a window opened for a session
/// no window shows: one at a time, the latest click winning (`Clicks`).
@MainActor
final class Works {
    private let board: JumpBoard
    private let clicks: Clicks

    /// Every jump's news, once a jump, whichever surface asked for it, after each click's own `answered`: the edge's
    /// caption.
    var heard: (JumpNews) -> Void = { _ in }

    /// A jump that fails is told in a banner (`JumpAnswer.banner`); tmux and zmx are run with Lee's login shell's
    /// environment, as `environment` gives it, found once and kept, asked for at each jump within its limit; a window
    /// opened attaches by the commands Lee sets, as `commands` gives them at the click, on the Space showing, the one
    /// choice until the Space picker (stage 7, D) asks Lee here.
    init(
        banners: Banners, environment: @escaping @Sendable () async -> [String: String],
        commands: @escaping () -> AttachCommands
    ) {
        let board = JumpBoard()
        let openings = RecentOpenings()
        let oneJump = OneJump()

        self.board = board
        clicks = Clicks(oneJump, jump: { session in
            let commands = commands()

            return {
                switch await Jump.live(
                    to: session, on: board, environment: environment, commands: commands, openings: openings
                ) {
                case let .answered(answer):
                    .answered(answer)
                case let .openable(opening):
                    .openable { choosing in await opening.open(choosing: choosing) }
                }
            }
        }, choose: { .current })
        oneJump.heard = { [weak self] news in
            if case let .ended(answer) = news, let banner = answer.banner {
                banners.post(banner)
            }
            self?.heard(news)
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

    /// Jumps to the work's window, or opens one where none shows it (`Clicks`). Tells `answered` how it ended, and
    /// `handBack` where the front is to be given back, as nothing of SitRep's comes forward.
    func jump(
        to work: String, answered: @escaping (JumpAnswer) -> Void = { _ in }, handBack: @escaping () -> Void = {}
    ) {
        clicks.click(work, answered: answered, handBack: handBack)
    }
}

extension AppSettings {
    /// The attach commands Lee set, each empty for SitRep's own.
    var attachCommands: AttachCommands {
        AttachCommands(zmx: zmxAttach, tmux: tmuxAttach)
    }
}
