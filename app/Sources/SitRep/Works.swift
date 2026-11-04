import Foundation
import os
import SitRepCore

/// The jump to a session's window, through the plugin's CLI: one at a time, the latest click winning.
@MainActor
final class Works {
    private let logger = Logger(sitrep: "jump")
    private let banners: Banners
    private let oneJump = OneJump()
    private let plugin: Plugin

    /// Every jump's news, whichever surface asked for it, after the surface's own `answered`: the edge's caption.
    var heard: (JumpNews) -> Void = { _ in }

    init(banners: Banners, plugin: Plugin) {
        self.banners = banners
        self.plugin = plugin
    }

    /// Jumps to the work's window, stopping any jump under way, and tells `answered` whether it jumped once it ends. A
    /// jump that fails, refused or given no answer within its limit, is told in a banner, and to `refused`; one a later
    /// jump stopped is not, as that one goes on.
    func jump(
        to work: String, answered: @escaping (Bool) -> Void = { _ in }, refused: @escaping () -> Void = {}
    ) {
        let jump: @Sendable () async -> JumpAnswer = { [plugin] in
            await plugin.ask({ await $0.jump(to: work) }, unrun: JumpAnswer.refused)
        }

        oneJump.run(jump) { [weak self] news in
            if case let .ended(answer) = news {
                answered(answer == .jumped)
                self?.ended(answer, to: work, refused: refused)
            }
            self?.heard(news)
        }
    }

    private func ended(_ answer: JumpAnswer, to work: String, refused: () -> Void) {
        switch answer {
        case .jumped:
            break
        case .stopped:
            logger.notice("Jump to \(work, privacy: .public) stopped: a later jump took its place")
        case let .refused(why):
            banners.post(.unjumped(why))
            refused()
        case .unanswered:
            banners.post(.tooBusy)
            refused()
        }
    }
}
