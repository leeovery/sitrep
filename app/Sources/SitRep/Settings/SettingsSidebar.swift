import SitRepMenu
import SwiftUI

/// The Settings window's sidebar: the four panes, each a row with its symbol, in the system's sidebar list, which draws
/// the pane shown in the accent while the window is key and in the system's grey when not. While any Claude Code window
/// runs an older plugin, Claude Code's row carries how many on its right, as System Settings counts its updates.
struct SettingsSidebar: View {
    let settings: SettingsModel

    var body: some View {
        let behind = ClaudeCodePane(settings.live.last, plugin: settings.live.plugin).behind

        List(selection: selection) {
            ForEach(SettingsPane.allCases) { pane in
                Label(pane.title, systemImage: pane.symbol)
                    .badge(pane == .claudeCode ? behind : 0)
                    .tag(pane)
            }
        }
        .listStyle(.sidebar)
    }

    /// The pane shown; a click on the list's empty space, which picks none, leaves it shown.
    private var selection: Binding<SettingsPane?> {
        Binding(get: { settings.pane }, set: { pane in
            if let pane {
                settings.turn(to: pane)
            }
        })
    }
}
