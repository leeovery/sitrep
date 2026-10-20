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
    /// The clock the pages are drawn at: ages, washes and an answer's wait.
    private(set) var now = Date()
    /// A wash or an answer's wait is under way: the views draw every frame until it ends.
    private(set) var isMoving = false
    /// SitRep's own Reduce motion, or the Mac's, followed as either changes.
    private(set) var reducesMotion = WindowModel.readReducesMotion()

    /// What the views' presses ask the model for.
    @ObservationIgnored private(set) var actions = WindowActions()
    @ObservationIgnored private let run: WindowRun
    @ObservationIgnored private let sitrep: SitRepCLI?
    @ObservationIgnored private let works: Works
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var wake: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    private static let lastSessionKey = "windowLastSession"
    /// How often the ages are drawn again while nothing else changes.
    private static let tick: TimeInterval = 30

    init(sitrep: SitRepCLI?, works: Works, defaults: UserDefaults = .standard) {
        self.sitrep = sitrep
        self.works = works
        self.defaults = defaults
        run = WindowRun(lastSession: defaults.string(forKey: Self.lastSessionKey))
        actions = WindowActions(
            pick: { [weak self] in self?.pick($0) },
            press: { [weak self] in self?.press($0, on: $1) },
            toggle: { [weak self] in self?.toggle($0) },
            jump: { [weak self] in self?.jump(to: $0) },
            askToFinish: { [weak self] in self?.askToFinish($0) },
            cancelFinish: { [weak self] in self?.cancelFinish($0) },
            confirmFinish: { [weak self] in self?.confirmFinish($0) },
            pointer: { [weak self] in self?.pointer(isIn: $0) }
        )
        listen()
    }

    /// A jump runs, from the window, the notch, the strip or the menu: the window's jumps wait.
    var isJumping: Bool { works.isJumping }

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

    func opened() {
        read(run.open())
        refresh()
    }

    func closed() {
        run.close()
        refresh()
    }

    /// Escape: the answer pressed last, still waiting, is taken back. Whether there was one.
    func undo() -> Bool {
        defer { refresh() }
        return run.undo()
    }

    private func pick(_ pick: Pick) {
        read(run.pick(pick))
        defaults.set(run.lastSession, forKey: Self.lastSessionKey)
        refresh()
    }

    private func press(_ button: Card.Button, on ask: AskAddress) {
        if let session = run.press(button, on: ask, at: Date()) {
            jump(to: session)
        }
        refresh()
    }

    private func toggle(_ ask: AskAddress) {
        run.toggle(ask)
        refresh()
    }

    private func pointer(isIn: Bool) {
        run.pointer(isIn: isIn, at: Date())
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
            let finished = await sitrep?.finish(session) ?? .refused(Plugin.unbuilt)

            run.finished(session, finished)
            refresh()
        }
    }

    /// To the session's window, as the notch's and the menu's jumps go: one at a time, none while one runs.
    private func jump(to session: String) {
        if !works.isJumping {
            works.jump(to: session)
        }
    }

    // MARK: Running what the run asks for

    private func read(_ reads: [Read]) {
        for read in reads {
            Task {
                let answer = await sitrep?.board(of: read.session) ?? .failed(Plugin.unbuilt)

                run.read(read, gave: answer, at: Date(), reducesMotion: reducesMotion)
                refresh()
            }
        }
    }

    /// The answers whose two seconds ran out, each to `sitrep answer`.
    private func send() {
        for (ask, answer) in run.due(at: Date()) {
            Task {
                let written = await sitrep?.answer(ask.ask, of: ask.session, with: answer) ?? .refused(Plugin.unbuilt)

                read(run.answered(ask, written))
                refresh()
            }
        }
    }

    /// What the views show, at this moment; then the next moment it changes by time alone is waited for.
    private func refresh() {
        let time = Date()

        run.settle(at: time)
        send()
        now = time
        listed = run.listed(at: time)
        page = run.page(at: time)
        pick = run.pick
        isMoving = run.isMoving(at: time)
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
