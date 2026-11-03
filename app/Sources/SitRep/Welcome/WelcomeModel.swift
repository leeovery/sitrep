import Foundation
import Observation
import SitRepCore
import SitRepMenu
import SitRepPanel
import SitRepRelay

/// What the welcome does to the Mac beyond Settings' services: whether Ghostty runs, Ghostty opened for Allow…, as
/// macOS asks for its leave only while it runs, and the wait on a prompt before the row says where it is.
@MainActor
struct WelcomeMac {
    var ghosttyRuns: () -> Bool
    var openGhostty: () async -> Void
    var wait: (Duration) async -> Void

    static let live = WelcomeMac(
        ghosttyRuns: { Leaves.ghosttyRuns }, openGhostty: { await Leaves.openGhostty() },
        wait: { try? await Task.sleep(for: $0) }
    )
}

/// The welcome as one visit keeps it (DESIGN, "The welcome window"): the step Lee is on, the login item and the two
/// leaves as macOS last said them, and the sounds he has chosen, each of which the stage's notch swells with. A visit
/// lasts from the window opening until it closes: opened again while it shows, it goes back to its first step and keeps
/// the rest. What he sets goes straight to `Preferences`, so the stage and the real edge move at once. It reads and
/// changes the Mac through Settings' own services and `WelcomeMac`, so a test never registers SitRep, asks macOS, opens
/// Ghostty, copies or plays a sound; its sounds are its own, so stopping them never cuts off a new ask's.
@MainActor
@Observable
final class WelcomeModel {
    let preferences: Preferences
    let live: LiveBoard
    let services: SettingsServices
    let mac: WelcomeMac
    private(set) var steps = WelcomeSteps()
    private(set) var login: LoginItem
    /// What macOS lets SitRep do with notifications, and whether it may control Ghostty: nil until read.
    private(set) var notices: NoticeLeave?
    private(set) var ghostty: GhosttyLeave?
    /// The rows whose ask is under way, each with whether Lee has waited long on its prompt.
    private(set) var asking: [WelcomePermission: Bool] = [:]
    /// Each row's ask, and the last read of both leaves: internal only for the tests, which await them.
    @ObservationIgnored private(set) var asks: [WelcomePermission: Task<Void, Never>] = [:]
    @ObservationIgnored private(set) var reading: Task<Void, Never>?
    /// How many sounds Lee has chosen this visit: the stage's notch swells with each.
    private(set) var chimes = 0
    /// Whether the window shows, from its opening until it closes.
    private(set) var isVisiting = false
    /// Whether this visit registered SitRep to open at login, so macOS's notice came with it.
    private(set) var registeredThisVisit = false
    /// Closes the window, for Skip setup and Done: the window sets it as it is made.
    @ObservationIgnored var closeWindow: () -> Void = {}
    @ObservationIgnored private var plan: WelcomeLogin

    init(preferences: Preferences, live: LiveBoard, services: SettingsServices, mac: WelcomeMac) {
        self.preferences = preferences
        self.live = live
        self.services = services
        self.mac = mac
        login = services.login()
        plan = WelcomeLogin(isFirst: !preferences.welcomed)
    }

    var step: WelcomeStep { steps.current }

    /// The menu's Welcome…: the first step, whenever it opens. A visit begins only where none is under way, with the
    /// login item read afresh, and the first welcome only while none has closed; one under way keeps what it did.
    func open() {
        steps.restart()
        guard !isVisiting else {
            return
        }

        isVisiting = true
        registeredThisVisit = false
        plan = WelcomeLogin(isFirst: !preferences.welcomed)
        readLogin()
    }

    /// Continue: the next step, or at the last, Done, which closes the window and leaves the callout beside the real
    /// edge, as no other close does.
    func goOn() {
        guard !steps.isLast else {
            preferences.callout.done()
            closeWindow()
            return
        }

        steps.next()
        arrived()
    }

    func goBack() {
        steps.back()
        arrived()
    }

    /// Skip setup: what Lee set stays, and the defaults stand for the rest, as the window closes.
    func skip() {
        closeWindow()
    }

    /// The window closing, however it closes: SitRep registered where the first welcome is due to, the welcome's sound
    /// stopped, and the welcome done with on this Mac.
    func close() {
        readLogin()
        if plan.close(login) {
            register()
        }
        services.sounds.stop()
        preferences.welcomed = true
        isVisiting = false
    }

    /// The login item as macOS says it now: before every act on it, and each time the window comes forward, as Lee
    /// may have changed it, or approved it, in System Settings. Found on or changed, it is his (`WelcomeLogin.read`).
    func readLogin() {
        login = services.login()
        plan.read(login)
    }

    /// At the sound's step, the first welcome registers SitRep, so macOS's notice comes as the stage shows it; at the
    /// steps that show the leaves, they are read afresh.
    private func arrived() {
        switch step {
        case .sound:
            readLogin()
            if plan.arrive(login) {
                register()
            }
        case .permissions, .ready:
            readLeaves()
        case .hello, .ask, .edge:
            break
        }
    }

    /// SitRep registered to open at login: only where macOS says now that it is not, so it never unregisters.
    private func register() {
        readLogin()
        guard login.choice == .register else {
            return
        }

        services.chooseLogin()
        readLogin()
        registeredThisVisit = registeredThisVisit || login.isOn
    }

