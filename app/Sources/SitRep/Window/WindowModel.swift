import AppKit
import Observation
import SitRepCore
import SitRepEdge
import enum SitRepPanel.FoldPeriod
import enum SitRepPanel.SnoozeTime
import SitRepWindow

/// The SitRep window's run, as the views see it: what it lists and shows, kept current as the board, the clock and
/// Lee's presses change it. It runs what the run asks for: the sessions it follows, and a look now, told to the app's
/// one `watch`; and off the main thread an answer, a finish; a snooze or a wake, through the app's `Snoozes`; a jump,
/// through the app's `Works`, one at a time; and `sitrep screen`, on its own cadence while the window shows.
@MainActor
@Observable
final class WindowModel {
    private(set) var sidebar = Sidebar()
    private(set) var page = Page.empty("Looking for sessions…")
    private(set) var pick: Pick?
    /// What the Filter field holds, never saved.
    private(set) var filter = Filter()
    /// The clock the pages are drawn at: ages, washes and an answer's wait.
    private(set) var now = Date()
    /// SitRep's own Reduce motion, or the Mac's, followed as either changes.
    private(set) var reducesMotion: Bool
    /// The window's jump under way, which only the button pressed shows.
    private(set) var jumping = Jumping()

    /// What the views' presses ask the model for.
    @ObservationIgnored private(set) var actions = WindowActions()
    @ObservationIgnored private let run: WindowRun
    /// The calendar the window's wake times are worded on, its run's.
    var calendar: Calendar { run.calendar }
    @ObservationIgnored private let plugin: Plugin
    @ObservationIgnored private let works: Works
    @ObservationIgnored private let snoozes: Snoozes
    @ObservationIgnored private let following: Following
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let saved: SavedSettings<SidebarSettings>
    /// The folds as last saved, which are saved again as they change.
    @ObservationIgnored private var savedFolds: Folds
    @ObservationIgnored private var wake: Task<Void, Never>?
    /// The wait for the next look at the screen.
    @ObservationIgnored private var screenWake: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    private static let lastSessionKey = "windowLastSession"
    /// How often the ages are drawn again while nothing else changes.
    private static let tick: TimeInterval = 30

    /// `period`, how long a your-turn row stays before it folds into "N earlier", as Lee set it.
    init(
        plugin: Plugin, works: Works, snoozes: Snoozes, following: Following, period: FoldPeriod,
        defaults: UserDefaults = .standard
    ) {
        self.plugin = plugin
        self.works = works
        self.snoozes = snoozes
        self.following = following
        self.defaults = defaults
        reducesMotion = Self.readReducesMotion(defaults)
        let saved = SavedSettings<SidebarSettings>(defaults)
        let folds = saved.read().folds

        self.saved = saved
        savedFolds = folds.kept
        run = WindowRun(lastSession: defaults.string(forKey: Self.lastSessionKey), folds: folds, period: period)
        actions = WindowActions(
            pick: { [weak self] in self?.pick($0) },
            pickInList: { [weak self] in self?.pickInList($0) },
            press: { [weak self] in self?.press($0, on: $1) },
            toggle: { [weak self] in self?.toggle($0) },
            toggleItem: { [weak self] in self?.toggle($0) },
            jump: { [weak self] in self?.jump($0) },
            snooze: { [weak self] in self?.snooze($0, $1) },
            wake: { [weak self] in self?.wake($0) },
            snoozeRow: { [weak self] in self?.snoozes.snoozeRow($1, of: $0, $2) },
            wakeRow: { [weak self] in self?.snoozes.wakeRow($1, of: $0) },
            askToFinish: { [weak self] in self?.askToFinish($0) },
            cancelFinish: { [weak self] in self?.cancelFinish($0) },
            confirmFinish: { [weak self] in self?.confirmFinish($0) },
            pointer: { [weak self] in self?.pointer(isIn: $0) },
            pointerOverPage: { [weak self] in self?.pointer(overPage: $0, from: $1) },
            fold: { [weak self] in self?.fold($0) },
            filter: { [weak self] in self?.narrow(to: $0) },
            openFirstMatch: { [weak self] in self?.openFirstMatch() }
        )
        listen()
    }

