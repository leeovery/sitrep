import AppKit
import Observation
import SitRepEdge
import SitRepMenu
import SitRepPanel

/// SitRep's own edge on the welcome's stage (DESIGN, "The welcome window"): the notch or the strip as Lee set them,
/// the real runs drawing into the real surfaces, fed a made-up board (`WelcomeBoard`), never a picture or a video, so
/// the stage cannot drift from the app. They run on a screen of the stage's own, its menu bar the stage's, at the
/// size the step plays them, the notch's home where Paper's boards put it, and follow the real settings: notch or
/// strip, style, material and edge, each change drawn at once, the window in front or not. Frames run while the window
/// is in front and something moves, as the real edge's do: the shape, the light, or the loop's pointer; between them
/// the stage sleeps until the loop's next beat or a sound chosen. Under Reduce motion, the Mac's or SitRep's, the runs
/// cross-fade their states rather than move. It takes no clicks.
@MainActor
final class StageEdge: NSView {
    /// The edge's size on the stage: step 1's open panel at this share, so it sits on the stage as on a screen; the
    /// notch alone at its real size, as Paper's boards make it the subject.
    static let loopScale = 0.7
    static let stillScale = 1.0
    /// The notch's home on the stage, in its points from its top, where Paper's boards put it: board A's, and C's, D's
    /// and F's.
    static let loopNotchY = 226.0
    static let stillNotchY = 230.0
    /// The slow refresh the light breathes on while nothing else moves, as the real notch's.
    private static let lightRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)

    /// What the stage plays: a change starts it afresh, at its own size.
    var play = WelcomeStage.loop {
        didSet {
            if play != oldValue {
                restage()
            }
        }
    }

    /// Whether the window is in front: only then do frames run, and the loop's clock with them.
    var isRunning = false {
        didSet {
            guard isRunning != oldValue else {
                return
            }

            lastTime = nil
            if isRunning {
                step(at: Displays.now)
            } else {
                sleep()
            }
        }
    }

    /// Where the callout stands, for the desktop to place it.
    let callout = StageCallout()
    /// How the last frame paced the stage: internal only for the tests, which read that a chime swells the notch.
    private(set) var lastPace = StagePace.still

    private let preferences: Preferences
    private let size: CGSize
    private let menuBar: Double
    private let content = Scaled()
    private var settings: EdgeSettings
    private var shape: any StageShape
    private var link: CADisplayLink?
    /// The loop's next beat, while frames sleep.
    private var beat: Timer?
    /// The loop's own clock, ms, which runs only while the window is in front.
    private var loopTime = 0.0
    private var lastTime: Double?
    /// The ask on the board as last told.
    private var asks = false
    private var chimes = 0
    /// The ask's row's middle on the stage, once the loop's panel shows it.
    private var row: CGPoint?

    /// The stage this big in its points, under a menu bar this tall, its settings Lee's.
    init(size: CGSize, menuBar: Double, preferences: Preferences) {
        self.preferences = preferences
        self.size = size
        self.menuBar = menuBar
        settings = preferences.edge
        shape = Self.shape(settings.show)
        super.init(frame: CGRect(origin: .zero, size: size))

        content.frame = bounds
        addSubview(content)
        restage()
        follow()
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

    /// Whether frames are drawing a refresh at a time: internal only for the tests.
    var isDrawing: Bool { link.map { !$0.isPaused } ?? false }

    /// The edge's points to the stage's, as the step plays it.
    var scale: Double { play == .loop ? Self.loopScale : Self.stillScale }

    /// The screen the edge runs on, the stage's own at the edge's scale, its notch's home where Paper puts it.
    var edge: ScreenEdge {
        let screen = CGRect(origin: .zero, size: CGSize(width: size.width / scale, height: size.height / scale))
        let notchY = play == .loop ? Self.loopNotchY : Self.stillNotchY

        return ScreenEdge(
            frame: screen, visible: CGRect(x: 0, y: 0, width: screen.width, height: screen.height - menuBar / scale),
            edge: settings.edge, along: notchY / size.height
        )
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

    /// The window closed: frames stop for good, until it next comes forward.
    func stop() {
        isRunning = false
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        step(at: link.targetTimestamp * 1000)
    }

    /// One frame at this time on the display's clock: the settings as Lee left them, the loop on by as long as since
    /// the last frame while the window is in front, the edge moved on and drawn, and the frames paced.
    func step(at time: Double) {
        follow(preferences.edge)
        if isRunning {
            loopTime += max(0, time - (lastTime ?? time))
        }
        lastTime = isRunning ? time : nil

        let due = asks(at: loopTime)

        if due != asks {
            tell(due, isNew: due)
        }
        if play == .loop, row == nil, WelcomeLoop.findsRow(at: loopTime) {
            row = shape.middle(of: WelcomeBoard.asking, on: edge, settings)
        }

        let pointer = play == .loop
            ? WelcomeLoop.pointer(at: loopTime, notchY: edge.stage.notchY, row: row)
            : nil

        shape.step(at: time, pointer: pointer, edge, settings)
        if play == .callout {
            placeCallout()
        }
        pace(at: time)
    }

    /// Beside the shape at rest, 14 past its front, level with the notch's home; told the desktop only as it moves.
    private func placeCallout() {
        let edge = edge
        let place = StageCallout.Place(
            inset: shape.front(on: edge) * scale + 14, middle: edge.stage.notchY * scale, isRight: settings.edge == .right
        )

        if place != callout.place {
            callout.place = place
        }
    }

    /// The play started afresh: the edge's screen at its scale, the shape and its run made anew, the board told, and
    /// a frame drawn.
    private func restage() {
        loopTime = 0
        lastTime = nil
        row = nil
        content.setBoundsSize(edge.frame.size)
        replace(with: Self.shape(settings.show))
        step(at: Displays.now)
    }

    /// Frames run while something moves; while only the light breathes, on its slow refresh; else none, the loop
    /// waking them at its next beat. Behind, none.
    private func pace(at time: Double) {
        let pointerMoves = play == .loop && WelcomeLoop.pointerMoves(at: loopTime)

        lastPace = pointerMoves ? .moving : shape.pace(at: time, settings)
        guard isRunning, lastPace != .still else {
            return sleep()
        }

        let link = link ?? makeLink()

        beat?.invalidate()
        beat = nil
        link.preferredFrameRateRange = lastPace == .light ? Self.lightRate : .default
        link.isPaused = false
    }

    /// No frames until something moves: the loop wakes them at its next beat.
    private func sleep() {
        link?.isPaused = true
        beat?.invalidate()
        beat = nil
        if isRunning {
            wakeAtTheNextBeat()
        }
    }

    private func wakeAtTheNextBeat() {
        guard play == .loop else {
            return
        }

        let wait = (WelcomeLoop.next(after: loopTime) - loopTime) / 1000
        let beat = Timer(timeInterval: wait, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.step(at: Displays.now) }
        }

        RunLoop.main.add(beat, forMode: .common)
        self.beat = beat
    }

    private func makeLink() -> CADisplayLink {
        let link = displayLink(target: self, selector: #selector(tick))

        link.add(to: .main, forMode: .common)
        self.link = link
        return link
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

    /// The made-up board told to the edge, the ask on it new as it lands, which swells the notch. With the ask gone,
    /// so is its row.
    private func tell(_ asks: Bool, isNew: Bool) {
        let now = Displays.wallNow
        let board = asks ? WelcomeBoard.asked(at: now, isNew: isNew) : WelcomeBoard.calm(at: now)

        self.asks = asks
        if !asks {
            row = nil
        }
        shape.show(board, at: Displays.now, edge, settings)
    }

    /// Each change Lee makes to the edge's settings drawn at once, the window in front or not, so the stage never
    /// stands a frame behind the desktop round it.
    private func follow() {
        withObservationTracking { _ = preferences.edge } onChange: { [weak self] in
            Task { @MainActor in
                self?.follow()
                self?.step(at: Displays.now)
            }
        }
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
            replace(with: Self.shape(settings.show))
        } else {
            place(shape)
            shape.apply(settings, at: Displays.now, edge)
        }
    }

    /// Another shape, or the same made anew, in the old one's place, told the board.
    private func replace(with shape: any StageShape) {
        self.shape.surface.removeFromSuperview()
        self.shape = shape
        content.addSubview(shape.surface)
        place(shape)
        shape.apply(settings, at: Displays.now, edge)
        tell(asks(at: loopTime), isNew: false)
    }

    /// The shape's surface where its window would stand on the stage's screen, against the edge Lee chose.
    private func place(_ shape: any StageShape) {
        let edge = edge, window = shape.window(on: edge)

        shape.surface.frame = CGRect(
            x: window.minX, y: edge.frame.maxY - window.maxY, width: window.width, height: window.height
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

/// Where the callout stands beside the shape at rest, for the desktop round the stage to place it as it changes.
@MainActor
@Observable
final class StageCallout {
    /// Its near side this far in from the stage's edge, 14 past the shape's front; its middle this far down, level with
    /// the notch's home; and which edge it is against.
    struct Place: Equatable {
        var inset: CGFloat
        var middle: CGFloat
        var isRight: Bool
    }

    var place = Place(inset: 0, middle: 0, isRight: false)
}

/// What moves on the stage: the shape or the pointer, a refresh at a time; only the light, which breathes on a slow
/// refresh; or nothing.
enum StagePace {
    case moving, light, still
}

/// The notch or the strip on the stage: its run, and the surface it draws into, which the real edge's window holds.
@MainActor
protocol StageShape: AnyObject {
    var surface: NSView { get }
    /// Where its window stands on a screen, in the screen's coordinates.
    func window(on edge: ScreenEdge) -> CGRect
    /// How far into the screen it reaches at rest.
    func front(on edge: ScreenEdge) -> Double
    /// The middle of a session's row on the stage, while the shape shows it.
    func middle(of session: String, on edge: ScreenEdge, _ settings: EdgeSettings) -> CGPoint?
    func apply(_ settings: EdgeSettings, at time: Double, _ edge: ScreenEdge)
    func show(_ board: PanelBoard, at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings)
    /// One frame, the pointer where the stage puts it, drawn as the real edge draws it.
    func step(at time: Double, pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings)
    /// What moves at this time, as the real edge paces its frames.
    func pace(at time: Double, _ settings: EdgeSettings) -> StagePace
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

    /// Found down the panel's middle, on the rows as the run lays them out.
    func middle(of session: String, on edge: ScreenEdge, _ settings: EdgeSettings) -> CGPoint? {
        guard let run, let panel = run.frame.panel?.frame else {
            return nil
        }

        let setting = Self.setting(edge, settings), x = panel.midX
        let on = stride(from: panel.minY, to: panel.maxY, by: 1).filter { y in
            run.row(at: CGPoint(x: x, y: y), in: setting)?.session?.id == session
        }

        return on.first.map { CGPoint(x: x, y: ($0 + on[on.count - 1]) / 2) }
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

    func pace(at time: Double, _ settings: EdgeSettings) -> StagePace {
        guard let run else {
            return .still
        }

        let reduces = Displays.reducesMotion(settings), light = run.lightTime(time)

        if run.frame.isMoving || run.isFolding(at: time) {
            return .moving
        }
        return run.frame.light.level > 0.001 && LiveLight.moves(sinceAsk: run.sinceAsk(at: light), reducesMotion: reduces)
            ? .light : .still
    }

    /// Nothing to tell of what it showed: the stage has no window to save a crossing for, nor a caption.
    private func draw(_ run: NotchRun, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        _ = run.takeShown()
        notch.draw(run, in: Self.setting(edge, settings))
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

    /// The strip has no panel: the pointer rests on its mark.
    func middle(of session: String, on edge: ScreenEdge, _ settings: EdgeSettings) -> CGPoint? {
        nil
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

    func pace(at time: Double, _ settings: EdgeSettings) -> StagePace {
        run?.frame.isMoving == true ? .moving : .still
    }

    /// Nothing to tell of what it showed: the stage has no window to save a crossing for, nor a caption.
    private func draw(_ run: StripRun, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        _ = run.takeShown()
        strip.draw(run, in: Self.setting(edge, settings), mirror: edge.stripMirror)
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
