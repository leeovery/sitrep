import Foundation
import os
import SitRepCore

/// The works on screen and the jump to one, through the plugin's CLI. The
/// app only reads the board and jumps; it never writes to it.
@MainActor
final class Works {
    /// The Info.plist key `app/build` stamps the plugin's folder under.
    private nonisolated static let pluginKey = "SitRepPlugin"

    private nonisolated static let unbuilt = "This SitRep names no plugin to run: build it with app/build."

    private let logger = Logger(sitrep: "jump")
    private let banners: Banners
    private let oneJump = OneJump()
    /// Lee's login shell is asked for its PATH once, as the app starts; the CLI waits on it.
    private let sitrep = Task { await Works.cliOfPlugin() }

    init(banners: Banners) {
        self.banners = banners
    }

    var isJumping: Bool { oneJump.isRunning }

    func list() async -> ListAnswer {
        guard let cli = await sitrep.value else {
            return .failed(Self.unbuilt)
        }

        return await cli.list()
    }

    /// Jumps to the work's window unless a jump is under way; a jump that fails is told in a banner.
    func jump(to work: String) {
        Task {
            let ran = await oneJump.run { await self.jumping(to: work) }

            if !ran {
                logger.notice("Jump to \(work, privacy: .public) refused: another jump is running")
            }
        }
    }

    func sendTestBanner() {
        Task { await banners.post(.test(await list())) }
    }

    private func jumping(to work: String) async {
        guard let cli = await sitrep.value else {
            return await banners.post(.unjumped(Self.unbuilt))
        }

        if case let .refused(why) = await cli.jump(to: work) {
            await banners.post(.unjumped(why))
        }
    }

    private nonisolated static func cliOfPlugin() async -> SitRepCLI? {
        guard let plugin = Bundle.main.object(forInfoDictionaryKey: pluginKey) as? String else {
            Logger(sitrep: "cli").error("No \(pluginKey, privacy: .public) in the Info.plist: \(unbuilt, privacy: .public)")

            return nil
        }

        return SitRepCLI(plugin: URL(fileURLWithPath: plugin), path: await LoginPath.find())
    }
}