    // MARK: Your edge

    /// Notch or Strip, set at once: the stage and the real edge take it.
    func choose(_ show: EdgeSettings.Show) {
        preferences.edit { $0.show = show }
    }

    // MARK: Its sound, and its start

    var sounds: WelcomeSounds { WelcomeSounds(services.sounds.names) }

    /// The sound a new ask plays, as `AlertSounds` reads the one saved; nil for No sound.
    var sound: String? {
        preferences.app.playsSound ? services.sounds.chosen(preferences.app.sound) : nil
    }

    /// A row clicked: its sound chosen, in one change, and played once; or No sound, which turns off Play a sound for a
    /// new ask. The stage's notch swells with either, so the sound and the light are learnt together.
    func choose(sound: String?) {
        var app = preferences.app

        app.playsSound = sound != nil
        app.sound = sound ?? app.sound
        preferences.app = app
        sound.map(services.sounds.play)
        chimes += 1
    }

    /// Open SitRep at login, set on or off: the real login item, as General's is, changed only where macOS says now it
    /// stands otherwise, and Lee's from now on.
    func setLogin(_ isOn: Bool) {
        plan.press()
        if isOn {
            register()
        } else {
            readLogin()
            if login.isOn {
                services.chooseLogin()
                readLogin()
            }
        }
    }

    /// The switch's row, as General words it while macOS waits on Lee's approval.
    var loginRow: SettingsRow { .login(login) }

    /// Whether macOS's notice belongs to this visit: on, it came as this visit registered SitRep; off, turning it on
    /// would bring it. An item on since an earlier visit brings none.
    var announcesNotice: Bool {
        !login.isOn || registeredThisVisit
    }

    // MARK: What it asks of macOS

    /// What macOS says of both leaves, each row as its answer comes: each time the window comes forward, as Lee may
    /// have changed them in System Settings, and as he arrives at a step that shows them. Reading asks macOS nothing.
    func readLeaves() {
        reading = Task {
            async let notices: Void = readNotices()
            async let ghostty: Void = readGhostty()

            _ = await (notices, ghostty)
        }
    }

    private func readNotices() async {
        notices = await services.noticeLeave()
    }

    private func readGhostty() async {
        ghostty = await services.ghostty()
    }

    /// Where a row stands: its ask under way, else as macOS last said it.
    func leave(_ permission: WelcomePermission) -> WelcomeLeave {
        if let waitedLong = asking[permission] {
            return .asking(waitedLong: waitedLong)
        }

        return switch permission {
        case .notifications: .notifications(notices, isOn: preferences.app.notifiesNewAsks)
        case .ghostty: .ghostty(ghostty)
        }
    }

    /// A row's button, as the row stands: to ask, macOS asked; refused, System Settings, at the leave's page.
    func press(_ permission: WelcomePermission) {
        switch leave(permission) {
        case .toAsk: ask(permission)
        case .refused: openSettings(for: permission)
        case .asking, .on: break
        }
    }

    /// The ask, its spinner showing until macOS answers, and once Lee has waited long, where macOS put its prompt.
    private func ask(_ permission: WelcomePermission) {
        let waits = Task {
            await mac.wait(WelcomePermission.patience)
            if !Task.isCancelled, asking[permission] == false {
                asking[permission] = true
            }
        }

        asking[permission] = false
        asks[permission] = Task {
            switch permission {
            case .notifications: await turnOnNotifications()
            case .ghostty: await allowGhostty()
            }
            waits.cancel()
            asking[permission] = nil
        }
    }

    /// Turn On…: Notify me of a new ask on, and macOS asked through the notices helper, as Settings' switch asks.
    private func turnOnNotifications() async {
        preferences.app.notifiesNewAsks = true
        await services.askForNotices()
        await readNotices()
    }

    /// Allow…: Ghostty opened first where it isn't running, as macOS asks only while it runs; then macOS's prompt.
    private func allowGhostty() async {
        if !mac.ghosttyRuns() {
            await mac.openGhostty()
        }
        ghostty = await services.allowGhostty()
    }

    /// Refused: the leave's page in System Settings. Notifications' row is still about the switch, so it goes on, for
    /// banners to come once Lee allows them there.
    private func openSettings(for permission: WelcomePermission) {
        switch permission {
        case .notifications:
            preferences.app.notifiesNewAsks = true
            services.open(.notifications)
        case .ghostty:
            services.open(.automation)
        }
    }

    // MARK: Ready

    var reload: WelcomeReload { WelcomeReload(live.plugin) }

    /// Lee's choices played back, read from the real settings.
    var playback: [WelcomePlayback.Row] {
        WelcomePlayback.rows(
            edge: preferences.edge, app: preferences.app, sound: services.sounds.chosen(preferences.app.sound),
            login: login, ghostty: leave(.ghostty)
        )
    }

    /// Copy: `/reload-plugins` on the pasteboard, as the Claude Code pane's Copy puts it there.
    func copyReloadCommand() {
        services.copy(ClaudeCodePane.command)
    }

    func fix(_ fix: WelcomePlayback.Fix) {
        switch fix {
        case .turnOnLogin: setLogin(true)
        case .loginItems: services.open(.loginItems)
        case .allowGhostty, .automation: press(.ghostty)
        }
    }
}
