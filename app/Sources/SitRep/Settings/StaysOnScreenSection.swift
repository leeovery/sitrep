import SitRepMenu
import SitRepPanel
import SwiftUI

/// What stays on screen: the three pictures, then the card of the rows that apply to the choice (`StaysOnScreen`), each
/// arriving and leaving by the system's own transition, at once under reduced motion; with Nothing, one line says what
/// carries the board.
struct StaysOnScreenSection: View {
    @Bindable var preferences: Preferences
    let services: SettingsServices

    @Environment(\.reducesWindowMotion) private var reducesMotion
    @State private var isSliding = false

    var body: some View {
        let rows = StaysOnScreen.rows(preferences.edge, hasGlass: services.hasGlass)

        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(name: "What stays on screen")
            ShowPictures(show: preferences.binding(\.show))
            if rows.isEmpty {
                Text(StaysOnScreen.menuCarries).font(.system(size: 13)).foregroundStyle(.secondary)
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

    /// The main display first, then each other by its name.
    private var display: some View {
        let choices = DisplayChoice.choices(among: services.displays(), chosen: preferences.edge.display)

        return Picker("Display", selection: preferences.binding(\.display)) {
            ForEach(choices) { choice in
                Text(choice.name).tag(choice.id)
                if choice == .main, choices.count > 1 {
                    Divider()
                }
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    /// Max, as how far along its slider it is: its right end is Full. The edge follows a drag as it goes, and it is
    /// saved once, as the drag ends.
    private var maxShare: Binding<Double> {
        Binding(get: { preferences.edge.maxLength.share }, set: { share in
            preferences.edit(saving: !isSliding) { $0.maxLength = StripMax(share: share) }
        })
    }

    private func segmented<Value: Hashable>(
        _ label: String, _ setting: WritableKeyPath<EdgeSettings, Value>, _ values: [Value], _ title: KeyPath<Value, String>
    ) -> some View {
        Picker(label, selection: preferences.binding(setting)) {
            ForEach(values, id: \.self) { Text($0[keyPath: title]).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
