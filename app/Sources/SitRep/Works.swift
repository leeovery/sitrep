import Foundation
import os
import SitRepCore

/// The works on screen and the jump to one, through the plugin's CLI. The
/// app only reads the board and jumps; it never writes to it.
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

    func list() async -> ListAnswer {
        await sitrep?.list() ?? .failed(Plugin.unbuilt)
    }

    /// Jumps to the work's window unless a jump is under way. A jump that
    /// fails is told in a banner once the next jump may run, as a banner may
    /// first wait on Lee allowing banners at all.
    func jump(to work: String) {
        Task {
            switch await oneJump.run({ await self.sitrep?.jump(to: work) ?? .refused(Plugin.unbuilt) }) {
            case nil:
                logger.notice("Jump to \(work, privacy: .public) refused: another jump is running")
            case let .refused(why):
                await banners.post(.unjumped(why))
            case .jumped:
                break
            }
        }
    }

    func sendTestBanner() {
        Task { await banners.post(.test(await list())) }
    }
}
