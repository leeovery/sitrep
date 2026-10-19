import AppKit
import SitRepEdge
import SitRepPanel

/// The notch on its display: it owns the notch, in the style Lee chose, feeds it a frame per display refresh with the
/// pointer, the time and the board's rows, and draws what each gives back. Frames run only while the model moves, or
/// the pointer is near the notch or over the open panel; the mouse monitors wake them, on any move while the panel is
/// out (`Frame.wakes`). While idle it costs nothing, but for the light, which breathes on a slow refresh of its own
/// while something needs Lee.
@MainActor
final class NotchController: NSObject {
    /// A click on a row: the session to jump to.
    var onJump: (String) -> Void = { _ in }
    /// A drag let the notch go: the settings with its new place.
    var onMoved: (EdgeSettings) -> Void = { _ in }

    private var settings: EdgeSettings
    private var edge: ScreenEdge
    private var notch: any Notch
    private var style: NotchStyle
    private var board = PanelBoard()
    private var rows = HeldRows()
    /// The panel's list as the model and the drawing have it.
    private var list: PanelList
    private let surface = NotchSurface()
    private let window: EdgeWindow
    private var frame: Frame
    private var asks = AskClock()
    private var link: CADisplayLink?
    private var lightLink: CADisplayLink?
    private var scroll = 0.0
    private var drag: NotchDrag?
    private var monitors: [Any] = []

    /// The slow refresh the light breathes on while frames are idle.
    private static let lightRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)

    init(_ settings: EdgeSettings, on display: Display) {
        self.settings = settings
        edge = ScreenEdge(display, settings)
        style = settings.style
        list = PanelList(head: board.head, content: Content(laying: []))

        let input = Self.input(at: Displays.now, pointer: nil, needsLee: false, edge, list, settings)

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
        link = startLink(#selector(tick))
        lightLink = startLink(#selector(tickLight), rate: Self.lightRate)
        listen()
    }

    /// Whether the notch is on its display, Lee having chosen it and no full-screen app having the display: hidden,
    /// it draws nothing and hears nothing, and the board waits for it.
    var isShown = false {
        didSet {
            guard isShown != oldValue else {
                return
            }

            if isShown {
                window.orderFrontRegardless()
                wake()
            } else {
                window.orderOut(nil)
                link?.isPaused = true
                lightLink?.isPaused = true
            }
        }
    }

    /// The board as `watch` last printed it. Its rows show at once while the panel is in, and keep their places while
    /// it is out; a row new on it swells the notch and, with the panel out, is washed; something needing Lee with
    /// nothing new, as on the first board, lights the notch with no swell.
    func show(_ board: PanelBoard) {
        board.tell(notch, after: self.board)
        self.board = board
        rows.take(board.sessions)
        relist()
        if isOut {
            surface.wash(board.new)
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
        wake()
    }

    /// Starts the frames again, with a frame at once, so what changed shows on this refresh.
    func wake() {
        guard isShown, link?.isPaused == true else {
            return
        }

        step(at: Displays.now)
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

    @objc private func tickLight(_ link: CADisplayLink) {
        drawLight(at: link.targetTimestamp * 1000)
    }

    /// One frame: the model moved on to this time with the pointer where it is, drawn, and the clocks paced.
    private func step(at time: Double) {
        let pointer = edge.stagePoint(NSEvent.mouseLocation)
        let input = Self.input(at: time, pointer: pointer, needsLee: board.needsLee, edge, list, settings)

        frame = notch.frame(input)
        restyle(input)
        if rows.hold(notch.phase != .closed) {
            relist()
        }
        scroll = frame.panel.map { list.content.scrolled(scroll, by: 0, showing: $0.frame.height) } ?? 0
        asks.take(lastAsk: frame.light.lastAsk, simTime: frame.time, at: time)
        surface.show(NotchScene(
            frame: frame, hover: pointer.flatMap(row), scroll: scroll, now: Displays.wallNow, mirror: edge.mirror
        ))
        drawLight(at: time)
        window.ignoresMouseEvents = drag == nil && !(pointer.map(frame.hits) ?? false)
        pace(pointer)
    }

    /// The rows as they show now, laid out, to the model's next frame and the drawing.
    private func relist() {
        list = PanelList(head: board.head, content: Content(laying: Item.list(rows.shown)))
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
        surface.showLight(frame.light, outline: frame.outline, colours: LiveLight(time: time, sinceAsk: asks.since(time)))
    }

    /// Frames run while the model wants them; otherwise only the light's slow refresh, and only while it is lit.
    /// Hidden, none.
    private func pace(_ pointer: CGPoint?) {
        let running = isShown && frame.wantsFrames(pointer: pointer, field: notch.field)

        link?.isPaused = !running
        lightLink?.isPaused = running || !isShown || frame.light.level <= 0.001
    }

    /// Lee's action on the model, then frames to show it.
    private func act(_ action: (any Notch) -> Void) {
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
    /// a drag.
    private func press(at screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        if let index = row(at: point) {
            click(index)
        } else if frame.hits(point) {
            drag = NotchDrag(at: point, home: notch.notchY)
        }
    }

    private func click(_ index: Int) {
        guard let session = list.item(index)?.session, let target = board.jump(session) else {
            return
        }

        act { $0.clickRow(index) }
        onJump(target)
    }

    /// A press moved: once it is a drag the panel closes and the notch follows the pointer along the edge.
    private func drag(to screenPoint: CGPoint) {
        guard var drag, let point = edge.stagePoint(screenPoint) else {
            return
        }

        if drag.move(to: point, width: edge.frame.width) {
            notch.carry()
        }
        self.drag = drag
        if drag.isCarrying {
            edge = edge.moved(along: drag.notchY / edge.frame.height)
        }
        wake()
    }

    /// The press let go: a drag leaves the notch where it took it, saved.
    private func release() {
        defer { drag = nil }

        guard let drag, drag.isCarrying else {
            return
        }

        onMoved(drag.dropped(settings, at: notch.notchY, height: edge.frame.height))
    }

    private func scroll(by delta: Double) {
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
        } else if frame.wakes(pointer: edge.stagePoint(NSEvent.mouseLocation), field: notch.field) {
            wake()
        }
    }
}
