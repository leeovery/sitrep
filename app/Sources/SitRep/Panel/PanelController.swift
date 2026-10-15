import AppKit
import SitRepPanel

/// The side panel on the screen with the menu bar: it owns the model, feeds it a frame per display refresh with the
/// pointer and the time, and draws what each gives back. Frames run only while the model moves, or the pointer is
/// near the lip or over the open panel; mouse monitors wake them. While idle it costs nothing, but for the light,
/// which breathes on a slow refresh of its own while something needs Lee.
@MainActor
final class PanelController: NSObject {
    /// Whether anything needs Lee: for the spike, a toggle in the menu.
    var needsLee = true {
        didSet { wake() }
    }

    private let dials: PanelDials
    private let model: Meniscus
    /// The content's layout, which the view draws and a click finds its row in.
    private let content: Content
    private let view: PanelView
    private let window: SidePanel
    private var edge: ScreenEdge
    private var frame: Frame
    private var asks = AskClock()
    private var link: CADisplayLink?
    private var lightLink: CADisplayLink?

    /// The slow refresh the light breathes on while frames are idle.
    private static let lightRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)

    init(dials: PanelDials) {
        self.dials = dials
        edge = Self.screenEdge()

        let input = Input(time: Self.now, pointer: edge.stagePoint(NSEvent.mouseLocation), needsLee: true, stage: edge.stage)

        model = Meniscus(settings: dials.settings, input)
        frame = model.frame(input)
        content = input.content
        view = PanelView(items: model.items, content: content)
        window = SidePanel(frame: edge.window, view: view)
        super.init()

        view.onClick = { [unowned self] point in click(at: point) }
        dials.onChange = { [unowned self] settings in
            model.settings = settings
            wake()
        }
        window.orderFrontRegardless()
        link = startLink(#selector(tick))
        lightLink = startLink(#selector(tickLight), rate: Self.lightRate)
        listen()
        step(at: Self.now)
    }

    /// A new ask, as the menu simulates one: the lip swells and the light flashes. Coming to need Lee is one already.
    func newAsk() {
        if needsLee {
            act { $0.newAsk() }
        } else {
            needsLee = true
        }
    }

    private static var now: Double { CACurrentMediaTime() * 1000 }

    /// The screen with the menu bar, which the panel lives on.
    private static func screenEdge() -> ScreenEdge {
        let screen = NSScreen.screens.first

        return ScreenEdge(frame: screen?.frame ?? .zero, visible: screen?.visibleFrame ?? .zero)
    }

    private func startLink(_ selector: Selector, rate: CAFrameRateRange? = nil) -> CADisplayLink {
        let link = view.displayLink(target: self, selector: selector)

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

        frame = model.frame(Input(time: time, pointer: pointer, needsLee: needsLee, stage: edge.stage))
        asks.take(lastAsk: frame.light.lastAsk, simTime: frame.time, at: time)
        view.show(frame, hover: pointer.flatMap(row))
        drawLight(at: time)
        window.ignoresMouseEvents = !(pointer.map(frame.hits) ?? false)
        pace(pointer)
    }

    private func drawLight(at time: Double) {
        view.showLight(frame.light, outline: frame.outline, colours: LiveLight(time: time, sinceAsk: asks.since(time)))
    }

    /// Frames run while the model wants them; otherwise only the light's slow refresh, and only while it is lit.
    private func pace(_ pointer: CGPoint?) {
        let running = frame.wantsFrames(pointer: pointer, field: model.settings.field)

        link?.isPaused = !running
        lightLink?.isPaused = running || frame.light.level <= 0.001
    }

    /// Starts the frames again, with a frame at once, so what changed shows on this refresh.
    private func wake() {
        guard link?.isPaused == true else {
            return
        }

        step(at: Self.now)
    }

    private var isOut: Bool { model.phase == .open || model.phase == .opening }

    /// Lee's action on the model, then frames to show it.
    private func act(_ action: (Meniscus) -> Void) {
        action(model)
        wake()
    }

    /// The session row under a point on the stage, while the panel shows it.
    private func row(at point: CGPoint) -> Int? {
        guard let panel = frame.panel, panel.contains(point) else {
            return nil
        }

        let inContent = CGPoint(x: point.x - panel.frame.minX, y: point.y - panel.frame.minY)

        return content.row(at: inContent, of: model.items)
    }

    private func click(at screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        if frame.hitRect.contains(point) {
            act { $0.clickLip() }
        } else if let row = row(at: point) {
            act { $0.clickRow(row) }
        }
    }

    /// The pointer anywhere wakes the frames when it comes near; a click in another app closes the panel. The
    /// global monitor hears what goes to other apps, the local one what comes to SitRep.
    private func listen() {
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let downs: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        _ = NSEvent.addGlobalMonitorForEvents(matching: moves.union(downs)) { [weak self] event in
            let isClick = downs.contains(NSEvent.EventTypeMask(type: event.type))

            MainActor.assumeIsolated { self?.heard(clickElsewhere: isClick) }
        }
        // a click in SitRep's own windows, such as the dials', leaves the panel as it is
        _ = NSEvent.addLocalMonitorForEvents(matching: moves) { [weak self] event in
            MainActor.assumeIsolated { self?.heard(clickElsewhere: false) }

            return event
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    private func heard(clickElsewhere: Bool) {
        if clickElsewhere, isOut {
            act { $0.clickElsewhere() }
        } else if frame.wantsFrames(pointer: edge.stagePoint(NSEvent.mouseLocation), field: model.settings.field) {
            wake()
        }
    }

    @objc private func screensChanged() {
        edge = Self.screenEdge()
        window.setFrame(edge.window, display: true)
        wake()
    }
}
