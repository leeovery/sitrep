import Foundation
import SitRepCore
import SitRepMenu
import SitRepScreen

/// The jump to a session's window, SitRep's own (`Jump`), from the watch's last line, or a window opened for a session
/// no terminal on this Mac shows, held or away: one at a time, the latest click winning (`Clicks`).
@MainActor
final class Works {
    private let board: JumpBoard
    private let openings: RecentOpenings
    private let clicks: Clicks

    /// Every jump's news, once a jump, whichever surface asked for it, after each click's own `answered`: the edge's
    /// caption.
    var heard: (JumpNews) -> Void = { _ in }

    /// A jump that fails is told in a banner (`JumpAnswer.banner`); tmux is found on Lee's PATH, as `path` gives it,
    /// the login shell's found once and kept, asked for at each jump within its limit; a window is opened as `opening`
    /// gives Lee's settings at the click.
    init(banners: Banners, path: @escaping @Sendable () async -> String, opening: @escaping () -> OpenSettings) {
        let board = JumpBoard()
        let openings = RecentOpenings()

        self.board = board
        self.openings = openings
        clicks = Clicks(jump: { session in
            let opening = opening()

            return {
                switch await Jump.live(to: session, on: board, path: path, opening: opening, openings: openings) {
                case let .answered(answer):
                    .answered(answer)
                case let .openable(window):
                    .openable(window.open)
                }
            }
        }, post: banners.post)
        clicks.heard = { [weak self] news in self?.heard(news) }
    }

    /// Each look of the watch, the board a jump goes from, and which tells a session resumed back.
    func show(_ last: LastBoard) {
        board.heard(last)
        last.board.map(openings.heard)
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
    /// How a window is opened for a session no terminal on this Mac shows, as Lee set it: a terminal SitRep no longer
    /// has a driver for read as Ghostty, and a resume command never set as the default.
    var openSettings: OpenSettings {
        OpenSettings(
            terminal: Driver.all.first { $0.program == terminal } ?? .ghostty,
            resumeCommand: resumeCommand ?? OpenSettings.defaultResumeCommand
        )
    }
}
