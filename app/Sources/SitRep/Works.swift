import Foundation
import os
import SitRepCore

/// The jump to a session's window, through the plugin's CLI: one at a time, the latest click winning (`OneJump`).
@MainActor
final class Works {
    private let logger = Logger(sitrep: "jump")
    private let oneJump = OneJump()
    private let plugin: Plugin

    /// Every jump's news, once a jump, whichever surface asked for it, after each click's own `answered`: the edge's
    /// caption.
    var heard: (JumpNews) -> Void = { _ in }

    /// A jump that fails is told in a banner (`JumpAnswer.banner`).
    init(banners: Banners, plugin: Plugin) {
        self.plugin = plugin
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

    /// Jumps to the work's window, in place of any jump under way but one to the same work not yet still jumping, which
    /// this joins; tells `answered` whether it jumped once it ends, and `refused` when it failed, as its banner says.
    func jump(
        to work: String, answered: @escaping (Bool) -> Void = { _ in }, refused: @escaping () -> Void = {}
    ) {
        let jump: @Sendable () async -> JumpAnswer = { [plugin] in
            await plugin.ask({ await $0.jump(to: work) }, unrun: JumpAnswer.refused)
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
