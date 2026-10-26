import Foundation
import SitRepCore
import SitRepPanel

/// Lee's snoozes and wakes, through the plugin's CLI: a snooze's time worked out as it is pressed, on the Gregorian
/// calendar in the Mac's time zone (`WakeTime.calendar`). A row's menu has nowhere to say a refusal, so a banner says it, as a jump's does; a
/// card says its own.
@MainActor
final class Snoozes {
    private let plugin: Plugin
    private let banners: Banners

    init(plugin: Plugin, banners: Banners) {
        self.plugin = plugin
        self.banners = banners
    }

    /// The asks of a session snoozed until the time chosen, worked out now: what it came to.
    func snooze(_ asks: [String], of session: String, _ choice: SnoozeChoice) async -> WriteAnswer {
        let until = choice.wakes(after: Date(), in: WakeTime.calendar)

        return await plugin.ask({ await $0.snooze(asks, of: session, until: until) }, unrun: WriteAnswer.refused)
    }

    /// The asks of a session woken now: what it came to.
    func wake(_ asks: [String], of session: String) async -> WriteAnswer {
        await plugin.ask({ await $0.wake(asks, of: session) }, unrun: WriteAnswer.refused)
    }

    /// A row's asks snoozed, a refusal told in a banner.
    func snoozeRow(_ asks: [String], of session: String, _ choice: SnoozeChoice) {
        Task {
            if case let .refused(why) = await snooze(asks, of: session, choice) {
                banners.post(.unsnoozed(why))
            }
        }
    }

    /// A row's asks woken, a refusal told in a banner.
    func wakeRow(_ asks: [String], of session: String) {
        Task {
            if case let .refused(why) = await wake(asks, of: session) {
                banners.post(.unwoken(why))
            }
        }
    }
}
