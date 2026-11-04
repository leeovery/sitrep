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

    /// What is named of a session, its asks or its turn, snoozed until the time chosen, worked out now: what it came to.
    func snooze(_ named: Snoozable, of session: String, _ time: SnoozeTime) async -> WriteAnswer {
        let until = time.wakes(after: Date(), in: WakeTime.calendar)

        return await plugin.ask({ await $0.snooze(named, of: session, until: until) }, unrun: WriteAnswer.refused)
    }

    /// What is named of a session, its asks or its turn, woken now: what it came to.
    func wake(_ named: Snoozable, of session: String) async -> WriteAnswer {
        await plugin.ask({ await $0.wake(named, of: session) }, unrun: WriteAnswer.refused)
    }

    /// What a row showed snoozed, its asks or its turn, until the time chosen, worked out now, a refusal told in a
    /// banner.
    func snoozeRow(_ named: Snoozable, of session: String, _ time: SnoozeTime) {
        Task {
            if case let .refused(why) = await snooze(named, of: session, time) {
                banners.post(.unsnoozed(why))
            }
        }
    }

    /// What a row showed asleep, its asks or its turn, woken, a refusal told in a banner.
    func wakeRow(_ named: Snoozable, of session: String) {
        Task {
            if case let .refused(why) = await wake(named, of: session) {
                banners.post(.unwoken(why))
            }
        }
    }
}
