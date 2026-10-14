import Foundation
import os
import SitRepCore

/// The works on screen and the jump to one, through the plugin's CLI. The
/// app only reads the board and jumps; it never writes to it.
@MainActor
final class Works {
    /// The Info.plist key `app/build` stamps the plugin's folder under.
    private static let pluginKey = "SitRepPlugin"

    private static let unbuilt = "This SitRep names no plugin to run: build it with app/build."

    private let logger = Logger(sitrep: "jump")
    private let banners: Banners
    private let oneJump = OneJump()
    private let sitrep: SitRepCLI?

    init(banners: Banners) {
        self.banners = banners
        sitrep = Self.cliOfPlugin()
    }

    var isJumping: Bool { oneJump.isRunning }

    func list() async -> ListAnswer {
        await sitrep?.list() ?? .failed(Self.unbuilt)
    }

    /// Jumps to the work's window unless a jump is under way. A jump that
    /// fails is told in a banner once the next jump may run, as a banner may
    /// first wait on Lee allowing banners at all.
    func jump(to work: String) {
        Task {
            switch await oneJump.run({ await self.sitrep?.jump(to: work) ?? .refused(Self.unbuilt) }) {
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

    private static func cliOfPlugin() -> SitRepCLI? {
        guard let plugin = Bundle.main.object(forInfoDictionaryKey: pluginKey) as? String else {
            Logger(sitrep: "cli").error("No \(pluginKey, privacy: .public) in the Info.plist: \(unbuilt, privacy: .public)")

            return nil
        }

        let shellPath = ShellPath()

        return SitRepCLI(plugin: URL(fileURLWithPath: plugin), path: { await shellPath.path() })
    }
}
