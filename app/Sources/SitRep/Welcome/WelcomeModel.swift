import Foundation
import Observation
import SitRepCore
import SitRepMenu
import SitRepPanel

/// The welcome as one visit keeps it (DESIGN, "The welcome window"): the step Lee is on, the login item as macOS last
/// said it, and the sounds he has chosen, each of which the stage's notch swells with. What he sets goes straight to
/// `Preferences`, so the stage and the real edge move at once. It reads and changes the Mac through Settings' own
/// services, so a test never registers SitRep, copies or plays a sound.
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

    /// A visit begins, as the window opens: at the first step, the login item read afresh, and the first welcome only
    /// while none has closed.
    func begin() {
        steps.restart()
        login = services.login()
        plan = WelcomeLogin(isFirst: !preferences.welcomed)
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

    /// The window closing, however it closes: SitRep registered where the first welcome is due to, a sound playing
    /// stopped, and the welcome done with on this Mac.
    func close() {
        login = services.login()
        if plan.close(login) {
            register()
        }
        services.sounds.stop()
        preferences.welcomed = true
    }

    /// At the sound's step, the first welcome registers SitRep, so macOS's notice comes as the stage shows it.
    private func arrived() {
        if step == .sound, plan.arrive(login) {
            register()
        }
    }

    private func register() {
        services.chooseLogin()
        login = services.login()
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

    /// A row clicked: its sound chosen and played once, or No sound, which turns off Play a sound for a new ask. The
    /// stage's notch swells with either, so the sound and the light are learnt together.
    func choose(sound: String?) {
        if let sound {
            preferences.app.sound = sound
            preferences.app.playsSound = true
            services.sounds.play(sound)
        } else {
            preferences.app.playsSound = false
        }
        chimes += 1
    }

    /// Open SitRep at login, pressed: the real login item, registered or unregistered at once, as General's is, and
    /// Lee's from now on.
    func pressLogin() {
        plan.press()
        services.chooseLogin()
        login = services.login()
    }

    /// The switch's row, as General words it while macOS waits on Lee's approval.
    var loginRow: SettingsRow { .login(login) }

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
        case .turnOnLogin: pressLogin()
        case .loginItems: services.open(.loginItems)
        }
    }
}
