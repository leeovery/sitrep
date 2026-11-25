import Foundation
import SitRepCore
import SitRepPanel

/// Lee's snoozes and wakes from a card row's menu, and his snooze of one ask from the asks panel's Snooze ▾, through
/// the plugin's CLI: a snooze until the time its menu showed, worked out as it opened, on the Gregorian calendar in the
/// Mac's time zone (`WakeTime.calendar`). The menu has nowhere to say a refusal, so a banner says it, as a jump's does;
/// and so it says a time come already, Tonight on a menu opened before its time and chosen after, which snoozes
/// nothing.
@MainActor
final class Snoozes {
    private let plugin: Plugin
    private let post: @MainActor (Banner) -> Void

    init(plugin: Plugin, post: @escaping @MainActor (Banner) -> Void) {
        self.plugin = plugin
        self.post = post
    }

    /// A session snoozed, its row having shown `asks`, until `until`, or with none until it moves: what it came to.
    private func snooze(_ session: String, showing asks: [String], _ until: Date?) async -> WriteAnswer {
        await plugin.ask({ await $0.snooze(session, showing: asks, until: until) }, unrun: WriteAnswer.refused)
    }

    /// One ask of a session snoozed alone until `until`: what it came to.
    private func snooze(_ session: String, ask: String, _ until: Date) async -> WriteAnswer {
        await plugin.ask({ await $0.snooze(session, ask: ask, until: until) }, unrun: WriteAnswer.refused)
    }

    /// A session woken now: what it came to.
    private func wake(_ session: String) async -> WriteAnswer {
        await plugin.ask({ await $0.wake(session) }, unrun: WriteAnswer.refused)
    }

    /// A row's session snoozed, its asks and its turn, until the time its menu showed, or with none until it moves, a
    /// refusal told in a banner; a time come already snoozes nothing, a banner saying so. `asks` are those the row
    /// showed.
    func snoozeRow(_ session: String, showing asks: [String], _ until: Date?) {
        snoozing(until) { await self.snooze(session, showing: asks, until) }
    }

    /// One ask of the session snoozed alone until the time Snooze ▾ showed, as the pane snoozes one, a refusal told
    /// in a banner; a time come already snoozes nothing, a banner saying so.
    func snoozeAsk(_ session: String, ask: String, _ until: Date) {
        snoozing(until) { await self.snooze(session, ask: ask, until) }
    }

    /// A snooze until `until` run through the CLI, a refusal told in a banner; none run where the time has come
    /// already, a banner saying so.
    private func snoozing(_ until: Date?, _ snooze: @escaping @MainActor () async -> WriteAnswer) {
        if let why = WakeTime.comeAlready(until, at: Date(), in: WakeTime.calendar) {
            return post(.unsnoozed(why))
        }

        Task {
            if case let .refused(why) = await snooze() {
                post(.unsnoozed(why))
            }
        }
    }

    /// A Snoozed row's session woken, a refusal told in a banner.
    func wakeRow(_ session: String) {
        Task {
            if case let .refused(why) = await wake(session) {
                post(.unwoken(why))
            }
        }
    }
}