    private static func readReducesMotion(_ defaults: UserDefaults) -> Bool {
        Displays.reducesMotion(SavedEdgeSettings(defaults).read())
    }

    /// SitRep's setting saved, or the Mac's changing, shows at once, as the edge follows the Mac's.
    private func listen() {
        let follow: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.reducesMotion = Self.readReducesMotion(self.defaults)
            }
        }

        observers = [
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: defaults, queue: .main, using: follow
            ),
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main,
                using: follow
            ),
        ]
    }

    // MARK: Inputs

    func show(_ last: LastBoard) {
        run.show(last, at: Date(), reducesMotion: reducesMotion)
        refresh()
    }

    func unrun(_ why: String) {
        run.unrun(why)
        refresh()
    }

    /// The window opens, on the pick given, else on what it opens on.
    func opened(on pick: Pick? = nil) {
        run.open(on: pick)
        refresh()
        lookAtScreen()
    }

    func closed() {
        run.close()
        refresh()
        lookAtScreen()
    }

    func minimised() {
        run.minimise()
        refresh()
        lookAtScreen()
    }

    func restored() {
        run.restore()
        refresh()
        lookAtScreen()
    }

    /// Escape: the answer pressed last, still waiting, is taken back. Whether there was one.
    func undo() -> Bool {
        defer { refresh() }
        return run.undo()
    }

    func pick(_ pick: Pick) {
        run.pick(pick)
        picked()
    }

    private func pickInList(_ pick: Pick) {
        run.pickInList(pick, at: Date())
        picked()
    }

    /// Lee set how long a your-turn row stays before it folds into "N earlier": the list refolds at once.
    func period(_ period: FoldPeriod) {
        run.period = period
        refresh()
    }

    /// A pick made: the session picked kept as the one the window opens on.
    private func picked() {
        defaults.set(run.lastSession, forKey: Self.lastSessionKey)
        refresh()
    }

    private func press(_ button: Card.Button, on ask: AskAddress) {
        if run.press(button, on: ask, at: Date()) != nil {
            jump(.card(ask, button))
        }
        refresh()
    }

    private func toggle(_ ask: AskAddress) {
        run.toggle(ask)
        refresh()
    }

    private func toggle(_ item: Item) {
        run.toggle(item)
        refresh()
    }

    private func pointer(isIn: Bool) {
        run.pointer(isIn: isIn, at: Date())
        refresh()
    }

    private func pointer(overPage isIn: Bool, from region: ObjectIdentifier) {
        run.pointer(overPage: isIn, from: region, at: Date())
        refresh()
    }

    /// The window became key, or stopped being.
    func window(isKey: Bool) {
        run.window(isKey: isKey, at: Date())
        refresh()
        lookAtScreen()
    }

    /// macOS said whether the window is visible.
    func window(isVisible: Bool) {
        run.window(isVisible: isVisible)
        lookAtScreen()
    }

    /// A heading clicked, or "N earlier": its fold, kept as Lee leaves it (`keepFolds`), unless the filter holds text.
    private func fold(_ fold: Fold) {
        run.toggle(fold)
        refresh()
    }

    private func narrow(to text: String) {
        run.filter = Filter(text)
        refresh()
    }

    private func openFirstMatch() {
        run.openFirstMatch()
        picked()
    }

    private func askToFinish(_ session: String) {
        run.askToFinish(session)
        refresh()
    }

    private func cancelFinish(_ session: String) {
        run.cancelFinish(session)
        refresh()
    }

    private func confirmFinish(_ session: String) {
        guard run.confirmFinish(session) else {
            return
        }

        refresh()
        Task {
            let finished = await plugin.ask({ await $0.finish(session) }, unrun: WriteAnswer.refused)

            lookNow(if: run.finished(session, finished))
        }
    }

    /// A time chosen on a card's Snooze: the ask snoozed, its card saying any refusal.
    private func snooze(_ ask: AskAddress, _ time: SnoozeTime) {
        run.snoozing(ask)
        refresh()
        Task {
            let written = await snoozes.snooze(.asks([ask.ask]), of: ask.session, time)

            lookNow(if: run.snoozed(ask, written))
        }
    }

    /// A card's Wake now: the ask woken, its card saying any refusal.
    private func wake(_ ask: AskAddress) {
        run.snoozing(ask)
        refresh()
        Task {
            let written = await snoozes.wake(.asks([ask.ask]), of: ask.session)

            lookNow(if: run.woke(ask, written))
        }
    }

    /// To the session's window, as the notch's and the menu's jumps go: one at a time, none while one runs from
    /// anywhere. Only the button pressed shows it, until it answers.
    private func jump(_ press: JumpPress) {
        guard jumping.press(press, isJumping: works.isJumping) else {
            return
        }

        works.jump(to: press.session) { [weak self] _ in
            MainActor.assumeIsolated { self?.jumping.answered() }
        }
    }

    // MARK: Running what the run asks for

    /// `sitrep screen`, where the run says a look is due, its answer told to the run, and drawn where it changed what
    /// the window knows; then the next look waited for.
    private func lookAtScreen() {
        if let look = run.looksAtScreen(at: Date()) {
            Task { [weak self] in await self?.runScreen(look) }
        }
        scheduleScreen()
    }

    private func runScreen(_ look: ScreenLook) async {
        let answer = await plugin.ask({ await $0.screen() }, unrun: ScreenAnswer.failed)

        if run.looked(answer, of: look, at: Date()) {
            refresh()
        }
        lookAtScreen()
    }

    private func scheduleScreen() {
        screenWake?.cancel()
        screenWake = run.nextScreenLook.map { next in
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSince(Date()))))
                if !Task.isCancelled {
                    self?.lookAtScreen()
                }
            }
        }
    }

    /// The answers whose two seconds ran out, each to `sitrep answer`.
    private func send() {
        for (ask, answer) in run.due(at: Date()) {
            Task {
                let written = await plugin.ask({ await $0.answer(ask.ask, of: ask.session, with: answer) }, unrun: WriteAnswer.refused)

                lookNow(if: run.answered(ask, written, at: Date()))
            }
        }
    }

    /// After one of the window's own writes: `watch` is told the set followed as it now stands, then, where the run
    /// asks it to, looks at once, so the board it carries next has the write.
    private func lookNow(if isAsked: Bool) {
        refresh()
        if isAsked {
            following.lookNow()
        }
    }

    /// What the views show, at this moment, and what the window follows; then the next moment it changes by time alone
    /// is waited for.
    private func refresh() {
        let time = Date()

        run.settle(at: time)
        following.follow(run.follow())
        send()
        now = time
        sidebar = run.sidebar(at: time)
        page = run.page(at: time)
        pick = run.pick
        filter = run.filter
        keepFolds()
        schedule(after: time)
    }

    /// Lee's folds saved as they change, by a heading clicked, a pick made elsewhere unfolding its section, or the
    /// filter clearing on a pick made while it held text; those made while the filter holds text are never his, and
    /// "N earlier" open is never kept.
    private func keepFolds() {
        let kept = run.folds.kept

        if kept != savedFolds {
            savedFolds = kept
            saved.save(kept)
        }
    }

    private func schedule(after time: Date) {
        let next = [run.nextChange, run.isOpen ? time.addingTimeInterval(Self.tick) : nil].compactMap { $0 }.min()

        wake?.cancel()
        wake = next.map { next in
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSince(Date()))))
                if !Task.isCancelled {
                    self?.refresh()
                }
            }
        }
    }
}
