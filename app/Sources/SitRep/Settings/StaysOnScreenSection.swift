import SitRepMenu
import SitRepPanel
import SwiftUI

/// What stays on screen: the three pictures, then the card of the rows that apply to the choice (`StaysOnScreen`), each
/// arriving and leaving by the system's own transition, at once under reduced motion; with Nothing, one line says what
/// carries the board.
struct StaysOnScreenSection: View {
    let settings: SettingsModel

    @Environment(\.reducesWindowMotion) private var reducesMotion
    @State private var isSliding = false

    var body: some View {
        let rows = StaysOnScreen.rows(preferences.edge, hasGlass: settings.services.hasGlass)

        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(name: "What stays on screen")
            ShowPictures(show: preferences.binding(\.show), isOnScreen: settings.isOnScreen)
            if rows.isEmpty {
                Text(StaysOnScreen.menuCarries).font(.system(size: 13)).foregroundStyle(WindowStyle.soft)
            } else {
                SettingsCard {
                    ForEach(Array(rows.enumerated()), id: \.element) { offset, row in
                        VStack(spacing: 0) {
                            if offset > 0 {
                                CardSeparator()
                            }
                            self.row(row)
                        }
                    }
                }
            }
        }
        .animation(reducesMotion ? nil : .default, value: rows)
    }

    @ViewBuilder private func row(_ row: StaysOnScreen.Row) -> some View {
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
        case .length:
            CardRow(label: "Length", line: "Grows with its marks, or runs the screen's height") {
                segmented("Length", \.length, StripLength.allCases, \.title)
            }
        case .max:
            CardRow(label: "Max", line: "How far it grows; its right end is Full") {
                Slider(value: maxShare, in: 0 ... 1) { Text("Max") } onEditingChanged: { isSliding in
                    self.isSliding = isSliding
                    if !isSliding {
                        preferences.save()
                    }
                }
                .labelsHidden()
                .frame(width: WindowStyle.controls)
            }
        case .material:
            CardRow(label: "Material", line: "For the notch and the strip alike") {
                segmented("Material", \.material, EdgeSettings.Material.allCases, \.title)
            }
        case .reduceMotion:
            CardRow(label: "Reduce motion", line: "SitRep follows the Mac's own setting either way") {
                Toggle("Reduce motion", isOn: preferences.binding(\.reducesMotion)).toggleStyle(.switch).labelsHidden()
            }
        }
    }

    private var preferences: Preferences { settings.preferences }

    /// The main display first, then each other by its name.
    private var display: some View {
        let choices = DisplayChoice.choices(among: settings.displays, chosen: preferences.edge.display)
        let sections = [[DisplayChoice.main], choices.filter { $0 != .main }].filter { !$0.isEmpty }

        return PopUp(label: "Display", sections: sections, title: \.name, selection: display(among: choices))
            .frame(width: WindowStyle.controls)
    }

    /// The display chosen, by its choice.
    private func display(among choices: [DisplayChoice]) -> Binding<DisplayChoice> {
        let id = preferences.binding(\.display)

        return Binding(get: { choices.first { $0.id == id.wrappedValue } ?? .main }, set: { id.wrappedValue = $0.id })
    }

    /// Max, as how far along its slider it is: its right end is Full. The edge follows a drag as it goes, and it is
    /// saved once, as the drag ends.
    private var maxShare: Binding<Double> {
        Binding(get: { preferences.edge.maxLength.share }, set: { share in
            preferences.edit(saving: !isSliding) { $0.maxLength = StripMax(share: share) }
        })
    }

    private func segmented<Value: Hashable>(
        _ label: String, _ setting: WritableKeyPath<EdgeSettings, Value>, _ values: [Value],
        _ title: @escaping (Value) -> String
    ) -> some View {
        Segments(label: label, values: values, title: title, selection: preferences.binding(setting))
            .frame(width: WindowStyle.controls)
    }
}

extension EdgeSettings.Edge {
    var title: String { self == .left ? "Left" : "Right" }
}

extension NotchStyle {
    var title: String { self == .meniscus ? "Meniscus" : "Card" }
}

extension StripLength {
    var title: String { self == .grows ? "Grows" : "Full" }
}

extension EdgeSettings.Material {
    var title: String { self == .black ? "Black" : "Glass" }
}
