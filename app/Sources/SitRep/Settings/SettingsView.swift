import SitRepCore
import SitRepMenu
import SitRepPanel
import SwiftUI

/// What the Settings window reads of the Mac and does for Lee, apart from what he sets: given whole, so its panes can
/// be drawn over a world of their own.
@MainActor
struct SettingsServices {
    /// The displays connected, for Display.
    var displays: () -> [DisplayChoice.Connected]
    /// Liquid Glass, for Material: macOS 26's.
    var hasGlass: Bool
    /// The plugin's folder as Lee would write it, `~/Code/sitrep`; nil for a SitRep naming none.
    var pluginFolder: String?
    var jump: (String) -> Void
    var sendTest: () -> Void
    var noticeLeave: () async -> NoticeLeave
    /// macOS asked for leave to notify, as the switch goes on, unless Lee answered already.
    var askForNotices: () async -> Void
    var login: () -> LoginItem
    var chooseLogin: () -> Void
    var ghostty: () async -> GhosttyLeave
    var open: (Leaves.Place) -> Void
}

/// The Settings window (DESIGN, "Settings"): macOS's glass sidebar with SitRep's header and the three panes, the one
/// chosen opening next time.
struct SettingsView: View {
    @Bindable var preferences: Preferences
    let live: LiveBoard
    let services: SettingsServices

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: paneBinding) { pane in
                Label(pane.title, systemImage: pane.symbol).tag(pane)
            }
            .safeAreaInset(edge: .top) {
                AppHeader().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 8)
            }
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            SettingsPaneView(pane: preferences.app.pane, preferences: preferences, live: live, services: services)
                .navigationTitle(preferences.app.pane.title)
        }
    }

    /// The pane shown, kept as the one ⌘, opens next; the sidebar never shows none.
    private var paneBinding: Binding<SettingsPane?> {
        Binding(get: { preferences.app.pane }, set: { pane in
            if let pane {
                preferences.app.pane = pane
            }
        })
    }
}

/// One pane, on its own.
struct SettingsPaneView: View {
    let pane: SettingsPane
    @Bindable var preferences: Preferences
    let live: LiveBoard
    let services: SettingsServices

    var body: some View {
        switch pane {
        case .edge: EdgePaneView(preferences: preferences, services: services)
        case .notifications: NotificationsPaneView(preferences: preferences, services: services)
        case .general: GeneralPaneView(live: live, services: services)
        }
    }
}

extension Preferences {
    /// One of the edge's settings, for a control: a change goes through `edit`, saved, and the edge takes it.
    func binding<Value>(_ setting: WritableKeyPath<EdgeSettings, Value>) -> Binding<Value> {
        Binding(get: { self.edge[keyPath: setting] }, set: { value in self.edit { $0[keyPath: setting] = value } })
    }
}

/// A row of a pane: its title, the line under it, and its control.
struct SettingsRow<Control: View>: View {
    let title: String
    var line: String?
    @ViewBuilder let control: () -> Control

    var body: some View {
        LabeledContent {
            control()
        } label: {
            Text(title)
            if let line {
                Text(line)
            }
        }
    }
}

/// "Change ↗", leaving SitRep for System Settings.
struct ChangeButton: View {
    let action: () -> Void

    var body: some View {
        Button("Change ↗", action: action).buttonStyle(.link)
    }
}
