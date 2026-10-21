import AppKit
import SitRepCore
import SitRepMenu
import SitRepPanel
import SwiftUI

/// What Settings reads of the Mac and does for Lee, apart from what he sets: given whole, so the page can be drawn over
/// a world of its own.
@MainActor
struct SettingsServices {
    /// The displays connected, for Display.
    var displays: () -> [DisplayChoice.Connected]
    /// Liquid Glass, for Material: macOS 26's.
    var hasGlass: Bool
    var jump: (String) -> Void
    var sendTest: () -> Void
    var noticeLeave: () async -> NoticeLeave
    /// macOS asked for leave to notify, as the switch goes on, unless Lee answered already.
    var askForNotices: () async -> Void
    var login: () -> LoginItem
    var chooseLogin: () -> Void
    var ghostty: () async -> GhosttyLeave
    /// macOS's own prompt for the leave to control Ghostty, and what Lee chose.
    var allowGhostty: () async -> GhosttyLeave
    var open: (Leaves.Place) -> Void
}

/// What macOS says of SitRep's leaves, nil until it is read.
struct MacSays: Equatable {
    var notices: NoticeLeave?
    var login: LoginItem?
    var ghostty: GhosttyLeave?
}

/// Settings, a page of the SitRep window (DESIGN, "Settings"), set as a project's page is: the title, then What stays
/// on screen, Notifications and General, 36 apart. What macOS says is read as the page appears and again each time a
/// window comes forward, as Lee may have changed it in System Settings.
struct SettingsPage: View {
    @Bindable var preferences: Preferences
    let live: LiveBoard
    let services: SettingsServices
    @State private var said: MacSays

    /// What macOS says, given, shows at once, as the stills draw it.
    init(preferences: Preferences, live: LiveBoard, services: SettingsServices, said: MacSays = MacSays()) {
        self.preferences = preferences
        self.live = live
        self.services = services
        _said = State(initialValue: said)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            Text("Settings")
                .font(WindowStyle.ui(28, .bold))
                .spacing(-0.03, of: 28)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 6)
                .padding(.bottom, 36)
            VStack(alignment: .leading, spacing: 36) {
                StaysOnScreenSection(preferences: preferences, services: services)
                notifications
                general
            }
        }
        .padding(.bottom, 28)
        .task { await read() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await read() }
        }
    }

    /// The desktop corner a new ask's notification lands on, Send Test, then the switch and macOS's own answer.
    private var notifications: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(name: "Notifications")
            DesktopCorner()
            HStack(spacing: 16) {
                Text("A new ask, as it lands on your desktop").font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Send Test", action: services.sendTest).buttonStyle(.bordered)
            }
            .padding(.horizontal, 2)
            SettingsCard {
                StatedRow(row: .notify(said.notices, show: preferences.edge.show), isOn: notifies, fix: fix)
                CardSeparator()
                StatedRow(row: .allowed(said.notices), fix: fix)
            }
        }
    }

    /// The plugin, Open at login, and the leave to bring a session's Ghostty window to the front.
    private var general: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(name: "General")
            SettingsCard {
                StatedRow(row: .plugin(live.last, plugin: live.plugin), icon: "terminal", fix: fix, jump: services.jump)
                CardSeparator()
                StatedRow(row: .login(said.login), isOn: opensAtLogin, fix: fix)
                CardSeparator()
                StatedRow(row: .ghostty(said.ghostty), fix: fix)
            }
        }
    }

    /// The switch: turned on, macOS is asked for leave, unless Lee answered already.
    private var notifies: Binding<Bool> {
        Binding(get: { preferences.app.notifiesNewAsks }, set: { isOn in
            preferences.app.notifiesNewAsks = isOn
            if isOn {
                Task {
                    await services.askForNotices()
                    await read()
                }
            }
        })
    }

    /// Open at login, from the login item's real status, read again once Lee flips it.
    private var opensAtLogin: Binding<Bool> {
        Binding(get: { said.login?.isOn ?? false }, set: { _ in
            services.chooseLogin()
            said.login = services.login()
        })
    }

    private func fix(_ fix: SettingsRow.Fix) {
        switch fix {
        case .notifications: services.open(.notifications)
        case .automation: services.open(.automation)
        case .loginItems: services.open(.loginItems)
        case .allowGhostty: Task { said.ghostty = await services.allowGhostty() }
        }
    }

    private func read() async {
        said.login = services.login()
        said.notices = await services.noticeLeave()
        said.ghostty = await services.ghostty()
    }
}

extension Preferences {
    /// One of the edge's settings, for a control: a change goes through `edit`, saved, and the edge takes it.
    func binding<Value>(_ setting: WritableKeyPath<EdgeSettings, Value>) -> Binding<Value> {
        Binding(get: { self.edge[keyPath: setting] }, set: { value in self.edit { $0[keyPath: setting] = value } })
    }
}
