import AppKit
import Observation
import SitRepEdge
import SitRepMenu
import SitRepPanel

/// SitRep's own edge on the welcome's stage (DESIGN, "The welcome window"): the notch or the strip as Lee set them,
/// the real runs drawing into the real surfaces, fed a made-up board (`WelcomeBoard`), never a picture or a video, so
/// the stage cannot drift from the app. They run on a screen of the stage's own, its menu bar the stage's, at the
/// size the step plays them, the notch's home, and the strip's centre, where Paper's boards put the notch, and follow
/// the real settings: notch, strip or nothing, style, material and edge, each change drawn at once, the window in front
/// or not.
/// Frames run while the window is in front and something moves, as the real edge's do: the shape, the light, which
/// alone redraws on its slow refresh, or the loop's pointer; between them the stage sleeps until the loop's next beat
/// or a sound chosen. Behind, frames run only until a change settles, the loop's clock held. Under Reduce motion, the
/// Mac's or SitRep's, the runs cross-fade their states rather than move. It takes no clicks.
@MainActor
final class StageEdge: NSView {
    /// Where the welcome's window stands: in front; behind another, frames running only until what moves settles; or
    /// closed, or never yet in front, with none.
    enum Standing {
        case inFront, behind, closed
    }

    /// The edge's size on the stage: step 1's open panel at this share, so it sits on the stage as on a screen; the
    /// notch alone at its real size, as Paper's boards make it the subject.
    static let loopScale = 0.7
    static let stillScale = 1.0
    /// The notch's home on the stage, in its points from its top, where Paper's boards put it: board A's, and C's, D's
    /// and F's.
    static let loopNotchY = 226.0
    static let stillNotchY = 230.0
    /// A sound chosen lights SitRep's item for as long as the notch swells with it (ms): its two swells, 450 apart, and
    /// the second's way back.
    static let chimeLight = 900.0
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

    /// Where the window stands: a change re-paces the frames, and only in front does the loop's clock run.
    var standing = Standing.closed {
        didSet {
            if standing != oldValue {
                lastTime = nil
                step(at: Displays.now)
            }
        }
    }

    /// Where the callout stands, for the desktop to place it.
    let callout = StageCallout()
    /// What the desktop and the words show at this time into step 2's loop.
    let scene = StageScene()
    /// How the last frame paced the stage: internal only for the tests, which read that a chime swells the notch.
    private(set) var lastPace = StagePace.still
    /// The loop's own clock, ms, which runs only while the window is in front: internal only for the tests.
    private(set) var loopTime = 0.0
    /// The frames' link, made as frames first run and gone once the window closes: internal only for the tests.
    private(set) var link: CADisplayLink?
    /// The loop's next beat, while frames sleep in front: internal only for the tests.
    private(set) var beat: Timer?
    /// The end of a chime's light on SitRep's item, while it is lit: internal only for the tests.
    private(set) var chimeEnds: Timer?

    private let preferences: Preferences
    private let size: CGSize
    private let menuBar: Double
    private let content = Scaled()
    private var settings: EdgeSettings
    private var shape: any StageShape
    private var lastTime: Double?
    /// The ask on the board as last told.
    private var asks = false
    private var chimes = 0
    /// When the last sound was chosen, on the display's clock, while the play is the chime's.
    private var chimedAt: Double?
    /// The ask's row's middle on the stage, once the loop's panel shows it: internal only for the tests.
    private(set) var row: CGPoint?
    /// A style or an edge changed since the row was found: the pointer keeps to it until it is found again.
    private var rowIsStale = false
    /// The callout's place as last told the desktop.
    private var placed: StageCallout.Place?
    /// Whether SitRep's item was last told lit: internal only for the tests.
    private(set) var toldItem = true
    /// Whether the loop has the ask's row pressed in: internal only for the tests.
    private(set) var isPressing = false
    /// The scene as last told the desktop: internal only for the tests.
    private(set) var told = WelcomeLoop.Scene.rest

