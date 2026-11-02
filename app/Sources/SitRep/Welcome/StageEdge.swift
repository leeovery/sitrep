import AppKit
import SitRepEdge
import SitRepMenu
import SitRepPanel

/// SitRep's own edge on the welcome's stage (DESIGN, "The welcome window"): the notch or the strip as Lee set them,
/// the real runs drawing into the real surfaces, fed a made-up board (`WelcomeBoard`), never a picture or a video, so
/// the stage cannot drift from the app. They run on a screen of the stage's own, its menu bar the stage's, drawn at
/// `scale` of their size, and follow the real settings a frame at a time: notch or strip, style, material, edge and
/// place. A frame runs a refresh at a time while the window is in front; behind, the stage holds where it is. Under
/// Reduce motion, the Mac's or SitRep's, the runs cross-fade their states rather than move. It takes no clicks.
@MainActor
final class StageEdge: NSView {
    /// The edge drawn at this share of its size, so the panel and its rows sit on the stage as on a screen.
    static let scale = 0.7

    /// What the stage plays: a change starts it afresh.
    var play = WelcomeStage.loop {
        didSet {
            if play != oldValue {
                loopTime = 0
                tell(asks(at: 0), isNew: false)
                step(at: Displays.now)
            }
        }
    }

    /// Whether the window is in front: only then do frames run.
    var isRunning = false {
        didSet {
            link?.isPaused = !isRunning
        }
    }

    private let preferences: Preferences
    private let screen: CGRect
    private let menuBar: Double
    private let content = Scaled()
    private var settings: EdgeSettings
    private var shape: any StageShape
    private var link: CADisplayLink?
    /// The loop's own clock, ms, which stands still while the window is behind.
    private var loopTime = 0.0
    private var lastTime: Double?
    /// The ask on the board as last told.
    private var asks = false
    private var chimes = 0

