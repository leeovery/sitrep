import AppKit
import SitRepEdge
import SitRepPanel

/// The notch on its display: it runs the notch (`NotchRun`), in the style Lee chose, a frame per display refresh with
/// the pointer, the time and the board's rows, and draws what each gives back. Frames run only while something moves:
/// the model, a row folding, the ghost, a new row's wash in glass. A pointer resting anywhere moves nothing; the mouse
/// monitors wake the frames as it moves near the notch, or anywhere while the panel is out (`Frame.wakes`). While
/// idle it costs nothing, but for the light, which breathes on a slow refresh of its own while something needs Lee
/// (under reduced motion it holds still, and the refresh runs only while a new ask brightens it), and the open
/// panel's times, drawn again as they change. Whatever comes between frames, a board or Lee's hand, first brings the
/// notch up to now, so it takes its time from the clock, never from the last frame's, minutes old after an idle.
@MainActor
final class NotchController: NSObject {
    /// A click on a row: the session to jump to, and what to tell once the jump answers, whether it jumped.
    var onJump: (String, @escaping (Bool) -> Void) -> Void = { _, _ in }
    /// Whether a jump runs, from the panel, the menu or a banner.
    var isJumping: () -> Bool = { false }
    /// A drag let the notch go: the settings with its new place.
    var onMoved: (EdgeSettings) -> Void = { _ in }

    private var settings: EdgeSettings
    private var edge: ScreenEdge
    private let run: NotchRun
    private let surface = NotchSurface()
    private let window: EdgeWindow
    private var link: CADisplayLink?
    private var lightLink: CADisplayLink?
    /// While frames are idle with the panel out, its times drawn again as they next change.
    private var ages: Timer?
    private var drag: NotchDrag?
    /// A drag let go across the screen's middle: its settings, saved as the notch swaps edges.
    private var crossing: EdgeSettings?
    private let ghost = GhostEdge()
    private let caption = CaptionWindow()
    /// When a new row was last washed, on the run's clock.
    private var washed: Double?
    private var monitors: [Any] = []

