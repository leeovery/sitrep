import AppKit
import Observation
import SitRepCore
import SitRepMenu
import SitRepPanel
import SitRepRelay
import SwiftUI

/// What Settings reads of the Mac and does for Lee, apart from what he sets: given whole, so its panes can be drawn
/// over a world of their own.
@MainActor
struct SettingsServices {
    /// The displays connected, for Display.
    var displays: () -> [DisplayChoice.Connected]
    /// Liquid Glass, for Material: macOS 26's.
    var hasGlass: Bool
    var jump: (String) -> Void
    var sendTest: () -> Void
    /// Words put on the pasteboard, as Copy puts `/reload-plugins` there.
    var copy: (String) -> Void
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

/// Settings as its window keeps it from one visit to the next: what Lee sets, the pane shown and the panes shown before
/// it, the board and the plugin Claude Code reads, and what the Mac last said of SitRep's leaves and of its displays,
/// so a visit opens on what was last known and its reads then bring it up to date. Whether SitRep starts at login is
/// read as it is made, macOS answering at once. It is the window's one input.
@MainActor
@Observable
final class SettingsModel {
    let preferences: Preferences
    let live: LiveBoard
    let services: SettingsServices
    private(set) var said: MacSays
    private(set) var displays: [DisplayChoice.Connected] = []
    /// The pane shown, and those back and forward step through.
    private(set) var history: PaneHistory
    /// Allow… under way, while macOS's prompt is up.
    private(set) var isAllowing = false
    /// The read of what macOS says begun last, as a pane came into sight.
    @ObservationIgnored private(set) var reading: Task<Void, Never>?
    @ObservationIgnored private var isKey = false

    init(preferences: Preferences, live: LiveBoard, services: SettingsServices) {
        self.preferences = preferences
        self.live = live
        self.services = services
        said = MacSays(login: services.login())
        history = PaneHistory(preferences.app.pane)
    }

    /// The pane shown.
    var pane: SettingsPane { history.shown }

    /// The displays connected, as Edge appears and as the Mac's screens change.
    func readDisplays() {
        displays = services.displays()
    }

    /// The window keyed, or no longer. What macOS says is read as a pane comes into sight while the window is key: each
    /// time the window comes forward, Lee perhaps having changed it in System Settings, and as he turns to a pane.
    func keys(_ isKey: Bool) {
        let wasKey = self.isKey

        self.isKey = isKey
        if isKey, !wasKey {
            readInSight()
        }
    }

    /// A pane picked in the sidebar.
    func turn(to pane: SettingsPane) {
        step { $0.show(pane) }
    }

    /// Back, in the toolbar, to the pane shown before.
    func goBack() {
        step { $0.goBack() }
    }

    func goForward() {
        step { $0.goForward() }
    }

    /// A step through the panes: one turned to is saved, for the window to open on next, and read while the window is
    /// key.
    private func step(_ move: (inout PaneHistory) -> Void) {
        let shown = pane

        move(&history)
        guard pane != shown else {
            return
        }

        preferences.app.pane = pane
        if isKey {
            readInSight()
        }
    }

    private func readInSight() {
        reading = Task { await read() }
    }

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

    /// Show, on a window behind on the plugin: a jump to its session, as the menu's item for it jumps.
    func show(_ reload: ClaudeCodePane.Reload) {
        services.jump(reload.session)
    }

    /// Copy, under the windows behind: the command each needs, on the pasteboard, as SitRep cannot reload a window.
    func copyReloadCommand() {
        services.copy(ClaudeCodePane.command)
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

extension Preferences {
    /// One of the edge's settings, for a control: a change goes through `edit`, saved, and the edge takes it.
    func binding<Value>(_ setting: WritableKeyPath<EdgeSettings, Value>) -> Binding<Value> {
        Binding(get: { self.edge[keyPath: setting] }, set: { value in self.edit { $0[keyPath: setting] = value } })
    }
}
