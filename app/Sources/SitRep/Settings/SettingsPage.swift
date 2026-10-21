import AppKit
import Observation
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

/// Settings as the window keeps it from one visit to the next: what Lee sets, the board and the plugin General reads,
/// and what the Mac last said of SitRep's leaves and of its displays, so a visit opens on what was last known and its
/// reads then bring it up to date. Whether SitRep starts at login is read as it is made, macOS answering at once. It is
/// the page's one input, the same each time the window draws its page, so a refresh of the window that changes nothing
/// of Settings draws none of it again.
@MainActor
@Observable
final class SettingsModel {
    let preferences: Preferences
    let live: LiveBoard
    let services: SettingsServices
    private(set) var said: MacSays
    private(set) var displays: [DisplayChoice.Connected] = []
    /// Allow… under way, while macOS's prompt is up.
    private(set) var isAllowing = false

    init(preferences: Preferences, live: LiveBoard, services: SettingsServices) {
        self.preferences = preferences
        self.live = live
        self.services = services
        said = MacSays(login: services.login())
    }

    /// The displays connected, as the page appears and as the Mac's screens change.
    func readDisplays() {
        displays = services.displays()
    }

    /// What macOS says, as the page appears and each time a window comes forward, as Lee may have changed it in
    /// System Settings.
    func read() async {
        said.login = services.login()
        said.notices = await services.noticeLeave()
        said.ghostty = await services.ghostty()
    }

    /// Notify me of a new ask, turned on or off: on, macOS is asked for leave, unless Lee answered already.
    func notify(_ isOn: Bool) {
        preferences.app.notifiesNewAsks = isOn
        if isOn {
            Task {
                await services.askForNotices()
                await read()
            }
        }
    }

    /// Open at login, flipped, and its real status read again.
    func chooseLogin() {
        services.chooseLogin()
        said.login = services.login()
    }

    /// A row's button pressed. Allow… is pressed once while its prompt is up.
    func fix(_ fix: SettingsRow.Fix) {
        switch fix {
        case .notifications: services.open(.notifications)
        case .automation: services.open(.automation)
        case .loginItems: services.open(.loginItems)
        case .allowGhostty: allowGhostty()
        }
    }

    private func allowGhostty() {
        guard !isAllowing else {
            return
        }

        isAllowing = true
        Task {
            said.ghostty = await services.allowGhostty()
            isAllowing = false
        }
    }
}

/// Settings, a page of the SitRep window (DESIGN, "Settings"), set as a project's page is: the title, then What stays
/// on screen, Notifications and General, 36 apart. It reads what the Mac says as it appears, again each time a window
/// comes forward, and its displays as they change.
struct SettingsPage: View {
    let settings: SettingsModel

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
                StaysOnScreenSection(settings: settings)
                notifications
                general
            }
        }
        .padding(.bottom, 28)
        .onAppear(perform: settings.readDisplays)
        .task { await settings.read() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await settings.read() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            settings.readDisplays()
        }
    }

    /// The desktop corner a new ask's notification lands on, Send Test, then the switch and macOS's own answer.
    private var notifications: some View {
        let said = settings.said

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeading(name: "Notifications")
            DesktopCorner()
            HStack(spacing: 16) {
                Text("A new ask, as it lands on your desktop").font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Send Test", action: settings.services.sendTest).buttonStyle(.bordered)
            }
            .padding(.horizontal, 2)
            SettingsCard {
                StatedRow(row: .notify(said.notices, show: settings.preferences.edge.show), isOn: notifies, fix: settings.fix)
                CardSeparator()
                StatedRow(row: .allowed(said.notices), fix: settings.fix)
            }
        }
    }

    /// The plugin, Open at login, and the leave to bring a session's Ghostty window to the front.
    private var general: some View {
        let live = settings.live

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeading(name: "General")
            SettingsCard {
                StatedRow(
                    row: .plugin(live.last, plugin: live.plugin), icon: "terminal", fix: settings.fix,
                    jump: settings.services.jump
                )
                CardSeparator()
                StatedRow(row: .login(settings.said.login), isOn: opensAtLogin, fix: settings.fix)
                CardSeparator()
                StatedRow(row: .ghostty(settings.said.ghostty), isBusy: settings.isAllowing, fix: settings.fix)
            }
        }
    }

    private var notifies: Binding<Bool> {
        Binding(get: { settings.preferences.app.notifiesNewAsks }, set: settings.notify)
    }

    private var opensAtLogin: Binding<Bool> {
        Binding(get: { settings.said.login?.isOn ?? false }, set: { _ in settings.chooseLogin() })
    }
}

extension Preferences {
    /// One of the edge's settings, for a control: a change goes through `edit`, saved, and the edge takes it.
    func binding<Value>(_ setting: WritableKeyPath<EdgeSettings, Value>) -> Binding<Value> {
        Binding(get: { self.edge[keyPath: setting] }, set: { value in self.edit { $0[keyPath: setting] = value } })
    }
}
