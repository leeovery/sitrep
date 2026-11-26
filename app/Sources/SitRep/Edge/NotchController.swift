import AppKit
import SitRepCore
import SitRepEdge
import SitRepPanel

/// The notch on its display: it runs the notch (`NotchRun`), in the style Lee chose, a frame per display refresh with
/// the pointer, the time and the board's rows, and draws what each gives back. Frames run only while something moves:
/// the model, a row folding, the ghost, the asks panel's asks sliding. A pointer resting anywhere moves nothing; the
/// mouse monitors wake the frames as it moves near the notch, or anywhere while the panel is out (`Frame.wakes`).
/// While idle it costs nothing, but for the light, which breathes on a slow refresh of its own while something needs
/// Lee (under reduced motion it holds still, and the refresh runs only while a new ask brightens it), and the open
/// panel's times, drawn again as they change. Whatever comes between frames, a board, Lee's hand or a key the panel
/// holds, goes to the run, which brings the notch up to now first; each is drawn, and frames show what it did.
@MainActor
final class NotchController: NSObject, CalloutShape {
    /// A click on a row: the session to jump to, and what to tell once the jump answers, whether it jumped.
    var onJump: (String, @escaping (JumpAnswer) -> Void) -> Void = { _, _ in }
    /// A row's menu's Snooze: the session, the asks its row showed, and the time chosen, or until it moves.
    var onSnooze: (String, [String], Date?) -> Void = { _, _, _ in }
    /// The asks panel's Snooze ▾: the session, the ask it shows, and the time chosen.
    var onSnoozeAsk: (String, String, Date) -> Void = { _, _, _ in }
    /// Snooze's choices as Lee set them, read as a row's menu opens.
    private let snoozeSettings: () -> SnoozeSettings
    /// Whether one ask's Snooze offers a time, for the asks panel's Snooze ▾.
    private var snoozeOffer = SnoozeOffer()
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
    /// Its run: internal only for the tests, which read where it places the rows and the asks panel.
    let run: NotchRun
    /// Its window's content: internal only for the tests, which read where it draws.
    let surface = NotchSurface()
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
    private var monitors: [Any] = []
    /// Where on the stage the row's menu AppKit was last handed was asked for, which holds the card open once it
    /// shows.
    private var menuAt: CGPoint?
    /// Whether the window is wide, for the asks panel open beside the panel (`ScreenEdge.window(wide:)`).
    private var isWide = false
    /// The panel's keys: internal only for the tests, which read what its tap was told.
    let keys: NotchKeys

