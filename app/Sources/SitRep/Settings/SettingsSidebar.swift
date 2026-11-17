import SitRepMenu
import SwiftUI

/// The Settings window's sidebar: the five panes, each a row with its symbol, in the system's sidebar list, which draws
/// the pane shown in the accent while the window is key and in the system's grey when not. A row's count stands on its
/// right (`SettingsSidebarRow`).
struct SettingsSidebar: View {
    let settings: SettingsModel

    var body: some View {
        List(selection: Binding<SettingsPane?>(get: { settings.pane }, set: settings.select)) {
            ForEach(settings.sidebar) { row in
                Label(row.pane.title, systemImage: row.pane.symbol)
                    .badge(row.count ?? 0)
                    .tag(row.pane)
            }
        }
        .listStyle(.sidebar)
    }
}
