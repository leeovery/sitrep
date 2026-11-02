import Foundation
import Observation
import SitRepCore
import SitRepMenu
import SitRepPanel

/// The welcome as one visit keeps it (DESIGN, "The welcome window"): the step Lee is on, the login item as macOS last
/// said it, and the sounds he has chosen, each of which the stage's notch swells with. A visit lasts from the window
/// opening until it closes: opened again while it shows, it goes back to its first step and keeps the rest. What he
/// sets goes straight to `Preferences`, so the stage and the real edge move at once. It reads and changes the Mac
/// through Settings' own services, so a test never registers SitRep, copies or plays a sound; its sounds are its own,
/// so stopping them never cuts off a new ask's.
@MainActor
@Observable
final class WelcomeModel {
    let preferences: Preferences
    let live: LiveBoard
    let services: SettingsServices
    private(set) var steps = WelcomeSteps()
    private(set) var login: LoginItem
    /// How many sounds Lee has chosen this visit: the stage's notch swells with each.
    private(set) var chimes = 0
    /// Whether the window shows, from its opening until it closes.
    private(set) var isVisiting = false
    /// Whether this visit registered SitRep to open at login, so macOS's notice came with it.
    private(set) var registeredThisVisit = false
    /// Closes the window, for Skip setup and Done: the window sets it as it is made.
    @ObservationIgnored var closeWindow: () -> Void = {}
    @ObservationIgnored private var plan: WelcomeLogin

    init(preferences: Preferences, live: LiveBoard, services: SettingsServices) {
        self.preferences = preferences
        self.live = live
        self.services = services
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

    /// Continue: the next step, or at the last, Done, which closes the window.
    func goOn() {
        guard !steps.isLast else {
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

    /// At the sound's step, the first welcome registers SitRep, so macOS's notice comes as the stage shows it.
    private func arrived() {
        guard step == .sound else {
            return
        }

        readLogin()
        if plan.arrive(login) {
            register()
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

    // MARK: Ready

    var reload: WelcomeReload { WelcomeReload(live.plugin) }

    /// Lee's choices played back, read from the real settings.
    var playback: [WelcomePlayback.Row] {
        WelcomePlayback.rows(
            edge: preferences.edge, app: preferences.app, sound: services.sounds.chosen(preferences.app.sound),
            login: login
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
        }
    }
}
