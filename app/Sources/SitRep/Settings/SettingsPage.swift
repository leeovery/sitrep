import AppKit
import Observation
import SitRepCore
import SitRepMenu
import SitRepPanel
import SitRepRelay
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
    /// The sounds a new ask can play, for Sound, which plays the one chosen.
    var sounds: AlertSounds
    /// Nil when the notices helper does not answer.
    var noticeLeave: () async -> NoticeLeave?
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
    /// The read of what macOS says begun last, as the page came into sight.
    @ObservationIgnored private(set) var reading: Task<Void, Never>?
    @ObservationIgnored private var isShown = false
    @ObservationIgnored private var isKey = false

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

    /// The page shown, or gone. What macOS says is read as the page comes into sight, shown while its window is key:
    /// each time the window comes forward on it, Lee perhaps having changed it in System Settings, and once as the
    /// window opens on it, whether the page shows first or the window keys first.
    func shows(_ isShown: Bool) {
        sight { self.isShown = isShown }
    }

    /// The page's window keyed, or no longer (`shows`).
    func keys(_ isKey: Bool) {
        sight { self.isKey = isKey }
    }

    private func sight(_ change: () -> Void) {
        let wasInSight = isInSight

        change()
        if isInSight, !wasInSight {
            reading = Task { await read() }
        }
    }

    private var isInSight: Bool { isShown && isKey }

    /// What macOS says of SitRep's leaves, each row as its answer comes: the notices helper may take its time.
    func read() async {
        said.login = services.login()

        async let notices: Void = readNotices()
        async let ghostty: Void = readGhostty()

        _ = await (notices, ghostty)
    }

    private func readNotices() async {
        said.notices = await services.noticeLeave()
    }

    private func readGhostty() async {
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

    /// A sound chosen for a new ask, saved and played once, as System Settings › Sound plays an alert sound chosen.
    func choose(sound: String) {
        preferences.app.sound = sound
        services.sounds.play(sound)
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

/// Settings, a page of the SitRep window (DESIGN, "Settings"), set as System Settings sets its grouped form: the
/// title in a project's page's place, then What stays on screen, Notifications and General, 30 apart, in a column as
/// wide as the page less its insets, as a project's page is. It reads what the Mac says as it comes into sight
/// (`SettingsModel.shows`), and its displays as it appears and as they change.
struct SettingsPage: View {
    let settings: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            PageTitle(words: "Settings")
                .padding(.top, 6)
                // the drawing's 28 under a line of 34, where the title's own line is 33, so the first header stands
                // at page y 120 and the title where a project's stands
                .padding(.bottom, 29)
            VStack(alignment: .leading, spacing: SettingsStyle.sectionGap) {
                StaysOnScreenSection(settings: settings)
                notifications
                general
            }
        }
        .padding(.bottom, 40)
        .onAppear {
            settings.readDisplays()
            settings.shows(true)
        }
        .onDisappear { settings.shows(false) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            settings.readDisplays()
        }
    }

    /// The desktop corner a new ask's notification lands on, its caption and Send Test, then the switch and macOS's
    /// own answer; then the sound a new ask plays, which banners, silent, leave alone: its switch, and the sound,
    /// greyed while the switch is off.
    private var notifications: some View {
        let said = settings.said

        return SettingsSection(name: "Notifications") {
            DesktopCorner()
            HStack(spacing: 16) {
                Text("A new ask, as it lands on your desktop").font(.subheadline).foregroundStyle(SettingsStyle.secondary)
                Spacer(minLength: 0)
                Button("Send Test", action: settings.services.sendTest).buttonStyle(.bordered).fixedSize()
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
            .padding(.horizontal, SettingsStyle.inset)
            SettingsCard {
                StatedRow(row: .notify(said.notices, show: settings.preferences.edge.show), isOn: notifies, fix: settings.fix)
                CardSeparator()
                StatedRow(row: .allowed(said.notices), fix: settings.fix)
                CardSeparator()
                CardRow(label: "Play a sound for a new ask", line: "Once, whichever session it lands in") {
                    MiniSwitch(label: "Play a sound for a new ask", isOn: playsSound)
                }
                CardSeparator()
                CardRow(label: "Sound") {
                    PopUp(label: "Sound", sections: [settings.services.sounds.names], title: \.self, selection: sound)
                }
                .disabled(!settings.preferences.app.playsSound)
            }
        }
    }

    /// How long Your turn's rows stay out, the plugin, Open at login, and the leave to bring a session's Ghostty window
    /// to the front.
    private var general: some View {
        SettingsSection(name: "General") {
            SettingsCard {
                CardRow(label: "Your turn folds after", line: "Older ones fold into one line, which opens in place") {
                    PopUp(label: "Your turn folds after", sections: [FoldPeriod.allCases], title: \.title, selection: foldsAfter)
                }
                CardSeparator()
                PluginRow(settings: settings)
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

    private var playsSound: Binding<Bool> {
        Binding(get: { settings.preferences.app.playsSound }, set: { settings.preferences.app.playsSound = $0 })
    }

    private var sound: Binding<String> {
        Binding(get: { settings.preferences.app.sound }, set: settings.choose(sound:))
    }

    private var foldsAfter: Binding<FoldPeriod> {
        Binding(get: { settings.preferences.app.foldsAfter }, set: { settings.preferences.app.foldsAfter = $0 })
    }

    private var opensAtLogin: Binding<Bool> {
        Binding(get: { settings.said.login?.isOn ?? false }, set: { _ in settings.chooseLogin() })
    }
}

/// The plugin's row, on its own as it reads the board, which `watch` brings each time it prints, so the rest of the
/// page is drawn again only as the rest of Settings changes.
private struct PluginRow: View {
    let settings: SettingsModel

    var body: some View {
        StatedRow(
            row: .plugin(settings.live.last, plugin: settings.live.plugin), fix: settings.fix, jump: settings.services.jump
        )
    }
}

extension Preferences {
    /// One of the edge's settings, for a control: a change goes through `edit`, saved, and the edge takes it.
    func binding<Value>(_ setting: WritableKeyPath<EdgeSettings, Value>) -> Binding<Value> {
        Binding(get: { self.edge[keyPath: setting] }, set: { value in self.edit { $0[keyPath: setting] = value } })
    }
}
