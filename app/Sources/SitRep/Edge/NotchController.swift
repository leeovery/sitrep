import AppKit
import SitRepEdge
import SitRepPanel

/// The notch on its display: it runs the notch (`NotchRun`), in the style Lee chose, a frame per display refresh with
/// the pointer, the time and the board's rows, and draws what each gives back. Frames run only while something moves:
/// the model, a row folding, the ghost, a new row's wash in glass. A pointer resting anywhere moves nothing; the mouse
/// monitors wake the frames as it moves near the notch, or anywhere while the panel is out (`Frame.wakes`). While
/// idle it costs nothing, but for the light, which breathes on a slow refresh of its own while something needs Lee
/// (under reduced motion it holds still, and the refresh runs only while a new ask brightens it), and the open
/// panel's times, drawn again as they change. Whatever comes between frames, a board or Lee's hand, goes to the run,
/// which brings the notch up to now first; each is drawn, and frames show what it did.
@MainActor
final class NotchController: NSObject, CalloutShape {
    /// A click on a row: the session to jump to, and what to tell once the jump answers, whether it jumped.
    var onJump: (String, @escaping (Bool) -> Void) -> Void = { _, _ in }
    /// A row's button, or its menu's Open in SitRep: the session to open in the SitRep window.
    var onOpen: (String) -> Void = { _ in }
    /// A row's menu's Snooze: the session, the asks its row showed, and the time chosen.
    var onSnooze: (String, [String], SnoozeChoice) -> Void = { _, _, _ in }
    /// A Snoozed row's menu's Wake now: the session, and the asks its row showed.
    var onWake: (String, [String]) -> Void = { _, _ in }
    /// Whether a jump runs, from the panel, the menu or a banner.
    var isJumping: () -> Bool = { false }
    /// A drag let the notch go: the settings with its new place.
    var onMoved: (EdgeMove) -> Void = { _ in }
    /// The pointer over the notch, or its panel, in a frame: told each frame it is.
    var onPointedAt: () -> Void = {}

    /// How long a your-turn row stays before it folds into "N earlier": the card refolds at once as it changes.
    var period: FoldPeriod {
        didSet {
            wake()
        }
    }

    private var settings: EdgeSettings
    private var edge: ScreenEdge
    private let run: NotchRun
    private let surface = NotchSurface()
    /// Its window: internal only for the tests, which read that it stays on the screen.
    let window: EdgeWindow
    private var link: CADisplayLink?
    private var lightLink: CADisplayLink?
    /// While frames are idle with the panel out, its times drawn again as they next change.
    private var ages: Timer?
    /// A drag let go across the screen's middle: its settings, saved as the notch swaps edges.
    private var crossing: EdgeMove?
    private let ghost = GhostEdge()
    private let caption = CaptionWindow()
    /// When a new row was last washed, on the run's clock.
    private var washed: Double?
    private var monitors: [Any] = []
    /// Where on the stage the row's menu AppKit was last handed was asked for, which holds the card open once it
    /// shows.
    private var menuAt: CGPoint?

