import Foundation
import os
import SitRepCore

/// The jump to a session's window, one at a time, through the plugin's CLI.
@MainActor
final class Works {
    private let logger = Logger(sitrep: "jump")
    private let banners: Banners
    private let oneJump = OneJump()
    private let sitrep: SitRepCLI?

    init(banners: Banners, sitrep: SitRepCLI?) {
        self.banners = banners
        self.sitrep = sitrep
    }

    var isJumping: Bool { oneJump.isRunning }

    /// Jumps to the work's window unless a jump is under way, and tells
    /// `answered` whether it jumped. A jump that fails is told in a banner
    /// once the next jump may run, as a banner may first wait on Lee allowing
    /// banners at all.
    func jump(to work: String, answered: @escaping (Bool) -> Void = { _ in }) {
        Task {
            let answer = await oneJump.run({ await self.sitrep?.jump(to: work) ?? .refused(Plugin.unbuilt) })

            answered(answer == .jumped)
            switch answer {
            case nil:
                logger.notice("Jump to \(work, privacy: .public) refused: another jump is running")
            case let .refused(why):
                await banners.post(.unjumped(why))
            case .jumped:
                break
            }
        }
    }
}