    /// The slow refresh the light breathes on while frames are idle.
    private static let lightRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)

    /// On its display, its card's sections folded as `folding` has them, its keys read through `keys`, each row's
    /// Snooze offering what `snoozeSettings` gives as its menu opens.
    init(
        _ settings: EdgeSettings, on display: Display, folding: Folding, keys: KeysMac,
        snoozeSettings: @escaping () -> SnoozeSettings
    ) {
        self.settings = settings
        self.snoozeSettings = snoozeSettings
        edge = ScreenEdge(display, settings)
        run = NotchRun(at: Displays.now, in: .on(edge, settings), folding: folding, measure: AsksMeasure.drawn)
        window = EdgeWindow.onScreen(frame: edge.window, view: surface)
        self.keys = NotchKeys(keys)
        super.init()

        surface.show(run.list)
        surface.pointer = EdgePointer(
            pressed: { [unowned self] in press(at: $0) },
            dragged: { [unowned self] in drag(to: $0) },
            released: { [unowned self] in release() },
            scrolled: { [unowned self] in scroll($0) },
            menu: { [unowned self] in menu(at: $0) }
        )
        caption.over = edge.visible
        link = startLink(#selector(tick))
        lightLink = startLink(#selector(tickLight), rate: Self.lightRate)
        self.keys.onKey = { [unowned self] in heard($0) }
        self.keys.onLetGo = { [unowned self] in letGoOfKeys(in: $0) }
        self.keys.onAway = { [unowned self] in letGoOfKeys() }
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
            followKeys()
        }
    }

    /// The board as `watch` last printed it. Its rows show at once while the panel is in, and keep their places while
    /// it is out; a row new on it swells the notch and, with the panel out, is washed; something needing Lee with
    /// nothing new, as on the first board, lights the notch with no swell.
    func show(_ board: PanelBoard) {
        let washes = run.show(board, moment())

        if !washes.isEmpty {
            surface.wash(washes, at: run.time)
        }
        took()
    }

    /// The settings and the display, as they stand: the edge and the place along it, and the motion at once, the style
    /// once the notch is at rest.
    func apply(_ settings: EdgeSettings, on display: Display) {
        self.settings = settings
        edge = ScreenEdge(display, settings)
        window.setFrame(edge.window(wide: isWide), display: true)
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
            isShown: isShown, setting: setting
        )
    }

    /// What the run runs in: this edge as Lee set it, whether one ask's Snooze offers a time now, as he set them, and
    /// whether the Mac lets the panel take keys.
    private var setting: NotchRun.Setting {
        var setting = NotchRun.Setting.on(edge, settings)

        setting.offersSnooze = snoozeOffer.offers(at: Date(), in: run.calendar, settings: snoozeSettings())
        setting.takesKeys = keys.allowed
        return setting
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

    /// One frame: the notch moved on to this time with the pointer where it is, drawn, and the clocks paced. Internal
    /// only for the tests, which give the pointer on the stage.
    func step(at time: Double, pointer: CGPoint? = nil) {
        run.step(moment(at: time, pointer: pointer))
        draw()
    }

    /// An input the run has taken: while frames run, the next one draws it, with whatever the frames between showed
    /// (`NotchRun.takeShown`); while they sleep, the frame it brought the notch up to is drawn, and frames start to
    /// show what it did. The keys are told what the panel holds at once either way, so a key after a jump goes to the
    /// window jumped to though no frame has drawn since.
    private func took() {
        if isShown, link?.isPaused == true {
            draw()
        } else {
            followKeys()
        }
        wake()
    }

    /// The run's latest frame drawn, in the window widened for the asks panel while it is open: the edge it swapped to
    /// saved, the caption told the panel drained, and the clocks paced.
    private func draw() {
        let time = run.time, pointer = run.seen
        let setting = setting, shown = run.takeShown()

        if shown.swappedEdge, let crossing {
            self.crossing = nil
            onMoved(crossing)
        }
        if let drained = shown.jumpDrained {
            caption.drained(at: drained)
        }
        widen(run.asksShown != nil) { mirror in
            surface.draw(run, in: setting, mirror: mirror)
        }

        let isPointedAt = pointer.map { run.hits($0) } ?? false

        window.takesClicks = run.drag != nil || run.isSwiping || isPointedAt
        onDrawn?(isPointedAt)
        pace(at: time)
        followKeys()
    }

    /// The keys told whether the panel is out, shown, and what it holds.
    private func followKeys() {
        keys.follow(isOut: isShown && run.phase != .closed, holding: run.keySnapshot)
    }

    /// The window wide while the asks panel is open beside the panel, and back to the panel's once it closes, a frame
    /// drawn through its mirror (`EdgeWindow.reframe`).
    private func widen(_ wide: Bool, drawing draw: (CGAffineTransform) -> Void) {
        guard wide != isWide else {
            return draw(edge.mirror(wide: isWide))
        }

        isWide = wide
        window.reframe(edge.window(wide: wide)) {
            draw(edge.mirror(wide: wide))
        }
    }

    /// The notch at rest at its home, from the edge to its front, on the screen, for what stands beside it: at the home
    /// the settings give, as the run may not have stepped there yet.
    var restingBand: CGRect {
        edge.homeBand(reaching: run.restingOutline(at: edge.stage.notchY).boundingBox.maxX)
    }

    private func drawLight(at time: Double) {
        surface.drawLight(run, at: time, reducesMotion: Displays.reducesMotion(settings))
    }

    /// Frames run while something moves, or the way to the asks panel holds the pointer (`NotchRun.needsFrames`);
    /// otherwise only the light's slow refresh, while it is lit and moves, and with the panel out, a frame as its times
    /// next change. Hidden, none.
    private func pace(at time: Double) {
        let ghosts = ghost.step(at: time)
        let running = isShown && (run.needsFrames(at: time) || ghosts)

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
    /// an answer is held or taken back, or its Snooze offers the snooze of the ask it shows; anywhere else on the
    /// black, it may become a drag (`NotchRun.press`). Internal only for the tests.
    func press(at screenPoint: CGPoint) {
        guard let point = edge.stagePoint(screenPoint) else {
            return
        }

        act(on: run.press(moment(pointer: point)))
        took()
    }

    /// A key of the set while the panel holds the keys: what it does, by the paths a click takes (`NotchRun.key`).
    /// Internal only for the tests, which give the pointer on the stage.
    func heard(_ key: PanelKey, pointer: CGPoint? = nil) {
        act(on: run.key(key, moment(pointer: pointer)))
        took()
    }

    /// A key the panel doesn't take went through, in the hold of this number: the panel holds none until the pointer
    /// moves again.
    private func letGoOfKeys(in hold: Int) {
        run.letGoOfKeys(in: hold, moment())
        took()
    }

    /// The screens slept or the session went to another user: the panel holds the keys no more, so what is typed on
    /// coming back goes to the window in front.
    private func letGoOfKeys() {
        run.letGoOfKeys(moment())
        took()
    }

    /// What a press or a key came to: a jump, an answer held or taken back, a snooze menu, an ask's or a row's, or a
    /// row's wake.
    private func act(on press: NotchRun.Press?) {
        switch press {
        case let .jump(session, to: target, click: click)?:
            jump(from: session, to: target, click: click)
        case let .answer(answering)?:
            onAnswer(answering)
        case .undo?:
            onUndo()
        case let .snooze(ask, of: session, at: pressed)?:
            snooze(ask, of: session, pressed: pressed)
        case let .snoozeRow(session, row: row)?:
            snooze(session, beside: row)
        case let .wake(session)?:
            onWake(session.id)
        case .fold?, .carry?, .asks?, nil:
            break
        }
    }

    /// The asks panel's Snooze ▾: the times one ask's Snooze offers, under the button. A choice snoozes the ask it
    /// shows alone, and closes the asks panel.
    private func snooze(_ ask: String, of session: String, pressed: CGPoint) {
        guard let asks = run.asksShown, let button = asks.layout.snooze else {
            return
        }

        let drawn = asks.frame.applying(edge.mirror(wide: isWide))
        // the close drawn as the choice is made, whether AppKit performs it before `popUp` returns or after
        let menu = SnoozeMenu.forAsk(offering: snoozeSettings(), at: Date(), in: run.calendar) { [unowned self] until in
            onSnoozeAsk(session, ask, until)
            run.closeAsks(moment())
            took()
        }

        show(menu, at: CGPoint(x: drawn.minX + button.minX, y: drawn.minY + button.maxY), holding: pressed)
    }

    /// `z` on a row: the row's Snooze times in a menu of their own, beside the row's end away from the edge, its top
    /// level with the row's, as the asks panel stands beside its row.
    private func snooze(_ session: Session, beside row: CGRect) {
        let menu = snoozeMenu(for: session), drawn = row.applying(edge.mirror(wide: isWide))
        let x = settings.edge == .left ? drawn.maxX : drawn.minX - menu.size.width

        show(menu, at: CGPoint(x: x, y: drawn.minY), holding: CGPoint(x: row.midX, y: row.midY))
    }

    /// The row's Snooze times for `session`, numbered, a choice snoozing it as the row's menu's Snooze does, naming
    /// the asks its row showed. Internal only for the tests, which choose from it.
    func snoozeMenu(for session: Session) -> SnoozeMenu {
        let id = session.id, asks = session.asks

        return SnoozeMenu.forRow(offering: snoozeSettings(), at: Date(), in: run.calendar) { [unowned self] in
            onSnooze(id, asks, $0)
        }
    }

    /// A snooze menu shown on its own at this point in the window, the card held open as if the pointer rested at
    /// `holding` on the stage, as the row's menu holds it, and its digits, `z`, `k` and `j` the tap's while it shows.
    private func show(_ menu: SnoozeMenu, at point: CGPoint, holding: CGPoint) {
        run.menuOpened(at: holding)
        drawHeld()
        keys.shows(menu)
        menu.popUp(positioning: nil, at: point, in: surface)
        keys.menuClosed()
        run.menuClosed()
        took()
    }

    /// The card as a menu holding it shows it, drawn before the menu tracks, so the asks panel's keycaps are gone as
    /// the menu's own digits show.
    private func drawHeld() {
        if isShown {
            draw()
        }
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
              let row = run.row(at: point, in: setting), let session = row.session
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

    /// A scroll: a swipe on the asks panel pages it; anywhere else on the panel, the list scrolls. Internal only for the
    /// tests, which give its time and the pointer on the stage.
    func scroll(_ scroll: Scroll, at time: Double = Displays.now, pointer: CGPoint? = nil) {
        run.scroll(scroll, moment(at: time, pointer: pointer))
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

        keys.pointerMoved()
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
    /// A row's menu showing holds the card open as if the pointer rested where it was opened (`NotchRun.menuOpened`),
    /// and keeps AppKit's keys alone.
    func menuWillOpen(_ menu: NSMenu) {
        if let menuAt {
            run.menuOpened(at: menuAt)
            drawHeld()
        }
        keys.showsRowMenu()
    }

    /// Closed, before any choice on it runs: the card follows the pointer again, its grace starting from now.
    func menuDidClose(_ menu: NSMenu) {
        menuAt = nil
        keys.menuClosed()
        run.menuClosed()
        took()
    }
}
