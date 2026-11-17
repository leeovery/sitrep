import SitRepPanel
import SwiftUI

/// Snooze (DESIGN, "Settings"): Choices, a card of Snooze's six choices in their order, each a row with its controls and
/// its switch, the controls greyed while it is off; under the card, what offers them.
struct SnoozePane: View {
    let settings: SettingsModel

    static let caption = "SitRep's Snooze menus and the pane in Claude Code offer these. The menus also offer Until it moves."

    var body: some View {
        SettingsSection(name: "Choices") {
            SettingsCard {
                ForEach(SnoozeChoice.allCases, id: \.self) { choice in
                    if choice != SnoozeChoice.allCases.first {
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
        case .inAnHour: "One hour from when you snooze"
        case .laterToday: "This many hours from when you snooze"
        case .tonight: "At this time today; not offered once it has passed"
        case .tomorrow: "At this time tomorrow"
        case .thisWeekend: "On this day this week; not offered once it has passed"
        case .nextWeek: "On this day next week"
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
