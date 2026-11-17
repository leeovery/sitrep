import SitRepPanel
import SwiftUI

/// Snooze (DESIGN, "Settings"): Choices, a card of Snooze's six choices in their order, each a row with its controls and
/// its switch, the controls greyed while it is off; under the card, what offers them.
struct SnoozePane: View {
    let settings: SettingsModel

    static let caption = "The card and Claude Code's pane offer these, in this order. The card adds Until it moves."

    var body: some View {
        SettingsSection(name: "Choices") {
            SettingsCard {
                ForEach(Array(SnoozeChoice.allCases.enumerated()), id: \.offset) { place, choice in
                    if place > 0 {
                        CardSeparator()
                    }
                    SnoozeRow(choice: choice, settings: snooze)
                }
            }
            CaptionRow(words: Text(Self.caption))
        }
    }

    private var snooze: Binding<SnoozeSettings> {
        Binding(get: { settings.preferences.snooze }, set: { settings.preferences.snooze = $0 })
    }
}

/// A choice's row: its name, when it wakes, and against the card's right what Lee sets of its time, then its switch.
/// While the switch is off its controls grey, and the row's words stay.
struct SnoozeRow: View {
    let choice: SnoozeChoice
    @Binding var settings: SnoozeSettings

    var body: some View {
        CardRow(label: choice.title, line: line) {
            HStack(spacing: 8) {
                controls.disabled(!settings.isOn(choice))
                MiniSwitch(label: choice.title, isOn: isOn)
            }
        }
    }

    /// When it wakes, under its name.
    private var line: String {
        switch choice {
        case .inAnHour: "An hour after you snooze"
        case .laterToday: "That long after you snooze"
        case .tonight: "Today, until its time has passed"
        case .tomorrow: "On the day after today"
        case .thisWeekend: "From Monday until its day and time"
        case .nextWeek: "On its day of the week after this one"
        }
    }

    @ViewBuilder private var controls: some View {
        switch choice {
        case .inAnHour:
            EmptyView()
        case .laterToday:
            PopUp(
                label: "\(choice.title)'s hours", sections: [SnoozeSettings.HoursOn.choices],
                title: { $0 == 1 ? "1 hour" : "\($0) hours" }, selection: $settings.laterToday.hours
            )
        case .tonight:
            TimeField(label: "\(choice.title)'s time", time: $settings.tonight.at)
        case .tomorrow:
            TimeField(label: "\(choice.title)'s time", time: $settings.tomorrow.at)
        case .thisWeekend:
            day(among: Weekday.weekend, $settings.thisWeekend.day)
            TimeField(label: "\(choice.title)'s time", time: $settings.thisWeekend.at)
        case .nextWeek:
            day(among: Weekday.allCases, $settings.nextWeek.day)
            TimeField(label: "\(choice.title)'s time", time: $settings.nextWeek.at)
        }
    }

    private func day(among days: [Weekday], _ day: Binding<Weekday>) -> some View {
        PopUp(label: "\(choice.title)'s day", sections: [days], title: \.title, selection: day)
    }

    private var isOn: Binding<Bool> {
        Binding(get: { settings.isOn(choice) }, set: { settings.set(choice, on: $0) })
    }
}