    /// The stage this big in its points, under a menu bar this tall, its settings Lee's.
    init(size: CGSize, menuBar: Double, preferences: Preferences) {
        self.preferences = preferences
        self.menuBar = menuBar / Self.scale
        screen = CGRect(origin: .zero, size: CGSize(width: size.width / Self.scale, height: size.height / Self.scale))
        settings = preferences.edge
        shape = Self.shape(settings.show)
        super.init(frame: CGRect(origin: .zero, size: size))

        content.frame = bounds
        content.setBoundsSize(screen.size)
        addSubview(content)
        put(shape)
        tell(asks(at: 0), isNew: false)
        link = displayLink(target: self, selector: #selector(tick))
        link?.isPaused = true
        link?.add(to: .main, forMode: .common)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    /// The stage is a picture: every click goes to what is under it.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// The surface drawing the edge now: internal only for the tests, which read that it is the edge's own.
    var surface: NSView { shape.surface }

    /// The screen the edge runs on, the stage's own, as the edge's runs see it.
    var edge: ScreenEdge {
        ScreenEdge(
            frame: screen, visible: CGRect(x: 0, y: 0, width: screen.width, height: screen.height - menuBar),
            edge: settings.edge, along: settings.along
        )
    }

    /// Where a callout stands beside the shape at rest, in the stage's points: its near side this far in from the
    /// stage's edge, 14 past the shape's front, and its middle this far down, level with the notch's home.
    var callout: (inset: CGFloat, middle: CGFloat) {
        let edge = edge

        return (shape.front(on: edge) * Self.scale + 14, edge.stage.notchY * Self.scale)
    }

    /// A sound was chosen: the notch swells with it, as for an ask that lands.
    func chime(_ count: Int) {
        guard count != chimes else {
            return
        }

        chimes = count
        if play == .chime {
            tell(asks(at: loopTime), isNew: true)
            step(at: Displays.now)
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        step(at: link.targetTimestamp * 1000)
    }

    /// One frame at this time on the display's clock: the settings as Lee left them, the loop on by as long as the
    /// last frame, at most the 50 the runs take at once, and the edge moved on and drawn.
    func step(at time: Double) {
        follow(preferences.edge)
        loopTime += min(max(time - (lastTime ?? time), 0), 50)
        lastTime = time

        let due = asks(at: loopTime)

        if due != asks {
            tell(due, isNew: due)
        }

        let pointer = play == .loop ? WelcomeLoop.pointer(at: loopTime, notchY: edge.stage.notchY) : nil

        shape.step(at: time, pointer: pointer, edge, settings)
    }

    /// Whether the ask is on the board for the play, at this time into the loop: through the loop's last part, and
    /// throughout while the notch is lit; never at rest, beside the callout.
    private func asks(at loopTime: Double) -> Bool {
        switch play {
        case .loop: WelcomeLoop.asks(at: loopTime)
        case .lit, .chime: true
        case .callout: false
        }
    }

    /// The made-up board told to the edge, the ask on it new as it lands, which swells the notch.
    private func tell(_ asks: Bool, isNew: Bool) {
        let now = Displays.wallNow
        let board = asks ? WelcomeBoard.asked(at: now, isNew: isNew) : WelcomeBoard.calm(at: now)

        self.asks = asks
        shape.show(board, at: Displays.now, edge, settings)
    }

    /// Lee's settings, as they stand: the other shape where he chose it, its board told afresh; else the edge, the
    /// place, the material and the style, which the runs take each frame.
    private func follow(_ settings: EdgeSettings) {
        guard settings != self.settings else {
            return
        }

        let swaps = (settings.show == .strip) != (self.settings.show == .strip)

        self.settings = settings
        if swaps {
            shape.surface.removeFromSuperview()
            shape = Self.shape(settings.show)
            put(shape)
            tell(asks, isNew: false)
        } else {
            place(shape)
            shape.apply(settings, at: Displays.now, edge)
        }
    }

    private func put(_ shape: any StageShape) {
        content.addSubview(shape.surface)
        place(shape)
        shape.apply(settings, at: Displays.now, edge)
    }

    /// The shape's surface where its window would stand on the stage's screen, against the edge Lee chose.
    private func place(_ shape: any StageShape) {
        let window = shape.window(on: edge)

        shape.surface.frame = CGRect(
            x: window.minX, y: screen.maxY - window.maxY, width: window.width, height: window.height
        )
    }

    /// The strip where Lee chose it; else the notch, as the welcome offers no Nothing.
    private static func shape(_ show: EdgeSettings.Show) -> any StageShape {
        show == .strip ? StageStrip() : StageNotch()
    }

    /// The stage's screen at the stage's size, flipped as the edge's windows are.
    private final class Scaled: NSView {
        override var isFlipped: Bool { true }
    }
}

/// The notch or the strip on the stage: its run, and the surface it draws into, which the real edge's window holds.
@MainActor
protocol StageShape: AnyObject {
    var surface: NSView { get }
    /// Where its window stands on a screen, in the screen's coordinates.
    func window(on edge: ScreenEdge) -> CGRect
    /// How far into the screen it reaches at rest.
    func front(on edge: ScreenEdge) -> Double
    func apply(_ settings: EdgeSettings, at time: Double, _ edge: ScreenEdge)
    func show(_ board: PanelBoard, at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings)
    /// One frame, the pointer where the stage puts it.
    func step(at time: Double, pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings)
}

/// The notch on the stage, its folds never kept and nothing folding into "N earlier".
@MainActor
final class StageNotch: StageShape {
    private let notch = NotchSurface()
    private var run: NotchRun?

    var surface: NSView { notch }

    func window(on edge: ScreenEdge) -> CGRect { edge.window }

    func front(on edge: ScreenEdge) -> Double {
        run.map { $0.restingOutline(at: edge.stage.notchY).boundingBox.maxX } ?? 0
    }

    func apply(_ settings: EdgeSettings, at time: Double, _ edge: ScreenEdge) {
        notch.material = settings.material
        if run == nil {
            run = NotchRun(at: time, in: Self.setting(edge, settings))
        }
    }

    func show(_ board: PanelBoard, at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        guard let run else {
            return
        }

        let washes = run.show(board, Self.moment(time, nil, edge, settings))

        if !washes.isEmpty {
            notch.wash(washes, at: run.time)
        }
        draw(run, edge, settings)
    }

    func step(at time: Double, pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        guard let run else {
            return
        }

        run.step(Self.moment(time, pointer, edge, settings))
        draw(run, edge, settings)
    }

    /// As `NotchController` draws a frame, with no window to take clicks and nothing to tell of what it showed.
    private func draw(_ run: NotchRun, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        let setting = Self.setting(edge, settings), light = run.lightTime(run.time)

        _ = run.takeShown()
        notch.show(run.list)
        notch.show(NotchScene(
            frame: run.frame, hover: run.seen.flatMap { run.item(at: $0, in: setting) }, scroll: run.scroll,
            time: run.time, now: Displays.wallNow, mirror: edge.mirror, calendar: run.calendar
        ))
        notch.showLight(run.frame.light, outline: run.frame.outline, colours: LiveLight(
            time: light, sinceAsk: run.sinceAsk(at: light), reducesMotion: setting.reducesMotion
        ))
    }

    private static func moment(
        _ time: Double, _ pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings
    ) -> NotchRun.Moment {
        NotchRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: setting(edge, settings))
    }

    private static func setting(_ edge: ScreenEdge, _ settings: EdgeSettings) -> NotchRun.Setting {
        NotchRun.Setting(
            stage: edge.stage, mirror: edge.mirror, style: settings.style,
            reducesMotion: Displays.reducesMotion(settings), period: .never
        )
    }
}

/// The strip on the stage.
@MainActor
final class StageStrip: StageShape {
    private let strip = StripSurface()
    private var run: StripRun?

    var surface: NSView { strip }

    func window(on edge: ScreenEdge) -> CGRect { edge.stripWindow }

    func front(on edge: ScreenEdge) -> Double {
        run.map { $0.frame.strip.boundingBox.maxX } ?? 0
    }

    func apply(_ settings: EdgeSettings, at time: Double, _ edge: ScreenEdge) {
        strip.material = settings.material
        if let run {
            run.place(settings, Self.moment(time, nil, edge, settings))
        } else {
            run = StripRun(at: time, in: Self.setting(edge, settings), settings, measure: StripWordsLayer.measure)
        }
    }

    func show(_ board: PanelBoard, at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        guard let run else {
            return
        }

        run.show(board, Self.moment(time, nil, edge, settings))
        draw(run, edge, settings)
    }

    func step(at time: Double, pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        guard let run else {
            return
        }

        run.step(Self.moment(time, pointer, edge, settings))
        draw(run, edge, settings)
    }

    /// As `StripController` draws a frame, with no window to take clicks and nothing to tell of what it showed.
    private func draw(_ run: StripRun, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        _ = run.takeShown()
        strip.show(StripScene(
            frame: run.frame, hoverRow: run.hoverRow, note: run.note, now: Displays.wallNow, mirror: edge.stripMirror,
            menu: edge.stripStage.menu, reducesMotion: Displays.reducesMotion(settings)
        ))
    }

    private static func moment(
        _ time: Double, _ pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings
    ) -> StripRun.Moment {
        StripRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: setting(edge, settings))
    }

    private static func setting(_ edge: ScreenEdge, _ settings: EdgeSettings) -> StripRun.Setting {
        StripRun.Setting(stage: edge.stripStage, reducesMotion: Displays.reducesMotion(settings))
    }
}