    /// The slow refresh the light breathes on while frames are idle.
    private static let lightRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)

    init(_ settings: EdgeSettings, on display: Display) {
        self.settings = settings
        edge = ScreenEdge(display, settings)
        run = NotchRun(at: Displays.now, in: Self.setting(edge, settings))
        window = EdgeWindow(frame: edge.window, view: surface)
        super.init()

        surface.material = settings.material
        surface.show(run.list)
        surface.pointer = EdgePointer(
            pressed: { [unowned self] in press(at: $0) },
            dragged: { [unowned self] in drag(to: $0) },
            released: { [unowned self] in release() },
            scrolled: { [unowned self] in scroll(by: $0) }
        )
        caption.over = edge.visible
        link = startLink(#selector(tick))
        lightLink = startLink(#selector(tickLight), rate: Self.lightRate)
        listen()
    }

    /// Whether the notch is on its display, Lee having chosen it and no full-screen app having the display: hidden,
    /// it draws nothing and hears nothing, a drag under way ends where it began, and nothing of it shows, its caption
    /// and its ghost included. Its time runs on meanwhile: shown again, it is where it would have got to.
    var isShown = false {
        didSet {
            guard isShown != oldValue else {
                return
            }

            caption.mayShow = isShown
            if isShown {
                run.catchUp(to: Displays.now, in: setting)
                window.orderFrontRegardless()
                wake()
            } else {
                endDrag()
                window.orderOut(nil)
                link?.isPaused = true
                lightLink?.isPaused = true
                ages?.invalidate()
            }
        }
    }

    /// The board as `watch` last printed it. Its rows show at once while the panel is in, and keep their places while
    /// it is out; a row new on it swells the notch and, with the panel out, is washed; something needing Lee with
    /// nothing new, as on the first board, lights the notch with no swell.
    func show(_ board: PanelBoard) {
        advance()

        let washes = run.show(board, at: Displays.now, in: setting)

        surface.show(run.list)
        if !washes.isEmpty {
            surface.wash(washes, at: run.time)
            washed = run.time
        }
        wake()
    }

    /// The settings and the display, as they stand: the edge and the place along it, the material and the motion at
    /// once, the style once the notch is at rest.
    func apply(_ settings: EdgeSettings, on display: Display) {
        self.settings = settings
        edge = ScreenEdge(display, settings)
        window.setFrame(edge.window, display: true)
        surface.material = settings.material
        caption.over = edge.visible
        wake()
    }

    /// Starts the frames again, with a frame at once, so what changed shows on this refresh.
    func wake() {
        guard isShown, link?.isPaused == true else {
            return
        }

        step(at: Displays.now)
    }

    /// The notch brought up to now before a board or Lee's hand changes it: a frame now while frames sleep, its time
    /// run on while hidden. Running, the last frame is a refresh old at most.
    private func advance() {
        if !isShown {
            run.catchUp(to: Displays.now, in: setting)
        } else {
            wake()
        }
    }

    /// What the notch runs in now: the edge's stage, Lee's notch and the motion, which the Mac's setting may change.
    private var setting: NotchRun.Setting { Self.setting(edge, settings) }

    private static func setting(_ edge: ScreenEdge, _ settings: EdgeSettings) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: edge.stage, mirror: edge.mirror, style: settings.style,
            reducesMotion: Displays.reducesMotion(settings)
        )
    }

    private var pointer: CGPoint? { edge.stagePoint(NSEvent.mouseLocation) }

    private func startLink(_ selector: Selector, rate: CAFrameRateRange? = nil) -> CADisplayLink {
        let link = surface.displayLink(target: self, selector: selector)

        if let rate {
            link.preferredFrameRateRange = rate
        }
        link.isPaused = true
        link.add(to: .main, forMode: .common)

        return link
    }

    @objc private func tick(_ link: CADisplayLink) {
        step(at: link.targetTimestamp * 1000)
    }

    /// The light drawn a refresh on; once it no longer moves, as a brighten under reduced motion ends, drawn at rest
    /// and the refresh stopped.
    @objc private func tickLight(_ link: CADisplayLink) {
        let time = run.clock(link.targetTimestamp * 1000)

        drawLight(at: time)
        if !lightMoves(at: time) {
            link.isPaused = true
        }
    }

    /// One frame: the notch moved on to this time with the pointer where it is, drawn, and the clocks paced.
    private func step(at time: Double) {
        run.step(at: time, pointer: pointer, in: setting)
        draw()
    }

    /// The run's latest frame drawn: the edge it swapped to saved, the caption told the panel drained, and the clocks
    /// paced.
    private func draw() {
        let frame = run.frame, time = run.time, pointer = run.seen

        if frame.swapsEdge, let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        if run.notch.phase == .closing || run.notch.phase == .closed {
            caption.drained(at: time)
        }
        surface.show(run.list)
        surface.show(NotchScene(
            frame: frame, hover: pointer.flatMap { run.row(at: $0, in: setting) }, scroll: run.scroll, time: time,
            now: Displays.wallNow, mirror: edge.mirror
        ))
        drawLight(at: time)
        window.ignoresMouseEvents = drag == nil && !(pointer.map(frame.hits) ?? false)
        pace(at: time)
    }

    private func drawLight(at time: Double) {
        surface.showLight(run.frame.light, outline: run.frame.outline, colours: LiveLight(
            time: time, sinceAsk: run.sinceAsk(at: time), reducesMotion: Displays.reducesMotion(settings)
        ))
    }

    /// Frames run while something moves; otherwise only the light's slow refresh, while it is lit and moves, and with
    /// the panel out, a frame as its times next change. Hidden, none.
    private func pace(at time: Double) {
        let ghosts = ghost.step(at: time)
        let running = isShown && (run.frame.isMoving || run.folds(at: time) || ghosts || isWashing(at: time))

        link?.isPaused = !running
        lightLink?.isPaused = running || !lightMoves(at: time)
        ages?.invalidate()
        ages = nil
        if isShown, !running, run.frame.panel != nil {
            agesChange()
        }
    }

    /// Whether the light, shown and lit, changes from moment to moment (`LiveLight.moves`).
    private func lightMoves(at time: Double) -> Bool {
        isShown && run.frame.light.level > 0.001
            && LiveLight.moves(sinceAsk: run.sinceAsk(at: time), reducesMotion: Displays.reducesMotion(settings))
    }

    /// A new row's wash, which glass draws a frame at a time.
    private func isWashing(at time: Double) -> Bool {
        NotchSurface.drawn(settings.material) == .glass && washed.map { time - $0 < Wash.length } == true
    }

    /// A frame as the first of the open panel's times next reads differently, menus tracking or not.
    private func agesChange() {
        let now = Displays.wallNow
        guard let next = run.rows.shown.map({ $0.ageChanges(after: now) }).min() else {
            return
        }

        let ages = Timer(timeInterval: (next - now) / 1000, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.wake() }
        }

        RunLoop.main.add(ages, forMode: .common)
        self.ages = ages
    }

    /// Lee's action on the model, once it is up to now, then frames to show it.
    private func act(_ action: (any Notch) -> Void) {
        advance()
        action(run.notch)
        wake()
    }

    /// A press on a row that jumps presses it in and jumps to its session, and once the jump has jumped, the caption
    /// says where; anywhere else on the black, it may become a drag (`NotchRun.press`).
    private func press(at screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        let pressed = run.press(at: point, time: Displays.now, in: setting, mayJump: !isJumping())

        draw()
        switch pressed {
        case let .jump(session, to: target, click: click):
            caption.jumping(to: session.project)
            wake()
            onJump(target) { [weak self] in self?.answered(jumped: $0, click: click) }
        case .carry:
            drag = NotchDrag(at: point, home: run.notch.notchY)
        case nil:
            break
        }
    }

    /// The jump a click asked for answered; an answer to an earlier click changes nothing.
    private func answered(jumped: Bool, click: Int) {
        guard run.isLatest(click) else {
            return
        }

        caption.answered(jumped: jumped, at: run.clock(Displays.now))
        act { $0.jumpAnswered() }
    }

    /// A press moved: once it is a drag the panel closes, the notch lifts, and it follows the pointer along the edge,
    /// its ghost on the other edge once the pointer is past the screen's middle.
    private func drag(to screenPoint: CGPoint) {
        advance()
        guard var drag, let point = edge.stagePoint(screenPoint) else {
            return
        }

        let notch = run.notch

        if drag.move(to: point, width: edge.frame.width) {
            notch.carry()
            drag.carries(from: notch.notchY)
        }
        self.drag = drag
        if drag.isCarrying {
            notch.carried(to: drag.notchY)
            ghost.carried(across: drag.isAcross, outline: notch.restingOutline(at: notch.notchY), on: edge)
        }
        wake()
    }

    /// The press let go: a drag leaves the notch where it took it, saved; across the screen's middle, saved as it
    /// swaps edges.
    private func release() {
        defer { drag = nil }

        advance()
        guard let drag, drag.isCarrying else {
            return
        }

        let moved = drag.dropped(settings, at: run.notch.notchY, height: edge.frame.height)

        run.notch.drop(across: drag.isAcross)
        ghost.dropped(across: drag.isAcross)
        if drag.isAcross {
            crossing = moved
        } else {
            onMoved(moved)
        }
        wake()
    }

    /// The notch hidden mid-drag, its mouse-up perhaps never to come: the drag ends where it began, saving nothing,
    /// and the window lets clicks through again. Hidden as it crosses to the other edge, it is there at once.
    private func endDrag() {
        if let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        ghost.hide()
        guard let drag else {
            return
        }

        self.drag = nil
        if drag.isCarrying {
            run.notch.carried(to: edge.stage.notchY)
            run.notch.drop(across: false)
        }
        window.ignoresMouseEvents = true
    }

    private func scroll(by delta: Double) {
        advance()
        run.scroll(by: delta)
        wake()
    }

    /// The pointer anywhere wakes the frames when a move of it may change what shows; a click in another app closes
    /// the panel. The global monitor hears what goes to other apps, the local one what comes to SitRep.
    private func listen() {
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let downs: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        let global = NSEvent.addGlobalMonitorForEvents(matching: moves.union(downs)) { [weak self] event in
            let isClick = downs.contains(NSEvent.EventTypeMask(type: event.type))

            MainActor.assumeIsolated { self?.heard(clickElsewhere: isClick) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: moves) { [weak self] event in
            MainActor.assumeIsolated { self?.heard(clickElsewhere: false) }

            return event
        }

        monitors = [global, local].compactMap { $0 }
    }

    private func heard(clickElsewhere: Bool) {
        guard isShown else {
            return
        }

        if clickElsewhere, run.isOut {
            act { $0.clickElsewhere() }
        } else if !window.ignoresMouseEvents
            || run.frame.wakes(from: run.seen, to: pointer, field: run.notch.field)
        {
            wake()
        }
    }
}
