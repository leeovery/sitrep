import AppKit
import Observation
import SitRepCore
import SitRepEdge
import SitRepWindow

/// The SitRep window's run, as the views see it: what it lists and shows, kept current as the board, the clock and
/// Lee's presses change it. It runs what the run asks for, each off the main thread: a session's board, an answer,
/// a finish; and a jump, through the app's `Works`, one at a time.
@MainActor
@Observable
final class WindowModel {
    private(set) var listed = Listed()
    private(set) var page = Page.empty("Looking for sessions…")
    private(set) var pick: Pick?
    /// The sidebar's view, saved as Lee chooses it.
    private(set) var sidebar = Sidebar.projects
    /// What the Filter field holds, never saved.
    private(set) var filter = Filter()
    /// The clock the pages are drawn at: ages, washes and an answer's wait.
    private(set) var now = Date()
    /// SitRep's own Reduce motion, or the Mac's, followed as either changes.
    private(set) var reducesMotion = WindowModel.readReducesMotion()
    /// The window's jump under way, which only the button pressed shows.
    private(set) var jumping = Jumping()

    /// What the views' presses ask the model for.
    @ObservationIgnored private(set) var actions = WindowActions()
    @ObservationIgnored private let run: WindowRun
    @ObservationIgnored private let plugin: Plugin
    @ObservationIgnored private let works: Works
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let saved: SavedSettings<WindowSettings>
    @ObservationIgnored private var wake: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    private static let lastSessionKey = "windowLastSession"
    /// How often the ages are drawn again while nothing else changes.
    private static let tick: TimeInterval = 30

    init(plugin: Plugin, works: Works, defaults: UserDefaults = .standard) {
        self.plugin = plugin
        self.works = works
        self.defaults = defaults
        let saved = SavedSettings<WindowSettings>(defaults)

        self.saved = saved
        run = WindowRun(lastSession: defaults.string(forKey: Self.lastSessionKey), sidebar: saved.read().sidebar)
        sidebar = run.sidebar
        actions = WindowActions(
            pick: { [weak self] in self?.pick($0) },
            pickInList: { [weak self] in self?.pickInList($0) },
            press: { [weak self] in self?.press($0, on: $1) },
            toggle: { [weak self] in self?.toggle($0) },
            toggleItem: { [weak self] in self?.toggle($0) },
            jump: { [weak self] in self?.jump($0) },
            askToFinish: { [weak self] in self?.askToFinish($0) },
            cancelFinish: { [weak self] in self?.cancelFinish($0) },
            confirmFinish: { [weak self] in self?.confirmFinish($0) },
            pointer: { [weak self] in self?.pointer(isIn: $0) },
            choose: { [weak self] in self?.choose($0) },
            filter: { [weak self] in self?.filter($0) },
            openFirstMatch: { [weak self] in self?.openFirstMatch() }
        )
        listen()
    }

    private static func readReducesMotion() -> Bool {
        Displays.reducesMotion(SavedEdgeSettings().read())
    }

    /// SitRep's setting saved, or the Mac's changing, shows at once, as the edge follows the Mac's.
    private func listen() {
        let follow: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reducesMotion = Self.readReducesMotion()
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
        read(run.show(last, at: Date(), reducesMotion: reducesMotion))
        refresh()
    }

    func unrun(_ why: String) {
        run.unrun(why)
        refresh()
    }

    /// The window opens, on the pick given, else on what it opens on.
    func opened(on pick: Pick? = nil) {
        read(run.open(on: pick))
        refresh()
    }

    func closed() {
        run.close()
        refresh()
    }

    func minimised() {
        run.minimise()
        refresh()
    }

    func restored() {
        read(run.restore())
        refresh()
    }

    /// Escape: the answer pressed last, still waiting, is taken back. Whether there was one.
    func undo() -> Bool {
        defer { refresh() }
        return run.undo()
    }

    func pick(_ pick: Pick) {
        picked(run.pick(pick))
    }

    private func pickInList(_ pick: Pick) {
        picked(run.pickInList(pick, at: Date()))
    }

    /// A pick's reads run, and the session picked kept as the one the window opens on.
    private func picked(_ reads: [Read]) {
        read(reads)
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

    private func choose(_ sidebar: Sidebar) {
        run.sidebar = sidebar
        saved.save(sidebar)
        refresh()
    }

    private func filter(_ text: String) {
        run.filter = Filter(text)
        refresh()
    }

    private func openFirstMatch() {
        picked(run.openFirstMatch())
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

            run.finished(session, finished)
            refresh()
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

    private func read(_ reads: [Read]) {
        for read in reads {
            Task {
                let answer = await plugin.ask({ await $0.board(of: read.session) }, unrun: BoardAnswer.failed)

                run.read(read, gave: answer, at: Date(), reducesMotion: reducesMotion)
                refresh()
            }
        }
    }

    /// The answers whose two seconds ran out, each to `sitrep answer`.
    private func send() {
        for (ask, answer) in run.due(at: Date()) {
            Task {
                let written = await plugin.ask({ await $0.answer(ask.ask, of: ask.session, with: answer) }, unrun: WriteAnswer.refused)

                read(run.answered(ask, written))
                refresh()
            }
        }
    }

    /// What the views show, at this moment; then the next moment it changes by time alone is waited for.
    private func refresh() {
        let time = Date()

        run.settle(at: time)
        read(run.settledReads(at: time))
        send()
        now = time
        listed = run.listed(at: time)
        page = run.page(at: time)
        pick = run.pick
        sidebar = run.sidebar
        filter = run.filter
        schedule(after: time)
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
