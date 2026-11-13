import Foundation
import SitRepCore
import SitRepPanel

/// Lee's snoozes and wakes from a card row's menu, through the plugin's CLI: a snooze's time worked out as it is
/// pressed, on the Gregorian calendar in the Mac's time zone (`WakeTime.calendar`). The menu has nowhere to say a
/// refusal, so a banner says it, as a jump's does.
@MainActor
final class Snoozes {
    private let plugin: Plugin
    private let banners: Banners

    init(plugin: Plugin, banners: Banners) {
        self.plugin = plugin
        self.banners = banners
    }

    /// A session snoozed, its row having shown `asks`, until the time chosen, worked out now: what it came to.
    private func snooze(_ session: String, showing asks: [String], _ choice: SnoozeChoice) async -> WriteAnswer {
        let until = choice.wakes(after: Date(), in: WakeTime.calendar)

        return await plugin.ask({ await $0.snooze(session, showing: asks, until: until) }, unrun: WriteAnswer.refused)
    }

    /// A session woken now: what it came to.
    private func wake(_ session: String) async -> WriteAnswer {
        await plugin.ask({ await $0.wake(session) }, unrun: WriteAnswer.refused)
    }

    /// A row's session snoozed, its asks and its turn, until the time chosen, worked out now, a refusal told in a
    /// banner. `asks` are those the row showed.
    func snoozeRow(_ session: String, showing asks: [String], _ choice: SnoozeChoice) {
        Task {
            if case let .refused(why) = await snooze(session, showing: asks, choice) {
                banners.post(.unsnoozed(why))
            }
        }
    }

    /// A Snoozed row's session woken, a refusal told in a banner.
    func wakeRow(_ session: String) {
        Task {
            if case let .refused(why) = await wake(session) {
                banners.post(.unwoken(why))
            }
        }
    }
}
