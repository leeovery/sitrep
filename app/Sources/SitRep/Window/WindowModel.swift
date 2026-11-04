import AppKit
import Observation
import SitRepCore
import SitRepEdge
import enum SitRepPanel.FoldPeriod
import enum SitRepPanel.SnoozeChoice
import SitRepWindow

/// The SitRep window's run, as the views see it: what it lists and shows, kept current as the board, the clock and
/// Lee's presses change it, and where it is, kept as where it was left as that changes. It runs what the run asks
/// for: the sessions it follows, and a look now, told to the app's one `watch`; and off the main thread an answer, a
/// finish; a snooze or a wake, through the app's `Snoozes`; a jump, through the app's `Works`, one at a time; and
/// `sitrep screen`, on its own cadence while the window shows.
@MainActor
@Observable
final class WindowModel {
    private(set) var places = Places(Listed())
    /// The list beside the page; none for a project's page or a session's, which fill the window.
    private(set) var list: PlaceList? = PlaceList()
    /// How the board stands, for the list's place where it lists nothing.
    private(set) var head = Listed().head
    private(set) var page = Page.empty("Looking for sessions…")
    /// Where the window is: what the sidebar shows picked, and what the list has.
    private(set) var location = Location.place(.needsYou)
    /// The page fills the window, with no list beside it: the content list folds away.
    private(set) var isFullPage = false
    /// A list shows beside the page with rows in it, not folded away nor emptied to its one line: what the window's
    /// focus follows.
    private(set) var showsRows = true
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
    /// Told, as each change is taken, whether the page fills the window, so the list folds away or shows with the
    /// change and not a moment after it; and whether a session opened from outside before any board has just landed,
    /// on the board come, which puts focus on the list.
    @ObservationIgnored var arrange: (_ isFullPage: Bool, _ landed: Bool) -> Void = { _, _ in }
    @ObservationIgnored private var landedLater = 0
    @ObservationIgnored private let run: WindowRun
    /// The calendar the window's wake times are worded on, its run's.
    var calendar: Calendar { run.calendar }
    @ObservationIgnored private let plugin: Plugin
    @ObservationIgnored private let works: Works
    @ObservationIgnored private let snoozes: Snoozes
    @ObservationIgnored private let following: Following
    @ObservationIgnored private let defaults: UserDefaults
    /// Where the window was left, as last saved, which is saved again as it changes.
    @ObservationIgnored private var left: Location?
    @ObservationIgnored private var wake: Task<Void, Never>?
    /// The wait for the next look at the screen.
    @ObservationIgnored private var screenWake: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

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
        left = WhereLeft.read(defaults)
        run = WindowRun(remembered: left, period: period)
        actions = makeActions()
        listen()
    }

    private func makeActions() -> WindowActions {
        WindowActions(
            click: { [weak self] in self?.click($0) },
            pickInList: { [weak self] in self?.pickInList($0) ?? false },
            step: { [weak self] in self?.step(down: $0) },
            toggleFold: { [weak self] in self?.toggleFold(of: $0) },
            back: { [weak self] in self?.goBack() },
            forward: { [weak self] in self?.goForward() },
            openSession: { [weak self] in self?.openSession($0) },
            openProject: { [weak self] in self?.go(to: .project($0), by: .breadcrumb) },
            openParked: { [weak self] in self?.openParked($0) },
            backToSession: { [weak self] in self?.go(to: .session($0, from: .place(.parked)), by: .backToSession) },
            press: { [weak self] in self?.press($0, on: $1) },
            toggle: { [weak self] in self?.toggle($0) },
            toggleItem: { [weak self] in self?.toggle($0) },
            jump: { [weak self] in self?.jump($0) },
            snooze: { [weak self] in self?.snooze($0, $1) },
            wake: { [weak self] in self?.wake($0) },
            snoozeLine: { [weak self] in self?.snoozes.snoozeRow($0.asks, of: $0.session.id, $1) },
            wakeLine: { [weak self] in self?.snoozes.wakeRow($0.asks, of: $0.session.id) },
            askToFinish: { [weak self] in self?.askToFinish($0) },
            cancelFinish: { [weak self] in self?.cancelFinish($0) },
            confirmFinish: { [weak self] in self?.confirmFinish($0) },
            pointer: { [weak self] in self?.pointer(over: $0, isIn: $1) },
            pointerOverPage: { [weak self] in self?.pointer(overPage: $0, from: $1) },
            filter: { [weak self] in self?.narrow(to: $0) },
            openFirstMatch: { [weak self] in self?.openFirstMatch() }
        )
    }

    private static func readReducesMotion(_ defaults: UserDefaults) -> Bool {
        Displays.reducesMotion(SavedEdgeSettings(defaults).read())
    }

    /// SitRep's setting saved, or the Mac's changing, shows at once, as the edge follows the Mac's.
    private func listen() {
        let follow: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }

                let reduces = Self.readReducesMotion(self.defaults)

                if reduces != self.reducesMotion {
                    self.reducesMotion = reduces
                }
            }
        }

        // a change of any default comes here, the window's own place saved as it moves among them, so only a change
        // of the setting is taken
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

    /// The window opens afresh, where `WindowRun.open(landing:)` says, onto a session opened from outside where given.
    func opened(landing session: String? = nil) {
        run.open(landing: session)
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

    /// "Open in SitRep" on a session, from the card or the menu.
    func land(_ session: String) {
        run.land(session)
        refresh()
    }

    /// Escape: the answer pressed last, still waiting, is taken back. Whether there was one.
    func undo() -> Bool {
        defer { refresh() }
        return run.undo()
    }

    private func click(_ root: Root) {
        run.click(root)
        refresh()
    }

    private func pickInList(_ pick: ListPick) -> Bool {
        defer { refresh() }
        return run.pickInList(pick, at: Date())
    }

    private func step(down: Bool) {
        run.step(down: down, at: Date())
        refresh()
    }

    private func toggleFold(of place: Place) {
        run.toggleFold(of: place)
        refresh()
    }

    private func goBack() {
        run.goBack()
        refresh()
    }

    private func goForward() {
        run.goForward()
        refresh()
    }

    private func go(to location: Location, by way: History.Way) {
        run.go(to: location, by: way)
        refresh()
    }

    /// A session's row on a project's page: its page, pushed from what the sidebar shows picked, the project.
    private func openSession(_ session: String) {
        go(to: .session(session, from: run.location.root), by: .projectSession)
    }

    /// Parked, narrowed to a session, from its "later · N parked", or a project, from its "N parked".
    private func openParked(_ scope: ParkedScope) {
        let way: History.Way = switch scope {
        case .session: .sessionParked
        case .project: .projectParked
        case .all: .sidebar
        }

        go(to: .place(.parked, scope: scope), by: way)
    }

    /// Lee set how long a your-turn row stays before it folds into "N earlier": the list refolds at once.
    func period(_ period: FoldPeriod) {
        run.period = period
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

    private func pointer(over column: HeldLists.Column, isIn: Bool) {
        run.pointer(over: column, isIn: isIn, at: Date())
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

    private func narrow(to text: String) {
        run.filter = Filter(text)
        refresh()
    }

    private func openFirstMatch() {
        run.openFirstMatch()
        refresh()
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
    private func snooze(_ ask: AskAddress, _ choice: SnoozeChoice) {
        run.snoozing(ask)
        refresh()
        Task {
            let written = await snoozes.snooze([ask.ask], of: ask.session, choice)

            lookNow(if: run.snoozed(ask, written))
        }
    }

    /// A card's Wake now: the ask woken, its card saying any refusal.
    private func wake(_ ask: AskAddress) {
        run.snoozing(ask)
        refresh()
        Task {
            let written = await snoozes.wake([ask.ask], of: ask.session)

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

    /// What the views show, at this moment, and what the window follows; where it is, kept as where it was left; then
    /// the next moment it changes by time alone is waited for.
    private func refresh() {
        let time = Date()

        run.settle(at: time)
        following.follow(run.follow())
        send()
        now = time
        places = run.places
        list = run.list(at: time)
        head = run.head
        page = run.page(at: time)
        location = run.location
        filter = run.filter
        if isFullPage != (list == nil) {
            isFullPage = list == nil
        }
        if showsRows != (list.map { !$0.isEmpty } ?? false) {
            showsRows.toggle()
        }
        arrange(isFullPage, run.landedLater != landedLater)
        landedLater = run.landedLater
        keepWhereLeft()
        schedule(after: time)
    }

    /// Where the window is, saved as it changes, as where it was left.
    private func keepWhereLeft() {
        if location != left {
            left = location
            WhereLeft.save(location, in: defaults)
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