    /// The stage this big in its points, under a menu bar this tall, its settings Lee's.
    init(size: CGSize, menuBar: Double, preferences: Preferences) {
        self.preferences = preferences
        self.size = size
        self.menuBar = menuBar
        settings = preferences.edge
        // none until `restage` below makes the shape for the play
        shape = StageNoEdge()
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

    /// Whether the notch's panel is out: internal only for the tests, which read that step 2's click drains it.
    var isOut: Bool { (shape as? StageNotch)?.isOut ?? false }

    /// The edge's points to the stage's, as the step plays it.
    var scale: Double { play.loop == nil ? Self.stillScale : Self.loopScale }

    /// The screen the edge runs on, the stage's own at the edge's scale, its notch's home where Paper puts it.
    var edge: ScreenEdge {
        let screen = CGRect(origin: .zero, size: CGSize(width: size.width / scale, height: size.height / scale))
        let notchY = play.loop == nil ? Self.stillNotchY : Self.loopNotchY

        return ScreenEdge(
            frame: screen, visible: CGRect(x: 0, y: 0, width: screen.width, height: screen.height - menuBar / scale),
            edge: settings.edge, along: notchY / size.height
        )
    }

    /// The shape at rest on the edge's screen, x into it from its edge, y down from its top.
    var resting: CGRect { shape.resting(on: edge) }

    /// A sound was chosen: the notch swells with it, as for an ask that lands, and SitRep's item in the menu bar
    /// lights for as long.
    func chime(_ count: Int) {
        guard count != chimes else {
            return
        }

        chimes = count
        if play == .chime {
            chimedAt = Displays.now
            tell(asks(at: loopTime), isNew: true)
            step(at: Displays.now)
            wakeAsTheChimeEnds()
        }
    }

    /// The window closed: frames stop for good, the link and the beat with them, until it next comes forward.
    func stop() {
        standing = .closed
        link?.invalidate()
        link = nil
        beat?.invalidate()
        beat = nil
        chimeEnds?.invalidate()
        chimeEnds = nil
    }

    /// A frame, or while only the light breathes, the light alone, as the real notch redraws it.
    @objc private func tick(_ link: CADisplayLink) {
        let time = link.targetTimestamp * 1000

        guard lastPace == .light, shape.pace(at: time, staged) == .light else {
            return step(at: time)
        }

        shape.drawLight(at: time, staged)
    }

    /// One frame at this time on the display's clock: the settings as Lee left them, the loop on by as long as since
    /// the last frame while the window is in front, the edge moved on and drawn, and the frames paced.
    func step(at time: Double) {
        follow(preferences.edge)
        if standing == .inFront {
            loopTime += max(0, time - (lastTime ?? time))
            lastTime = time
        }

        let due = asks(at: loopTime)

        if due != asks {
            tell(due, isNew: due)
        }

        let edge = edge
        let pointer = play.loop?.pointer(at: loopTime, home: shape.home(of: WelcomeBoard.asking, on: edge), row: row)

        shape.step(at: time, pointer: pointer, edge, staged)
        press(at: time)
        findRow(at: time)
        if play == .callout {
            placeCallout()
        }
        tellScene()
        tellItem(at: time)
        pace(at: time)
    }

    /// The ask's row, found on the panel as the frame just drawn lays it out, while the loop's pointer goes to it:
    /// first, again once a change has moved it, and each frame the shape moves.
    private func findRow(at time: Double) {
        guard play.loop?.findsRow(at: loopTime) == true,
              row == nil || rowIsStale || shape.pace(at: time, staged) == .moving
        else {
            return
        }

        row = shape.middle(of: WelcomeBoard.asking, on: edge, staged)
        rowIsStale = false
    }

    /// Step 2's click on the ask's row, pressed as the real notch takes a click, so the row presses in; then the jump
    /// landing, so the panel drains as the real one does once Ghostty has the session's window in front. Nothing is
    /// told anywhere: the stage's run has no one to jump. Pressed only on the row, once found, as a press anywhere
    /// else on the notch would start a drag nothing lets go.
    private func press(at time: Double) {
        let presses = play.loop?.presses(at: loopTime) == true

        guard presses != isPressing else {
            return
        }

        if !presses {
            isPressing = false
            shape.jumped(at: time, edge, staged)
        } else if let row {
            isPressing = true
            shape.press(at: time, pointer: row, edge, staged)
        }
    }

    /// Where step 2's loop stands, told the desktop and the words as it changes, after the view update that may have
    /// brought the frame, never during it.
    private func tellScene() {
        let now = play.loop?.scene(at: loopTime) ?? .rest

        guard now != told else {
            return
        }

        told = now
        Task { @MainActor [scene] in
            scene.now = now
        }
    }

    /// SitRep's item in the menu bar lit while the board has its ask, as the real one lights for needs you, and for a
    /// chime's length after each sound chosen. Told as `tellScene` tells.
    private func tellItem(at time: Double) {
        let chimeLights = chimedAt.map { time - $0 < Self.chimeLight } ?? false
        let isLit = asks(at: loopTime) || chimeLights

        guard isLit != toldItem else {
            return
        }

        toldItem = isLit
        Task { @MainActor [scene] in
            scene.isItemLit = isLit
        }
    }

    /// Beside the shape at rest, 14 past its front, level with the notch's home; with no edge, none. Told the desktop
    /// only as it moves, and after the view update that may have brought it (`EdgeHost`), never during it.
    private func placeCallout() {
        let edge = edge
        let place = shape is StageNoEdge ? nil : StageCallout.Place(
            inset: resting.maxX * scale + 14, middle: edge.stage.notchY * scale, isRight: settings.edge == .right
        )
        guard place != placed else {
            return
        }

        placed = place
        Task { @MainActor [callout] in
            callout.place = place
        }
    }

    /// The play started afresh: the edge's screen at its scale, the shape and its run made anew, the board told, and
    /// a frame drawn.
    private func restage() {
        loopTime = 0
        lastTime = nil
        isPressing = false
        chimedAt = nil
        chimeEnds?.invalidate()
        chimeEnds = nil
        content.setBoundsSize(edge.frame.size)
        replace(with: Self.shape(settings.show, play))
        step(at: Displays.now)
    }

    /// Frames for what moves, as the window stands; in front, between frames, the loop's next beat.
    private func pace(at time: Double) {
        let pointerMoves = standing == .inFront && play.loop?.pointerMoves(at: loopTime) == true

        lastPace = pointerMoves ? .moving : shape.pace(at: time, staged)
        beat?.invalidate()
        beat = nil

        let frames = frames(for: lastPace)

        if standing == .inFront, frames != .moving {
            wakeAtTheNextBeat()
        }
        guard frames != .still else {
            link?.isPaused = true
            return
        }

        let link = link ?? makeLink()

        link.preferredFrameRateRange = frames == .light ? Self.lightRate : .default
        link.isPaused = false
    }

    /// In front, frames as things move; behind, only until what moves settles, the light left at rest; closed, none.
    private func frames(for pace: StagePace) -> StagePace {
        switch standing {
        case .inFront: pace
        case .behind: pace == .moving ? .moving : .still
        case .closed: .still
        }
    }

    private func wakeAtTheNextBeat() {
        guard let loop = play.loop else {
            return
        }

        let wait = (loop.next(after: loopTime) - loopTime) / 1000
        let beat = Timer(timeInterval: wait, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.step(at: Displays.now) }
        }

        RunLoop.main.add(beat, forMode: .common)
        self.beat = beat
    }

