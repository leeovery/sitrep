import AppKit
import SitRepCore
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
    var onJump: (String, @escaping (JumpAnswer) -> Void) -> Void = { _, _ in }
    /// A row's menu's Snooze: the session, the asks its row showed, and the time chosen, or until it moves.
    var onSnooze: (String, [String], Date?) -> Void = { _, _, _ in }
    /// Snooze's choices as Lee set them, read as a row's menu opens.
    private let snoozeSettings: () -> SnoozeSettings
    /// A Snoozed row's menu's Wake now: the session.
    var onWake: (String) -> Void = { _ in }
    /// An answer's row, or Ignore, on the asks panel: the answer to hold; and the sending line's Undo.
    var onAnswer: (Answering) -> Void = { _ in }
    var onUndo: () -> Void = {}
    /// A drag let the notch go: the settings with its new place.
    var onMoved: (EdgeMove) -> Void = { _ in }
    /// Each frame drawn, with whether the pointer is over the notch, or its panel.
    var onDrawn: ((_ isPointedAt: Bool) -> Void)?

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
    /// Whether the window is wide, for the asks panel open beside the panel (`ScreenEdge.window(wide:)`).
    private var isWide = false

    /// The slow refresh the light breathes on while frames are idle.
    private static let lightRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)

    /// On its display, its card's sections folded as `folding` has them, the strip's setting as well, each row's
    /// Snooze offering what `snoozeSettings` gives as its menu opens.
    init(
        _ settings: EdgeSettings, on display: Display, folding: Folding,
        snoozeSettings: @escaping () -> SnoozeSettings
    ) {
        self.settings = settings
        self.snoozeSettings = snoozeSettings
        edge = ScreenEdge(display, settings)
        run = NotchRun(at: Displays.now, in: .on(edge, settings), folding: folding, measure: AsksMeasure.drawn)
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
        window.setFrame(edge.window(wide: isWide), display: true)
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
            isShown: isShown, setting: .on(edge, settings)
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

    /// The run's latest frame drawn, in the window widened for the asks panel while it is open: the edge it swapped to
    /// saved, the caption told the panel drained, and the clocks paced.
    private func draw() {
        let time = run.time, pointer = run.seen
        let setting = NotchRun.Setting.on(edge, settings), shown = run.takeShown()

        if shown.swappedEdge, let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        if let drained = shown.jumpDrained {
            caption.drained(at: drained)
        }
        widen(run.asksShown(in: setting) != nil)
        surface.draw(run, in: setting, mirror: edge.mirror(wide: isWide))

        let isPointedAt = pointer.map { run.hits($0, in: setting) } ?? false

        window.takesClicks = run.drag != nil || isPointedAt
        onDrawn?(isPointedAt)
        pace(at: time)
    }

    /// The window wide while the asks panel is open beside the panel, and back to the panel's once it closes: on the
    /// right edge it grows into the screen, its stage mirrored across its new width.
    private func widen(_ wide: Bool) {
        guard wide != isWide else {
            return
        }

        isWide = wide
        window.setFrame(edge.window(wide: wide), display: false)
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

    /// A frame as the first of the open panel's times next reads differently, menus tracking or not.
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

    /// A press on a row that jumps presses it in and jumps to its session, in place of any jump under way, and once the
    /// jump has jumped, the caption says where; on an eyebrow, its section folds or unfolds, kept; on the asks panel,
    /// an answer is held or taken back, or its Snooze offers the row's; anywhere else on the black, it may become a
    /// drag (`NotchRun.press`).
    private func press(at screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        switch run.press(moment(pointer: point)) {
        case let .jump(session, to: target, click: click)?:
            jump(from: session, to: target, click: click)
        case let .answer(answering)?:
            onAnswer(answering)
        case .undo?:
            onUndo()
        case let .snooze(session, at: pressed)?:
            snooze(session, pressed: pressed)
        case .fold?, .carry?, .asks?, nil:
            break
        }
        took()
    }

    /// The asks panel's Snooze ▾: the Snooze choices of its row's menu, under the button, the card held open as the
    /// row's menu holds it while it shows. A choice snoozes the session, naming the asks its row showed, and closes the
    /// asks panel.
    private func snooze(_ session: Session, pressed: CGPoint) {
        let setting = NotchRun.Setting.on(edge, settings)

        guard let asks = run.asksShown(in: setting) else {
            return
        }

        let drawn = asks.frame.applying(edge.mirror(wide: isWide)), button = asks.layout.snooze
        let id = session.id, showing = RowMenu.Row(session).asks ?? []
        let menu = SnoozeMenu(offering: snoozeSettings(), at: Date(), in: run.calendar) { [unowned self] until in
            onSnooze(id, showing, until)
            run.closeAsks(moment())
        }

        run.menuOpened(at: pressed)
        menu.popUp(
            positioning: nil, at: CGPoint(x: drawn.minX + button.minX, y: drawn.minY + button.maxY), in: surface
        )
        run.menuClosed()
    }

    /// An answer's news, as the answers tell it: the asks panel shows it sending, as it was, or at the session's next
    /// ask.
    func heard(_ news: AnswerNews) {
        run.heard(news, moment())
        took()
    }

    /// A row pressed in jumps to its session; the caption says where once the jump has jumped.
    private func jump(from session: Session, to target: String, click: Int) {
        caption.jumping(to: session.project)
        onJump(target) { [weak self] in self?.answered($0, click: click) }
    }

    /// A right-click on a row, away or not: its menu (`RowMenu`), which holds the card open while it shows. It snoozes
    /// or wakes the row's session, a snooze naming the asks the row showed.
    private func menu(at screenPoint: CGPoint) -> NSMenu? {
        guard let point = edge.stagePoint(screenPoint),
              let row = run.row(at: point, in: .on(edge, settings)), let session = row.session
        else {
            return nil
        }

        let menu = menu(for: session, row: row.key)

        menuAt = point
        menu.delegate = self
        return menu
    }

    /// The menu of the row `key` showing `session`, opened now. Internal only for the tests, which open it.
    func menu(for session: Session, row key: String) -> NSMenu {
        let id = session.id

        return RowMenu.make(
            for: RowMenu.Row(session), at: Date(), in: run.calendar, offering: snoozeSettings(),
            RowMenu.Actions(
                jump: { [unowned self] in jumpFromMenu(to: key) },
                snooze: { [unowned self] in onSnooze(id, $0, $1) },
                wake: { [unowned self] in onWake(id) }
            )
        )
    }

    /// Jump to the window, as a click on the row would, the row the menu is for pressed in, while it still shows.
    private func jumpFromMenu(to row: String) {
        if case let .jump(session, to: target, click: click) = run.jump(to: row, moment()) {
            jump(from: session, to: target, click: click)
        }
        took()
    }

    /// A jump's news, whichever surface asked for it, for the caption.
    func heard(_ news: JumpNews) {
        caption.heard(news)
    }

    /// The jump a click asked for answered; an answer to an earlier click changes nothing.
    private func answered(_ answer: JumpAnswer, click: Int) {
        guard run.isLatest(click) else {
            return
        }

        run.jumpAnswered(moment())
        caption.answered(answer, at: run.time)
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
