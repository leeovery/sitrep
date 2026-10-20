import SitRepMenu
import SitRepPanel
import SwiftUI

/// At the edge: Show as its three pictures, then Where, The notch, The strip and Look, each only while it applies
/// (`EdgePane`), fading in and out; with Nothing, one line says what carries the board.
struct EdgePaneView: View {
    @Bindable var preferences: Preferences
    let services: SettingsServices
    @State private var isSliding = false

    var body: some View {
        let pane = EdgePane(preferences.edge, hasGlass: services.hasGlass)

        Form {
            Section {
            } header: {
                ShowPictures(show: preferences.binding(\.show)).padding(.vertical, 6)
            }
            if pane.saysMenuCarries {
                Section {
                    Text(EdgePane.menuCarries).foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
            if pane.showsWhere {
                Section("Where") {
                    SettingsRow(title: "Edge", line: "Or drag it across the middle") {
                        segmented(\.edge, EdgeSettings.Edge.allCases, \.title)
                    }
                    SettingsRow(title: "Display") {
                        Picker("Display", selection: preferences.binding(\.display)) {
                            ForEach(DisplayChoice.choices(among: services.displays(), chosen: preferences.edge.display)) {
                                Text($0.name).tag($0.id)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                .transition(.opacity)
            }
            if pane.showsNotch {
                Section("The notch") {
                    SettingsRow(title: "Style", line: "Meniscus pours, Card slides") {
                        segmented(\.style, NotchStyle.allCases, \.title)
                    }
                }
                .transition(.opacity)
            }
            if pane.showsStrip {
                Section("The strip") {
                    SettingsRow(title: "Length", line: "Grows with its marks, or runs the screen's height") {
                        segmented(\.length, StripLength.allCases, \.title)
                    }
                    if pane.showsMax {
                        SettingsRow(title: "Max") {
                            Slider(value: maxShare, in: 0 ... 1) {
                                Text("Max")
                            } minimumValueLabel: {
                                Text("Short")
                            } maximumValueLabel: {
                                Text("Full")
                            } onEditingChanged: { isSliding in
                                self.isSliding = isSliding
                                if !isSliding {
                                    preferences.save()
                                }
                            }
                            .labelsHidden()
                            .frame(width: 220)
                        }
                        .transition(.opacity)
                    }
                }
                .transition(.opacity)
            }
            if pane.showsLook {
                Section("Look") {
                    if pane.showsMaterial {
                        SettingsRow(title: "Material", line: "For the notch and the strip alike") {
                            segmented(\.material, EdgeSettings.Material.allCases, \.title)
                        }
                    }
                    Toggle(isOn: preferences.binding(\.reducesMotion)) {
                        Text("Reduce motion")
                        Text("SitRep follows the Mac's own setting either way")
                    }
                }
                .transition(.opacity)
            }
        }
        .formStyle(.grouped)
        .animation(.easeInOut(duration: 0.25), value: pane)
    }

    /// Max, as how far along its slider it is: its right end is Full. The edge follows a drag as it goes, and it is
    /// saved once, as the drag ends.
    private var maxShare: Binding<Double> {
        Binding(get: { preferences.edge.maxLength.share }, set: { share in
            preferences.edit(saving: !isSliding) { $0.maxLength = StripMax(share: share) }
        })
    }

    private func segmented<Value: Hashable>(
        _ setting: WritableKeyPath<EdgeSettings, Value>, _ values: [Value], _ title: KeyPath<Value, String>
    ) -> some View {
        Picker(selection: preferences.binding(setting)) {
            ForEach(values, id: \.self) { Text($0[keyPath: title]).tag($0) }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
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
