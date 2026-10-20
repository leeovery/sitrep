import AppKit
import SitRepEdge
import SitRepPanel

/// The strip on its display, in place of the notch when Lee chooses it: it runs the strip (`StripRun`), a frame per
/// display refresh with the pointer, the time and the board's rows in core's order as `watch` prints them, and draws
/// what each gives back. Frames run only while something moves: the strip, its marks and tabs, the ghost. A pointer
/// resting anywhere moves nothing; the mouse monitors wake the frames as it moves onto the strip or off it, or
/// anywhere while a tab is out, a press is held, or the strip has the pointer (`StripFrame.wakes`). While idle it costs
/// nothing, but for an open tab's time, drawn again as it changes. Whatever comes between frames, a board or Lee's
/// hand, goes to the run, which brings the strip up to now first; each is drawn, and frames show what it did. Its
/// window is click-through but over the strip and an open tab.
@MainActor
final class StripController: NSObject {
    /// A click on a mark or a tab: the session to jump to, and what to tell once the jump answers, whether it jumped.
    var onJump: (String, @escaping (Bool) -> Void) -> Void = { _, _ in }
    /// Whether a jump runs, from the strip, the menu or a banner.
    var isJumping: () -> Bool = { false }
    /// A drag let the strip go: the settings with its new place.
    var onMoved: (EdgeSettings) -> Void = { _ in }

    private var settings: EdgeSettings
    private var edge: ScreenEdge
    private let run: StripRun
    private let surface = StripSurface()
    private let window: EdgeWindow
    private var link: CADisplayLink?
    /// While frames are idle with a tab out, its time drawn again as it next changes.
    private var ages: Timer?
    /// A drag let go across the screen's middle: its settings, saved as the strip swaps edges.
    private var crossing: EdgeSettings?
    private let ghost = GhostEdge()
    private let caption = CaptionWindow()
    private var monitors: [Any] = []

    init(_ settings: EdgeSettings, on display: Display) {
        self.settings = settings
        edge = ScreenEdge(display, settings)
        run = StripRun(at: Displays.now, in: Self.setting(edge, settings), settings, measure: StripWordsLayer.measure)
        window = EdgeWindow(frame: edge.stripWindow, view: surface)
        super.init()

        surface.material = settings.material
        surface.pointer = EdgePointer(
            pressed: { [unowned self] in press(at: $0) },
            dragged: { [unowned self] in drag(to: $0) },
            released: { [unowned self] in release() },
            scrolled: { [unowned self] in scroll(by: $0) }
        )
        caption.over = edge.visible
        link = surface.displayLink(target: self, selector: #selector(tick))
        link?.isPaused = true
        link?.add(to: .main, forMode: .common)
        listen()
    }

    /// Whether the strip is on its display, Lee having chosen it and no full-screen app having the display: hidden, it
    /// draws nothing and hears nothing, a drag under way ends where it began, and nothing of it shows, its caption and
    /// its ghost included. Its time runs on meanwhile: shown again, it is where it would have got to.
    var isShown = false {
        didSet {
            guard isShown != oldValue else {
                return
            }

            caption.mayShow = isShown
            if isShown {
                run.catchUp(moment())
                window.orderFrontRegardless()
                wake()
            } else {
                endDrag()
                window.orderOut(nil)
                link?.isPaused = true
                ages?.invalidate()
            }
        }
    }

    /// The board as `watch` last printed it: its rows, in core's order, become the marks, each new needs you moving in
    /// at once with its ring flashing; while it is stale, the tabs say since when.
    func show(_ board: PanelBoard) {
        run.show(board, moment())
        took()
    }

    /// The settings and the display, as they stand: the edge and the place along it, the length and Max, the material
    /// and the motion, all at once.
    func apply(_ settings: EdgeSettings, on display: Display) {
        self.settings = settings
        edge = ScreenEdge(display, settings)
        window.setFrame(edge.stripWindow, display: true)
        surface.material = settings.material
        caption.over = edge.visible
        run.place(settings, moment())
        took()
    }

    /// Starts the frames again, with a frame at once, so what changed shows on this refresh.
    func wake() {
        guard isShown, link?.isPaused == true else {
            return
        }

        step(at: Displays.now)
    }

    /// Now, as the run takes an input: the time, the pointer, whether the strip shows, and what it runs in.
    private func moment(at time: Double = Displays.now, pointer: CGPoint? = nil) -> StripRun.Moment {
        StripRun.Moment(
            time: time, pointer: pointer ?? edge.stagePoint(NSEvent.mouseLocation), pointerAt: Displays.now,
            isShown: isShown, setting: Self.setting(edge, settings)
        )
    }

    private static func setting(_ edge: ScreenEdge, _ settings: EdgeSettings) -> StripRun.Setting {
        StripRun.Setting(stage: edge.stripStage, reducesMotion: Displays.reducesMotion(settings))
    }

    @objc private func tick(_ link: CADisplayLink) {
        step(at: link.targetTimestamp * 1000)
    }

    /// One frame: the strip moved on to this time with the pointer where it is, drawn, and the frames paced.
    private func step(at time: Double) {
        run.step(moment(at: time))
        draw()
    }

    /// An input the run has taken: while frames run, the next one draws it, with whatever the frames between showed
    /// (`StripRun.takeShown`); while they sleep, the frame it brought the strip up to is drawn, and frames start to
    /// show what it did.
    private func took() {
        if isShown, link?.isPaused == true {
            draw()
        }
        wake()
    }

    /// The run's latest frame drawn: the edge it swapped to saved, the caption told the spin is over, and the frames
    /// paced.
    private func draw() {
        let frame = run.frame, time = run.time, shown = run.takeShown()

        if shown.swappedEdge, let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        if let drained = shown.drained {
            caption.drained(at: drained)
        }
        surface.show(StripScene(
            frame: frame, hoverRow: run.hoverRow, note: run.note, now: Displays.wallNow, mirror: edge.stripMirror,
            menu: edge.stripStage.menu, reducesMotion: Displays.reducesMotion(settings)
        ))
        window.ignoresMouseEvents = !(frame.pointer.map(frame.hits) ?? false)
        pace(at: time)
    }

    /// Frames run while something moves; otherwise, with a tab out, a frame as its time next changes. Hidden, none.
    private func pace(at time: Double) {
        let ghosts = ghost.step(at: time)
        let running = isShown && (run.frame.isMoving || ghosts)

        link?.isPaused = !running
        ages?.invalidate()
        ages = nil
        if isShown, !running {
            agesChange()
        }
    }

    /// A frame as the time on a tab out next reads differently, menus tracking or not.
    private func agesChange() {
        let now = Displays.wallNow
        guard let next = run.nextAgeChange(after: now) else {
            return
        }

        let ages = Timer(timeInterval: (next - now) / 1000, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.wake() }
        }

        RunLoop.main.add(ages, forMode: .common)
        self.ages = ages
    }