    /// The slow refresh the light breathes on while frames are idle.
    private static let lightRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)

    init(_ settings: EdgeSettings, period: FoldPeriod, on display: Display, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.period = period
        edge = ScreenEdge(display, settings)
        run = NotchRun(at: Displays.now, in: .on(edge, settings, period: period), kept: SavedSettings(defaults))
        window = EdgeWindow.onScreen(frame: edge.window, view: surface)
        super.init()

        surface.material = settings.material
        surface.show(run.list)
        surface.pointer = EdgePointer(
            pressed: { [unowned self] in press(at: $0) },
            dragged: { [unowned self] in drag(to: $0) },
            released: { [unowned self] in release() },
            scrolled: { [unowned self] in scroll(by: $0) },
            menu: { [unowned self] in menu(at: $0) }
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
            window.isShown = isShown
            if isShown {
                run.catchUp(moment())
                wake()
            } else {
                endDrag()
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
        let washes = run.show(board, moment())

        if !washes.isEmpty {
            surface.wash(washes, at: run.time)
            washed = run.time
        }
        took()
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

    /// Now, as the run takes an input: the time, the pointer, whether the notch shows, and what it runs in.
    private func moment(at time: Double = Displays.now, pointer: CGPoint? = nil) -> NotchRun.Moment {
        NotchRun.Moment(
            time: time, pointer: pointer ?? edge.stagePoint(NSEvent.mouseLocation), pointerAt: Displays.now,
            isShown: isShown, setting: .on(edge, settings, period: period)
        )
    }

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
        let time = run.lightTime(link.targetTimestamp * 1000)

        drawLight(at: time)
        if !lightMoves(at: time) {
            link.isPaused = true
        }
    }

    /// One frame: the notch moved on to this time with the pointer where it is, drawn, and the clocks paced.
    private func step(at time: Double) {
        run.step(moment(at: time))
        draw()
    }

    /// An input the run has taken: while frames run, the next one draws it, with whatever the frames between showed
    /// (`NotchRun.takeShown`); while they sleep, the frame it brought the notch up to is drawn, and frames start to
    /// show what it did.
    private func took() {
        if isShown, link?.isPaused == true {
            draw()
        }
        wake()
    }

    /// The run's latest frame drawn: the edge it swapped to saved, the caption told the panel drained, and the clocks
    /// paced.
    private func draw() {
        let frame = run.frame, time = run.time, pointer = run.seen
        let setting = NotchRun.Setting.on(edge, settings, period: period), shown = run.takeShown()

        if shown.swappedEdge, let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        if let drained = shown.jumpDrained {
            caption.drained(at: drained)
        }
        surface.draw(run, in: setting, mirror: edge.mirror)

        let isPointedAt = pointer.map(frame.hits) ?? false

        window.takesClicks = run.drag != nil || isPointedAt
        if isPointedAt {
            onPointedAt()
        }
        pace(at: time)
    }

    /// The notch at rest at its home, from the edge to its front, on the screen, for what stands beside it: at the home
    /// the settings give, as the run may not have stepped there yet.
    var restingBand: CGRect {
        edge.homeBand(reaching: run.restingOutline(at: edge.stage.notchY).boundingBox.maxX)
    }

    private func drawLight(at time: Double) {
        surface.drawLight(run, at: time, reducesMotion: Displays.reducesMotion(settings))
    }

    /// Frames run while something moves; otherwise only the light's slow refresh, while it is lit and moves, and with
    /// the panel out, a frame as its times next change. Hidden, none.
    private func pace(at time: Double) {
        let ghosts = ghost.step(at: time)
        let running = isShown && (run.frame.isMoving || run.isFolding(at: time) || ghosts || isWashing(at: time))

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
        isShown && run.lightMoves(at: time, reducesMotion: Displays.reducesMotion(settings))
    }

    /// A new row's wash, which glass draws a frame at a time.
    private func isWashing(at time: Double) -> Bool {
        NotchSurface.drawn(settings.material) == .glass && washed.map { time - $0 < Wash.length } == true
    }

    /// A frame as the first of the open panel's times next reads differently, or a your-turn row folds into "N
    /// earlier", menus tracking or not.
    private func agesChange() {
        guard let wait = Self.wait(for: run, at: Displays.wallNow) else {
            return
        }

        let ages = Timer(timeInterval: wait, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.wake() }
        }

        RunLoop.main.add(ages, forMode: .common)
        self.ages = ages
    }

    /// How long, in seconds, from this time on the wall clock, ms, until the run's open panel next draws differently
    /// (`NotchRun.nextAgeChange`); nil with nothing to draw again.
    static func wait(for run: NotchRun, at now: Double) -> TimeInterval? {
        run.nextAgeChange(after: now).map { ($0 - now) / 1000 }
    }

    /// A press on a row's button opens its session in the SitRep window; on a row that jumps, presses it in and jumps
    /// to its session, and once the jump has jumped, the caption says where; on an eyebrow, its section folds or
    /// unfolds, kept; anywhere else on the black, it may become a drag (`NotchRun.press`).
    private func press(at screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        switch run.press(moment(pointer: point), mayJump: !isJumping()) {
        case let .open(session)?:
            onOpen(session)
        case let .jump(session, to: target, click: click)?:
            jump(from: session, to: target, click: click)
        case .fold?, .carry?, nil:
            break
        }
        took()
    }

    /// A row pressed in jumps to its session; the caption says where once the jump has jumped.
    private func jump(from session: Session, to target: String, click: Int) {
        caption.jumping(to: session.project)
        onJump(target) { [weak self] in self?.answered(jumped: $0, click: click) }
    }

    /// A right-click on a row, away or not: its menu (`RowMenu`), which holds the card open while it shows. What it
    /// snoozes or wakes is the asks the row showed.
    private func menu(at screenPoint: CGPoint) -> NSMenu? {
        guard let point = edge.stagePoint(screenPoint),
              let row = run.row(at: point, in: .on(edge, settings, period: period)), let session = row.session
        else {
            return nil
        }

        let id = session.id, asks = session.asks, key = row.key
        let menu = RowMenu.make(
            for: RowMenu.Row(session), at: Date(), in: run.calendar,
            RowMenu.Actions(
                open: { [unowned self] in onOpen(id) },
                jump: { [unowned self] in jumpFromMenu(to: key) },
                snooze: { [unowned self] in onSnooze(id, asks, $0) },
                wake: { [unowned self] in onWake(id, asks) }
            )
        )

        menuAt = point
        menu.delegate = self
        return menu
    }

    /// Jump to the window, as a click on the row would, the row the menu is for pressed in, while it still shows.
    private func jumpFromMenu(to row: String) {
        if case let .jump(session, to: target, click: click) = run.jump(to: row, moment(), mayJump: !isJumping()) {
            jump(from: session, to: target, click: click)
        }
        took()
    }

    /// The jump a click asked for answered; an answer to an earlier click changes nothing.
    private func answered(jumped: Bool, click: Int) {
        guard run.isLatest(click) else {
            return
        }

        run.jumpAnswered(moment())
        caption.answered(jumped: jumped, at: run.time)
        took()
    }

    /// A press moved: once it is a drag the panel closes, the notch lifts, and it follows the pointer along the edge,
    /// its ghost on the other edge once the pointer is past the screen's middle.
    private func drag(to screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        if let drag = run.moved(width: edge.frame.width, moment(pointer: point)), drag.isCarrying {
            ghost.carried(across: drag.isAcross, outline: run.restingOutline(at: run.notchY), on: edge)
        }
        took()
    }

    /// The press let go: a drag leaves the notch where it took it, saved; across the screen's middle, saved as it
    /// swaps edges.
    private func release() {
        if let dropped = run.release(settings, height: edge.frame.height, moment()) {
            ghost.dropped(across: dropped.isAcross)
            if dropped.isAcross {
                crossing = dropped.move
            } else {
                onMoved(dropped.move)
            }
        }
        took()
    }

    /// The notch hidden mid-drag, its mouse-up perhaps never to come: the drag ends where it began, saving nothing,
    /// and the window lets clicks through again. Hidden as it crosses to the other edge, it is there at once.
    private func endDrag() {
        if let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        ghost.hide()
        if run.endDrag(moment()) {
            window.takesClicks = false
        }
    }

    private func scroll(by delta: Double) {
        run.scroll(by: delta, moment())
        took()
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
            run.clickElsewhere(moment())
            took()
        } else if window.takesClicks
            || run.frame.wakes(from: run.seen, to: edge.stagePoint(NSEvent.mouseLocation), field: run.field)
        {
            wake()
        }
    }
}

extension NotchController: NSMenuDelegate {
    /// A row's menu showing holds the card open as if the pointer rested where it was opened (`NotchRun.menuOpened`).
    func menuWillOpen(_ menu: NSMenu) {
        if let menuAt {
            run.menuOpened(at: menuAt)
        }
    }

    /// Closed, before any choice on it runs: the card follows the pointer again, its grace starting from now.
    func menuDidClose(_ menu: NSMenu) {
        menuAt = nil
        run.menuClosed()
        took()
    }
}