    /// A frame as a chime's light on SitRep's item ends, which may have no other frame to end it.
    private func wakeAsTheChimeEnds() {
        chimeEnds?.invalidate()

        let ends = Timer(timeInterval: Self.chimeLight / 1000, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.chimeEnds = nil
                self?.step(at: Displays.now)
            }
        }

        RunLoop.main.add(ends, forMode: .common)
        chimeEnds = ends
    }

    private func makeLink() -> CADisplayLink {
        let link = displayLink(target: self, selector: #selector(tick))

        link.add(to: .main, forMode: .common)
        self.link = link
        return link
    }

    /// Whether the ask is on the board for the play, at this time into the loop: from its landing until the loop ends
    /// or it is answered, and throughout while the notch is lit; never at rest, beside the callout, nor at the sound's
    /// step with no edge, where only each chime lights SitRep's item.
    private func asks(at loopTime: Double) -> Bool {
        if let loop = play.loop {
            return loop.asks(at: loopTime)
        }
        return play != .callout && !(play == .chime && shape is StageNoEdge)
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
        shape.show(board, at: Displays.now, edge, staged)
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
    /// place, the material and the style, which the runs take each frame. A style or an edge moves the ask's row, so
    /// the loop's pointer finds it again.
    private func follow(_ settings: EdgeSettings) {
        guard settings != self.settings else {
            return
        }

        let last = self.settings

        self.settings = settings
        if Self.kind(settings.show, play) != Self.kind(last.show, play) {
            replace(with: Self.shape(settings.show, play))
            return
        }
        if settings.style != last.style || settings.edge != last.edge {
            rowIsStale = true
        }
        place(shape)
        shape.apply(staged, at: Displays.now, edge)
    }

    /// Lee's settings as the stage runs them: the place along the edge the stage's own, so the strip centres where
    /// Paper puts the notch, as the notch sits there, wherever he dragged his own.
    private var staged: EdgeSettings {
        var staged = settings

        staged.along = edge.along
        return staged
    }

    /// Another shape, or the same made anew, in the old one's place, told the board; the ask's row to find again.
    private func replace(with shape: any StageShape) {
        self.shape.surface.removeFromSuperview()
        self.shape = shape
        row = nil
        content.addSubview(shape.surface)
        place(shape)
        shape.apply(staged, at: Displays.now, edge)
        tell(asks(at: loopTime), isNew: false)
    }

    /// The shape's surface where its window would stand on the stage's screen, against the edge Lee chose.
    private func place(_ shape: any StageShape) {
        let edge = edge, window = shape.window(on: edge)

        shape.surface.frame = CGRect(
            x: window.minX, y: edge.frame.maxY - window.maxY, width: window.width, height: window.height
        )
    }

    private enum Kind {
        case notch, strip, none
    }

    /// The shape the stage shows for what Lee chose, as the step plays it: the notch, the strip, or no edge at Nothing.
    /// Steps 1 and 2's loops show the notch at Nothing too, as they teach what it does before step 3 offers the choice.
    private static func kind(_ show: EdgeSettings.Show, _ play: WelcomeStage) -> Kind {
        switch show {
        case .strip: .strip
        case .nothing where play.loop == nil: .none
        case .notch, .nothing: .notch
        }
    }

    private static func shape(_ show: EdgeSettings.Show, _ play: WelcomeStage) -> any StageShape {
        switch kind(show, play) {
        case .notch: StageNotch()
        case .strip: StageStrip()
        case .none: StageNoEdge()
        }
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

    /// Nil with no edge to point at.
    var place: Place?
}

/// Where step 2's loop stands, for the desktop round the stage and the words beside it to show as it changes, and
/// whether SitRep's item in the desktop's menu bar is lit.
@MainActor
@Observable
final class StageScene {
    var now = WelcomeLoop.Scene.rest
    var isItemLit = true
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
    /// The shape at rest at the notch's home on the edge's screen, x into it from its edge, y down from its top: from
    /// the targets it moves to, never a frame it moves through.
    func resting(on edge: ScreenEdge) -> CGRect
    /// The middle of a session's row on the stage, while the shape shows it.
    func middle(of session: String, on edge: ScreenEdge, _ settings: EdgeSettings) -> CGPoint?
    /// Where the loop's pointer touches the shape and rests while it pours, lighting no session but this one.
    func home(of session: String, on edge: ScreenEdge) -> CGPoint
    func apply(_ settings: EdgeSettings, at time: Double, _ edge: ScreenEdge)
    func show(_ board: PanelBoard, at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings)
    /// One frame, the pointer where the stage puts it, drawn as the real edge draws it.
    func step(at time: Double, pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings)
    /// A click where the pointer is, taken as the real edge takes one.
    func press(at time: Double, pointer: CGPoint, _ edge: ScreenEdge, _ settings: EdgeSettings)
    /// The jump a click asked for answered, as the real edge hears it.
    func jumped(at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings)
    /// Its light alone, at this time, as the real notch redraws it while nothing else moves.
    func drawLight(at time: Double, _ settings: EdgeSettings)
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

    func resting(on edge: ScreenEdge) -> CGRect {
        run.map { $0.restingOutline(at: edge.stage.notchY).boundingBox } ?? .zero
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

    func home(of session: String, on edge: ScreenEdge) -> CGPoint { edge.notchHome }

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

    /// On a row, it presses in and asks for a jump, which the stage's run answers itself, as there is no one to jump.
    func press(at time: Double, pointer: CGPoint, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        guard let run else {
            return
        }

        _ = run.press(Self.moment(time, pointer, edge, settings), mayJump: true)
        draw(run, edge, settings)
    }

    /// The row pressed in drains the panel, as Ghostty's window comes forward.
    func jumped(at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        guard let run else {
            return
        }

        run.jumpAnswered(Self.moment(time, nil, edge, settings))
        draw(run, edge, settings)
    }

    /// Whether the panel is out: internal only for the tests.
    var isOut: Bool { run?.isOut ?? false }

    func drawLight(at time: Double, _ settings: EdgeSettings) {
        if let run {
            notch.drawLight(run, at: run.lightTime(time), reducesMotion: Displays.reducesMotion(settings))
        }
    }

    func pace(at time: Double, _ settings: EdgeSettings) -> StagePace {
        guard let run else {
            return .still
        }
        if run.frame.isMoving || run.isFolding(at: time) {
            return .moving
        }

        let lightMoves = run.lightMoves(at: run.lightTime(time), reducesMotion: Displays.reducesMotion(settings))

        return lightMoves ? .light : .still
    }

    /// Nothing to tell of what it showed: the stage has no window to save a crossing for, nor a caption.
    private func draw(_ run: NotchRun, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        _ = run.takeShown()
        notch.draw(run, in: Self.setting(edge, settings), mirror: edge.mirror)
    }

    private static func moment(
        _ time: Double, _ pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings
    ) -> NotchRun.Moment {
        NotchRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: setting(edge, settings))
    }

    private static func setting(_ edge: ScreenEdge, _ settings: EdgeSettings) -> NotchRun.Setting {
        .on(edge, settings, period: .never)
    }
}

/// The strip on the stage.
@MainActor
final class StageStrip: StageShape {
    private let strip = StripSurface()
    private var run: StripRun?

    var surface: NSView { strip }

    func window(on edge: ScreenEdge) -> CGRect { edge.stripWindow }

    /// Its resting width at the notch's home, as the real strip places its callout, however far it has grown.
    func resting(on edge: ScreenEdge) -> CGRect {
        CGRect(x: 0, y: edge.stage.notchY, width: Strip.restingWidth, height: 0)
    }

    /// The strip has no panel: the pointer rests on its mark (`home`).
    func middle(of session: String, on edge: ScreenEdge, _ settings: EdgeSettings) -> CGPoint? {
        nil
    }

    /// On the session's mark, so only its own tab pours: every point along the marks is near enough one to pour it.
    func home(of session: String, on edge: ScreenEdge) -> CGPoint {
        run?.frame.marks.first { $0.key == .session(session) }?.centre ?? edge.notchHome
    }

    func apply(_ settings: EdgeSettings, at time: Double, _ edge: ScreenEdge) {
        strip.material = settings.material
        if let run {
            run.place(settings, Self.moment(time, nil, edge, settings))
        } else {
            run = StripRun(at: time, in: .on(edge, settings), settings, measure: StripWordsLayer.measure)
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

    /// The strip has no row to press: its loop's pointer rests on the notch's place, and Ghostty comes forward alone.
    func press(at time: Double, pointer: CGPoint, _ edge: ScreenEdge, _ settings: EdgeSettings) {}

    func jumped(at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings) {}

    /// The strip's marks light with their frames: no light of its own.
    func drawLight(at time: Double, _ settings: EdgeSettings) {}

    func pace(at time: Double, _ settings: EdgeSettings) -> StagePace {
        run?.frame.isMoving == true ? .moving : .still
    }

    /// Nothing to tell of what it showed: the stage has no window to save a crossing for, nor a caption.
    private func draw(_ run: StripRun, _ edge: ScreenEdge, _ settings: EdgeSettings) {
        _ = run.takeShown()
        strip.draw(run, in: .on(edge, settings), mirror: edge.stripMirror)
    }

    private static func moment(
        _ time: Double, _ pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings
    ) -> StripRun.Moment {
        StripRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: .on(edge, settings))
    }
}

/// No edge, at Nothing: an empty surface, which nothing moves or lights.
@MainActor
final class StageNoEdge: StageShape {
    let surface = NSView()

    func window(on edge: ScreenEdge) -> CGRect { .zero }

    func resting(on edge: ScreenEdge) -> CGRect { .zero }

    func middle(of session: String, on edge: ScreenEdge, _ settings: EdgeSettings) -> CGPoint? { nil }

    func home(of session: String, on edge: ScreenEdge) -> CGPoint { edge.notchHome }

    func apply(_ settings: EdgeSettings, at time: Double, _ edge: ScreenEdge) {}

    func show(_ board: PanelBoard, at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings) {}

    func step(at time: Double, pointer: CGPoint?, _ edge: ScreenEdge, _ settings: EdgeSettings) {}

    func press(at time: Double, pointer: CGPoint, _ edge: ScreenEdge, _ settings: EdgeSettings) {}

    func jumped(at time: Double, _ edge: ScreenEdge, _ settings: EdgeSettings) {}

    func drawLight(at time: Double, _ settings: EdgeSettings) {}

    func pace(at time: Double, _ settings: EdgeSettings) -> StagePace { .still }
}

private extension ScreenEdge {
    /// On the notch at its home, in the panel's side padding as it pours, which no row covers.
    var notchHome: CGPoint { CGPoint(x: 4, y: stage.notchY) }
}
