import AppKit
import SitRepMenu
import SitRepPanel
import SwiftUI

/// Edge (DESIGN, "Settings"): the Show row's card, then the sections that apply to the choice (`EdgePane`), the
/// notch's, Motion and Keys, each arriving and leaving at once, the pane taking its new height with them; with Nothing,
/// the Show row's card alone. It reads the displays as it appears and as they change, for Display.
struct EdgePaneView: View {
    let settings: SettingsModel

    var body: some View {
        let sections = EdgePane.sections(preferences.edge)

        VStack(alignment: .leading, spacing: SettingsStyle.sectionGap) {
            SettingsCard {
                ShowRow(show: preferences.binding(\.show))
            }
            ForEach(sections, id: \.name) { section in
                SettingsSection(name: section.name) {
                    SettingsCard {
                        ForEach(Array(section.rows.enumerated()), id: \.element) { place, row in
                            if place > 0 {
                                CardSeparator()
                            }
                            self.row(row)
                        }
                    }
                }
            }
        }
        .onAppear(perform: settings.readDisplays)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            settings.readDisplays()
        }
    }

    @ViewBuilder private func row(_ row: EdgePane.Row) -> some View {
        switch row {
        case .edge:
            CardRow(label: "Edge", line: "Or drag it across the middle") {
                segmented("Edge", \.edge, EdgeSettings.Edge.allCases, \.title)
            }
        case .display:
            CardRow(label: "Display") { display }
        case .style:
            CardRow(label: "Style", line: "Meniscus pours, Card slides") {
                segmented("Style", \.style, NotchStyle.allCases, \.title)
            }
        case .reduceMotion:
            CardRow(label: "Reduce motion", line: "SitRep follows the Mac's own setting either way") {
                MiniSwitch(label: "Reduce motion", isOn: preferences.binding(\.reducesMotion))
            }
        case .keys:
            StatedRow(row: .keys(settings.said.keys, asked: preferences.app.askedForKeys), fix: settings.fix)
        }
    }

    private var preferences: Preferences { settings.preferences }

    /// The main display first, then each other by its name.
    private var display: some View {
        let choices = DisplayChoice.choices(among: settings.displays, chosen: preferences.edge.display)
        let sections = [[DisplayChoice.main], choices.filter { $0 != .main }].filter { !$0.isEmpty }

        return PopUp(label: "Display", sections: sections, title: \.name, selection: display(among: choices))
    }

    /// The display chosen, by its choice.
    private func display(among choices: [DisplayChoice]) -> Binding<DisplayChoice> {
        let id = preferences.binding(\.display)

        return Binding(get: { choices.first { $0.id == id.wrappedValue } ?? .main }, set: { id.wrappedValue = $0.id })
    }

    private func segmented<Value: Hashable>(
        _ label: String, _ setting: WritableKeyPath<EdgeSettings, Value>, _ values: [Value],
        _ title: @escaping (Value) -> String
    ) -> some View {
        Segments(label: label, value: preferences.binding(setting), values: values, title: title)
    }
}
