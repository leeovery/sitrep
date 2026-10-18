import AppKit
import SitRepPanel

/// The strip on the screen with the menu bar, in place of the notch when Lee chooses it: it owns the strip's model,
/// with the panel's sample sessions as its marks, feeds it a frame per display refresh with the pointer and the time,
/// and draws what each gives back. Frames run only while the model moves, or the pointer is on the strip or a tab;
/// mouse monitors wake them. Its window is click-through but over the strip and an open tab.
@MainActor
final class StripController: NSObject {
    private let dials: PanelDials
    private let model: Strip
    private let view = StripSurface()
    private let window: SidePanel
    private var edge: ScreenEdge
    private var frame: StripFrame
    private var link: CADisplayLink?
    /// How many asks the menu has simulated.
    private var asked = 0

    init(dials: PanelDials) {
        self.dials = dials
        edge = Display.edge
        let input = StripInput(
            time: Display.now, pointer: edge.stagePoint(NSEvent.mouseLocation), stage: edge.stripStage,
            reducesMotion: Display.reducesMotion
        )
        model = Strip(
            settings: dials.strip, sessions: StripSession.samples(at: StripWordsLayer.now),
            measure: StripWordsLayer.measure, input
        )
        frame = model.frame(input)
        window = SidePanel(frame: edge.stripWindow, view: view, overFullScreen: false)
        super.init()

        view.material = dials.material
        view.place(menu: edge.stripStage.menu, height: edge.stripStage.height)
        view.onClick = { [unowned self] point in click(at: point) }
        link = view.displayLink(target: self, selector: #selector(tick))
        link?.isPaused = true
        link?.add(to: .main, forMode: .common)
        listen()
    }

    /// Whether the strip is on the display, Lee having chosen it over the notch: hidden, it draws nothing and hears
    /// nothing, and its news waits for it.
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
            }
        }
    }

    /// The dials changed: the strip takes its settings and its material at once.
    func retune() {
        model.settings = dials.strip
        view.material = dials.material
        wake()
    }

    /// A new ask, as the menu simulates one: its needs you moves in at once, its ring flashing; the prototype's asks,
    /// in turn.
    func newAsk() {
        let ask = Self.asks[asked % Self.asks.count]
        asked += 1
        model.newAsk(StripSession(
            id: "ask-\(asked)", project: ask.project, kind: .needs, title: ask.title, code: ask.code, more: ask.more,
            sub: ask.sub, since: StripWordsLayer.now
        ))
        wake()
    }

    /// Nothing needs Lee any more, as the menu has it: every ask a window holds is answered, and its session carries
    /// on working, shown in place until the marks re-sort.
    func answerAll() {
        for var session in model.sessions where session.kind == .needs && !session.away {
            session.kind = .working
            session.title = "Carrying on from your answer"
            session.code = nil
            session.more = nil
            session.since = StripWordsLayer.now
            model.change(session)
        }
        wake()
    }

    @objc private func tick(_ link: CADisplayLink) {
        step(at: link.targetTimestamp * 1000)
    }

    /// One frame: the model moved on to this time with the pointer where it is, drawn, and the frames paced.
    private func step(at time: Double) {
        let pointer = edge.stagePoint(NSEvent.mouseLocation)
        frame = model.frame(StripInput(
            time: time, pointer: pointer, stage: edge.stripStage, reducesMotion: Display.reducesMotion
        ))
        view.show(frame, hoverRow: pointer.flatMap(countRow))
        window.ignoresMouseEvents = !(pointer.map(frame.hits) ?? false)
        link?.isPaused = !(isShown && frame.wantsFrames(pointer: pointer))
    }

    /// Starts the frames again, with a frame at once, so what changed shows on this refresh.
    private func wake() {
        guard isShown, link?.isPaused == true else {
            return
        }

        step(at: Display.now)
    }

    /// The count's row under a point on the stage, while its tab is out.
    private func countRow(at point: CGPoint) -> String? {
        frame.tabs.first { $0.isLive && $0.key == .more && $0.contains(point) }?.row(at: point)
    }

    private func click(at screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        model.click(at: point)
        wake()
    }

    /// The pointer anywhere wakes the frames when it comes onto the strip; a click in another app draws an open tab
    /// back. The global monitor hears what goes to other apps, the local one what comes to SitRep.
    private func listen() {
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let downs: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        _ = NSEvent.addGlobalMonitorForEvents(matching: moves.union(downs)) { [weak self] event in
            let isClick = downs.contains(NSEvent.EventTypeMask(type: event.type))

            MainActor.assumeIsolated { self?.heard(clickElsewhere: isClick) }
        }
        // a click in SitRep's own windows, such as the dials', leaves the tab as it is
        _ = NSEvent.addLocalMonitorForEvents(matching: moves) { [weak self] event in
            MainActor.assumeIsolated { self?.heard(clickElsewhere: false) }

            return event
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    private func heard(clickElsewhere: Bool) {
        guard isShown else {
            return
        }

        if clickElsewhere {
            model.clickElsewhere()
            wake()
        } else if frame.wantsFrames(pointer: edge.stagePoint(NSEvent.mouseLocation)) {
            wake()
        }
    }

    @objc private func screensChanged() {
        edge = Display.edge
        window.setFrame(edge.stripWindow, display: true)
        view.place(menu: edge.stripStage.menu, height: edge.stripStage.height)
        wake()
    }

    /// The prototype's new asks (its `ASKS`).
    private static let asks: [(project: String, title: String, code: String?, more: Int?, sub: String)] = [
        ("Mint", "Choose the diff budget", nil, nil, "Mint · Token-aware diff sizing"),
        ("Fabric", "Allow Bash ", "aws sso login --profile dev", nil, "Fabric · Atlas overload from llm-manager"),
        ("Switchboard", "Give the go for stage 3", nil, nil, "Switchboard · Milestone 7 stages 4 to 14"),
        ("Aircon", "Which unit is the bedroom?", nil, 2, "Aircon · Aircon local control"),
        ("Agentic Workflows", "Approve the reshaped review workflow", nil, nil, "Agentic Workflows · Reshape the workflows"),
    ]
}
