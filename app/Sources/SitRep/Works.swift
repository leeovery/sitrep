import Foundation
import os
import SitRepCore

/// The jump to a session's window, one at a time, through the plugin's CLI.
@MainActor
final class Works {
    private let logger = Logger(sitrep: "jump")
    private let banners: Banners
    private let oneJump = OneJump()
    private let plugin: Plugin

    init(banners: Banners, plugin: Plugin) {
        self.banners = banners
        self.plugin = plugin
    }

    var isJumping: Bool { oneJump.isRunning }

    /// Jumps to the work's window unless a jump is under way, and tells
    /// `answered` whether it jumped. A jump that fails is told in a banner
    /// once the next jump may run, as a banner may first wait on Lee allowing
    /// banners at all, and to `refused`; one turned away for another running
    /// is not, as that one brings its window forward.
    func jump(
        to work: String, answered: @escaping (Bool) -> Void = { _ in }, refused: @escaping () -> Void = {}
    ) {
        Task {
            let answer = await oneJump.run({ await self.plugin.ask({ await $0.jump(to: work) }, unrun: JumpAnswer.refused) })

            answered(answer == .jumped)
            switch answer {
            case nil:
                logger.notice("Jump to \(work, privacy: .public) refused: another jump is running")
            case let .refused(why):
                banners.post(.unjumped(why))
                refused()
            case .jumped:
                break
            }
        }
    }
}
