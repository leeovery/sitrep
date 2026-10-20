import AppKit
import SitRepEdge
import SitRepPanel

/// The notch on its display: it owns the notch, in the style Lee chose, feeds it a frame per display refresh with the
/// pointer, the time and the board's rows, and draws what each gives back. Frames run only while something moves: the
/// model, a row folding, the ghost, a new row's wash in glass. A pointer resting anywhere moves nothing; the mouse
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
    private var notch: any Notch
    private var style: NotchStyle
    private var board = PanelBoard()
    private var rows = HeldRows()
    private var folds = Folds()
    /// The panel's list as the model and the drawing have it.
    private var list: PanelList
    private let surface = NotchSurface()
    private let window: EdgeWindow
    private var frame: Frame
    /// The display's clock at the last frame, ms.
    private var time: Double
    /// The pointer on the stage as the last frame saw it.
    private var seen: CGPoint?
    private var asks = AskClock()
    private var link: CADisplayLink?
    private var lightLink: CADisplayLink?
    /// While frames are idle with the panel out, its times drawn again as they next change.
    private var ages: Timer?
    private var scroll = 0.0
    private var drag: NotchDrag?
    /// A drag let go across the screen's middle: its settings, saved as the notch swaps edges.
    private var crossing: EdgeSettings?
    private let ghost = GhostEdge()
    private let caption = CaptionWindow()
    /// How many rows' clicks have asked for a jump: the latest's answer is the one heard.
    private var clicks = 0
    /// When a new row was last washed, on the display's clock.
    private var washed: Double?
    private var monitors: [Any] = []

    /// The slow refresh the light breathes on while frames are idle.
    private static let lightRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)

    init(_ settings: EdgeSettings, on display: Display) {
        self.settings = settings
        edge = ScreenEdge(display, settings)
        style = settings.style
        list = PanelList(head: board.head, content: Content(laying: []))
        time = Displays.now

        let input = Self.input(at: time, pointer: nil, needsLee: false, edge, list, settings)

        notch = settings.style.notch(input)
        frame = notch.frame(input)
        window = EdgeWindow(frame: edge.window, view: surface)
        super.init()

        surface.material = settings.material
        surface.show(list)
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
                catchUp(to: Displays.now)
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
        board.tell(notch, after: self.board)
        self.board = board
        rows.take(board.sessions)

        let now = Displays.now

        relist(at: now)
        if isOut, !board.new.isEmpty {
            surface.wash(board.new, at: now)
            washed = now
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
            catchUp(to: Displays.now)
        } else {
            wake()
        }
    }

    private var isOut: Bool { notch.phase == .open || notch.phase == .opening }

    private static func input(
        at time: Double, pointer: CGPoint?, needsLee: Bool, _ edge: ScreenEdge, _ list: PanelList,
        _ settings: EdgeSettings
    ) -> Input {
        Input(
            time: time, pointer: pointer, needsLee: needsLee, stage: edge.stage, content: list.content,
            reducesMotion: Displays.reducesMotion(settings)
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
        let time = link.targetTimestamp * 1000

        drawLight(at: time)
        if !lightMoves(at: time) {
            link.isPaused = true
        }
    }

    /// One frame: the model moved on to this time with the pointer where it is, drawn, and the clocks paced.
    private func step(at time: Double) {
        let pointer = edge.stagePoint(NSEvent.mouseLocation)

        fold(at: time)

        let input = Self.input(at: time, pointer: pointer, needsLee: board.needsLee, edge, list, settings)

        frame = notch.frame(input)
        self.time = time
        seen = pointer
        if rows.hold(notch.phase != .closed) {
            relist(at: time)
        }
        restyle(input)
        if frame.swapsEdge, let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        if notch.phase == .closing || notch.phase == .closed {
            caption.drained(at: time)
        }
        scroll = frame.panel.map { list.content.scrolled(scroll, by: 0, showing: $0.frame.height) } ?? 0
        asks.take(lastAsk: frame.light.lastAsk, simTime: frame.time, at: time)
        surface.show(NotchScene(
            frame: frame, hover: pointer.flatMap(row), scroll: scroll, time: time, now: Displays.wallNow,
            mirror: edge.mirror
        ))
        drawLight(at: time)
        window.ignoresMouseEvents = drag == nil && !(pointer.map(frame.hits) ?? false)
        pace(at: time)
    }

    /// Hidden, the notch's time ran on: it is taken on to now (`Notch.runOn`), and the frame after shows it.
    private func catchUp(to now: Double) {
        frame = notch.runOn(from: time, to: now) { [board, edge, list, settings] in
            Self.input(at: $0, pointer: nil, needsLee: board.needsLee, edge, list, settings)
        }
        time = now
    }

    /// The rows as they show now, folding in and out while the panel is out, to the model's next frame and the
    /// drawing.
    private func relist(at time: Double) {
        folds.take(Item.list(rows.shown), at: time, animating: isOut, reducesMotion: Displays.reducesMotion(settings))
        list.head = board.head
        fold(at: time)
    }

    /// The list as it folds at this time.
    private func fold(at time: Double) {
        list.content = folds.content(at: time)
        surface.show(list)
    }

    /// Lee chose the other notch: an open panel closes first, and the notch changes once it is at rest.
    private func restyle(_ input: Input) {
        guard settings.style != style else {
            return
        }

        if isOut {
            notch.clickElsewhere()
        } else if notch.phase == .closed, !frame.isMoving {
            style = settings.style
            notch = style.notch(input)
            frame = notch.frame(input)
        }
    }

    private func drawLight(at time: Double) {
        surface.showLight(frame.light, outline: frame.outline, colours: LiveLight(
            time: time, sinceAsk: asks.since(time), reducesMotion: Displays.reducesMotion(settings)
        ))
    }

    /// Frames run while something moves; otherwise only the light's slow refresh, while it is lit and moves, and with
    /// the panel out, a frame as its times next change. Hidden, none.
    private func pace(at time: Double) {
        let ghosts = ghost.step(at: time)
        let running = isShown && (frame.isMoving || folds.isMoving(at: time) || ghosts || isWashing(at: time))

        link?.isPaused = !running
        lightLink?.isPaused = running || !lightMoves(at: time)
        ages?.invalidate()
        ages = nil
        if isShown, !running, frame.panel != nil {
            agesChange()
        }
    }

    /// Whether the light, shown and lit, changes from moment to moment (`LiveLight.moves`).
    private func lightMoves(at time: Double) -> Bool {
        isShown && frame.light.level > 0.001
            && LiveLight.moves(sinceAsk: asks.since(time), reducesMotion: Displays.reducesMotion(settings))
    }

    /// A new row's wash, which glass draws a frame at a time.
    private func isWashing(at time: Double) -> Bool {
        NotchSurface.drawn(settings.material) == .glass && washed.map { time - $0 < Wash.length } == true
    }

    /// A frame as the first of the open panel's times next reads differently, menus tracking or not.
    private func agesChange() {
        let now = Displays.wallNow
        guard let next = rows.shown.map({ $0.ageChanges(after: now) }).min() else {
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
        action(notch)
        wake()
    }

    /// The session row under a point on the stage, while the panel shows it.
    private func row(at point: CGPoint) -> Int? {
        guard let panel = frame.panel, panel.contains(point) else {
            return nil
        }

        return list.content.row(at: panel.contentPoint(point, mirror: edge.mirror, scroll: scroll))
    }

    /// A press on a row jumps to its session, unless no window holds it; anywhere else on the black, it may become
    /// a drag, unless the notch is still crossing to the other edge from the last.
    private func press(at screenPoint: CGPoint) {
        advance()
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        if let index = row(at: point) {
            click(index)
        } else if frame.hits(point), notch.mayCarry {
            drag = NotchDrag(at: point, home: notch.notchY)
        }
    }

    /// A row that jumps, while the panel takes the click and no jump runs, as the menu's works are disabled while one
    /// does: the row the model presses in, which it jumps to. Once the jump has jumped, the caption says where.
    private func click(_ index: Int) {
        let items = notch.items

        guard !isJumping(), items.indices.contains(index), let session = items[index].session,
              let target = board.jump(session), notch.clickRow(index)
        else {
            return
        }

        clicks += 1

        let click = clicks

        caption.jumping(to: session.project)
        wake()
        onJump(target) { [weak self] in self?.answered(jumped: $0, click: click) }
    }

    /// The jump a click asked for answered; an answer to an earlier click changes nothing.
    private func answered(jumped: Bool, click: Int) {
        guard click == clicks else {
            return
        }

        caption.answered(jumped: jumped, at: Displays.now)
        act { $0.jumpAnswered() }
    }

    /// A press moved: once it is a drag the panel closes, the notch lifts, and it follows the pointer along the edge,
    /// its ghost on the other edge once the pointer is past the screen's middle.
    private func drag(to screenPoint: CGPoint) {
        advance()
        guard var drag, let point = edge.stagePoint(screenPoint) else {
            return
        }

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

        let moved = drag.dropped(settings, at: notch.notchY, height: edge.frame.height)

        notch.drop(across: drag.isAcross)
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
            notch.carried(to: edge.stage.notchY)
            notch.drop(across: false)
        }
        window.ignoresMouseEvents = true
    }

    private func scroll(by delta: Double) {
        advance()
        guard let panel = frame.panel else {
            return
        }

        scroll = list.content.scrolled(scroll, by: delta, showing: panel.frame.height)
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

        if clickElsewhere, isOut {
            act { $0.clickElsewhere() }
        } else if !window.ignoresMouseEvents
            || frame.wakes(from: seen, to: edge.stagePoint(NSEvent.mouseLocation), field: notch.field)
        {
            wake()
        }
    }
}