    private func press(at screenPoint: CGPoint) {
        if let point = edge.stagePoint(screenPoint) {
            run.press(moment(pointer: point))
            took()
        }
    }

    /// A press moved: once it is a drag it carries the strip, its black showing on the other edge once the pointer is
    /// past the screen's middle.
    private func drag(to screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        run.moved(moment(pointer: point))
        if run.isDragging {
            ghost.carried(across: run.isAcross, outline: run.frame.strip, on: edge)
        }
        took()
    }

    /// The press let go where the pointer is: a click jumps, or opens a count's tab, but none while a jump runs, as
    /// the menu's works are disabled then; and once the jump has jumped, the caption says where. A drag leaves the
    /// strip where it took it, saved, and across the screen's middle saved as it swaps edges.
    private func release() {
        switch run.release(settings, mayJump: !isJumping(), moment()) {
        case let .jump(session, to: target, click: click):
            caption.jumping(to: session.project)
            onJump(target) { [weak self] in self?.answered(jumped: $0, click: click) }
        case let .dropped(dropped):
            ghost.dropped(across: dropped.isAcross)
            if dropped.isAcross {
                crossing = dropped.settings
            } else {
                onMoved(dropped.settings)
            }
        case nil:
            break
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

    /// The strip hidden mid-drag, its mouse-up perhaps never to come: the drag ends where it began, saving nothing,
    /// and the window lets clicks through again. Hidden as it crosses to the other edge, it is there at once.
    private func endDrag() {
        if let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        ghost.hide()
        if run.endDrag(moment()) {
            window.ignoresMouseEvents = true
        }
    }

    /// The wheel over an open count's tab scrolls its rows.
    private func scroll(by delta: Double) {
        run.scroll(by: delta, moment())
        took()
    }

    /// The pointer anywhere wakes the frames when a move of it may change what shows; a click in another app draws an
    /// open tab back. The global monitor hears what goes to other apps, the local one what comes to SitRep.
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

        if clickElsewhere {
            run.clickElsewhere(moment())
            took()
        } else if !window.ignoresMouseEvents || run.frame.wakes(pointer: edge.stagePoint(NSEvent.mouseLocation)) {
            wake()
        }
    }
}
