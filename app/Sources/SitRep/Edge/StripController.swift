import AppKit
import SitRepCore
import SitRepEdge
import SitRepPanel

/// The strip on its display, in place of the notch when Lee chooses it: it runs the strip (`StripRun`), a frame per
/// display refresh with the pointer, the time and the board's rows in core's order as `watch` prints them, and draws
/// what each gives back. Frames run only while something moves: the strip, its marks and tabs, the ghost. A pointer
/// resting anywhere moves nothing; the mouse monitors wake the frames as it moves onto the strip or off it, or
/// anywhere while a tab is out, a press is held, or the strip has the pointer (`StripFrame.wakes`). While idle it costs
/// nothing, but for an open tab's time, drawn again as it changes. Whatever comes between frames, a board or Lee's
/// hand, goes to the run, which brings the strip up to now first; each is drawn, and frames show what it did. Its
/// window is click-through but over the strip, an open tab and the asks panel, and wide while the asks panel is open.
/// A right-click brings up the menu of what is under it (`StripMenu`).
@MainActor
final class StripController: NSObject, CalloutShape {
    /// A click on a mark or a tab: the session to jump to, and what to tell once the jump answers, whether it jumped.
    var onJump: (String, @escaping (JumpAnswer) -> Void) -> Void = { _, _ in }
    /// A session's menu's Snooze: the session, the asks its row showed, and the time chosen, or until it moves.
    var onSnooze: (String, [String], Date?) -> Void = { _, _, _ in }
    /// The asks panel's Snooze ▾: the session, the ask it shows, and the time chosen.
    var onSnoozeAsk: (String, String, Date) -> Void = { _, _, _ in }
    /// An answer's row, or Ignore, on the asks panel: the answer to hold; and the sending line's Undo.
    var onAnswer: (Answering) -> Void = { _ in }
    var onUndo: () -> Void = {}
    /// Snooze's choices as Lee set them, read as a session's menu opens.
    private let snoozeSettings: () -> SnoozeSettings
    /// Whether one ask's Snooze offers a time, for the asks panel's Snooze ▾.
    private var snoozeOffer = SnoozeOffer()
    /// A Snoozed session's menu's Wake now: the session.
    var onWake: (String) -> Void = { _ in }
    /// A drag let the strip go: the settings with its new place.
    var onMoved: (EdgeMove) -> Void = { _ in }
    /// Each frame drawn, with whether the pointer is over the strip, or a tab out.
    var onDrawn: ((_ isPointedAt: Bool) -> Void)?

    private var settings: EdgeSettings
    private var edge: ScreenEdge
    /// Its run: internal only for the tests, which read where it places the tab and the asks panel.
    let run: StripRun
    private let surface = StripSurface()
    /// Its window: internal only for the tests, which read that it stays on the screen.
    let window: EdgeWindow
    private var link: CADisplayLink?
    /// While frames are idle with a tab out, its time drawn again as it next changes.
    private var ages: Timer?
    /// A drag let go across the screen's middle: its settings, saved as the strip swaps edges.
    private var crossing: EdgeMove?
    private let ghost = GhostEdge()
    private let caption = CaptionWindow()
    private var monitors: [Any] = []
    /// Whether the window is wide, for the asks panel open beside a tab (`ScreenEdge.stripWindow(wide:)`).
    private var isWide = false

    /// On its display, its sections folded as `folding` has them, the card's setting as well, each session's Snooze
    /// offering what `snoozeSettings` gives as its menu opens.
    init(
        _ settings: EdgeSettings, on display: Display, folding: Folding,
        snoozeSettings: @escaping () -> SnoozeSettings
    ) {
        self.settings = settings
        self.snoozeSettings = snoozeSettings
        edge = ScreenEdge(display, settings)
        run = StripRun(
            at: Displays.now, in: .on(edge, settings), settings, folding: folding, asksMeasure: AsksMeasure.drawn,
            measure: StripWordsLayer.measure
        )
        window = EdgeWindow.onScreen(frame: edge.stripWindow, view: surface)
        super.init()

        surface.pointer = EdgePointer(
            pressed: { [unowned self] in press(at: $0) },
            dragged: { [unowned self] in drag(to: $0) },
            released: { [unowned self] in release() },
            scrolled: { [unowned self] in scroll($0) },
            menu: { [unowned self] in menu(at: $0) }
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
            window.isShown = isShown
            if isShown {
                run.catchUp(moment())
                wake()
            } else {
                endDrag()
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

    /// The settings and the display, as they stand: the edge and the place along it, the length and Max, and the
    /// motion, all at once.
    func apply(_ settings: EdgeSettings, on display: Display) {
        self.settings = settings
        edge = ScreenEdge(display, settings)
        window.setFrame(edge.stripWindow(wide: isWide), display: true)
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
            isShown: isShown, setting: setting
        )
    }

    /// What the run runs in: this edge as Lee set it, and whether one ask's Snooze offers a time now, as he set them.
    private var setting: StripRun.Setting {
        var setting = StripRun.Setting.on(edge, settings)

        setting.offersSnooze = snoozeOffer.offers(at: Date(), in: run.calendar, settings: snoozeSettings())
        return setting
    }

    @objc private func tick(_ link: CADisplayLink) {
        step(at: link.targetTimestamp * 1000)
    }

    /// One frame: the strip moved on to this time with the pointer where it is, drawn, and the frames paced. Internal
    /// only for the tests, which give the pointer on the stage.
    func step(at time: Double, pointer: CGPoint? = nil) {
        run.step(moment(at: time, pointer: pointer))
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

    /// The run's latest frame drawn, in the window widened for the asks panel while it is open: the edge it swapped to
    /// saved, the caption told the spin is over, and the frames paced.
    private func draw() {
        let time = run.time, shown = run.takeShown(), setting = setting

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
        let isPointedAt = run.frame.pointer.map(run.hits) ?? false

        window.takesClicks = run.isSwiping || isPointedAt
        onDrawn?(isPointedAt)
        pace(at: time)
    }

    /// The window wide while the asks panel is open beside a tab, and back to the strip's once it closes, a frame drawn
    /// through its mirror, as the notch's widens (`EdgeWindow.reframe`).
    private func widen(_ wide: Bool, drawing draw: (CGAffineTransform) -> Void) {
        guard wide != isWide else {
            return draw(edge.stripMirror(wide: isWide))
        }

        isWide = wide
        window.reframe(edge.stripWindow(wide: wide)) {
            draw(edge.stripMirror(wide: wide))
        }
    }

    /// The strip at rest, from the edge to its front, level with the notch's home, on the screen, for what stands
    /// beside it, as it would beside the notch: whatever its length, and however far it has grown.
    var restingBand: CGRect {
        edge.homeBand(reaching: Strip.restingWidth)
    }

    /// Frames run while something moves, or the way to the asks panel holds the pointer (`StripRun.needsFrames`);
    /// otherwise, with a tab out, a frame as its time next changes. Hidden, none.
    private func pace(at time: Double) {
        let ghosts = ghost.step(at: time)
        let running = isShown && (run.needsFrames || ghosts)

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

    /// A press: on the asks panel, an answer is held or taken back, its Snooze offers the snooze of the ask it shows,
    /// or its Open in Claude jumps; on the tab's arrow, the asks panel opens or closes; anywhere else on the strip, as
    /// it lets go (`StripRun.press`). Internal only for the tests.
    func press(at screenPoint: CGPoint) {
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
        case let .snooze(ask, of: session, at: pressed)?:
            snooze(ask, of: session, pressed: pressed)
        case .asks?, nil:
            break
        }
        took()
    }

    /// The asks panel's Snooze ▾: the times one ask's Snooze offers, under the button, the strip held as a session's
    /// menu holds it while it shows. A choice snoozes the ask it shows alone, and closes the asks panel.
    private func snooze(_ ask: String, of session: String, pressed: CGPoint) {
        guard let asks = run.asksShown, let button = asks.layout.snooze else {
            return
        }

        let drawn = asks.frame.applying(edge.stripMirror(wide: isWide))
        // the close drawn as the choice is made, whether AppKit performs it before `popUp` returns or after
        let menu = SnoozeMenu.forAsk(offering: snoozeSettings(), at: Date(), in: run.calendar) { [unowned self] until in
            onSnoozeAsk(session, ask, until)
            run.closeAsks(moment())
            took()
        }

        run.menuOpened(at: pressed)
        menu.popUp(
            positioning: nil, at: CGPoint(x: drawn.minX + button.minX, y: drawn.minY + button.maxY - menuBar),
            in: surface
        )
        run.menuClosed()
    }

    /// How far the strip's stage starts above its window, under the menu bar.
    private var menuBar: Double { edge.stripStage.menu }

    /// An answer's news, as the answers tell it: the asks panel shows it sending, as it was, or at the session's next
    /// ask.
    func heard(_ news: AnswerNews) {
        run.heard(news, moment())
        took()
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

    /// The press let go where the pointer is: a click jumps, in place of any jump under way, or opens a count's tab;
    /// and once the jump has jumped, the caption says where. A drag leaves the strip where it took it, saved, and
    /// across the screen's middle saved as it swaps edges.
    private func release() {
        switch run.release(settings, moment()) {
        case let .jump(session, to: target, click: click):
            jump(from: session, to: target, click: click)
        case let .dropped(dropped):
            ghost.dropped(across: dropped.isAcross)
            if dropped.isAcross {
                crossing = dropped.move
            } else {
                onMoved(dropped.move)
            }
        case nil:
            break
        }
        took()
    }

    /// A mark or a row pressed in jumps to its session; the caption says where once the jump has jumped.
    private func jump(from session: Session, to target: String, click: Int) {
        caption.jumping(to: session.project)
        onJump(target) { [weak self] in self?.answered($0, click: click) }
    }

    /// A right-click on a session's mark or row, or on a count: its menu (`StripMenu`), which holds the strip as it is
    /// while it shows. It jumps, snoozes or wakes the session, a snooze naming the asks its row showed, and folds its
    /// section, or unfolds it, here and on the card.
    private func menu(at screenPoint: CGPoint) -> NSMenu? {
        guard let point = edge.stagePoint(screenPoint), let target = run.target(moment(pointer: point)) else {
            return nil
        }

        let menu = menu(for: target)

        menu.delegate = self
        return menu
    }

    /// The menu of a session's mark or row, or of a count, opened now. Internal only for the tests, which open it.
    func menu(for target: StripTarget) -> NSMenu {
        StripMenu.make(
            for: target, at: Date(), in: run.calendar, offering: snoozeSettings(),
            row: { [unowned self] in rowActions(for: $0) },
            fold: { [unowned self] in fold($0, folded: $1) }
        )
    }

    /// A session's menu's choices, each for the session by its own id, in Snoozed or not: its jump goes to its mark as
    /// the strip has it when chosen, a board while the menu showed having snoozed or woken it maybe. Internal only for
    /// the tests, which choose them.
    func rowActions(for session: Session) -> RowMenu.Actions {
        let id = session.id

        return RowMenu.Actions(
            jump: { [unowned self] in jumpFromMenu(to: session) },
            snooze: { [unowned self] in onSnooze(id, $0, $1) },
            wake: { [unowned self] in onWake(id) }
        )
    }

    /// Jump to the window, as a click on the mark, or its row, would, the one the menu is for pressed in where it can
    /// be.
    private func jumpFromMenu(to session: Session) {
        if case let .jump(session, to: target, click: click) = run.jump(to: session, moment()) {
            jump(from: session, to: target, click: click)
        }
        took()
    }

    /// Collapse or Expand from a menu: at once, here and on the card.
    private func fold(_ section: BoardSection, folded isFolded: Bool) {
        run.fold(section, folded: isFolded, moment())
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

    /// The strip hidden mid-drag, its mouse-up perhaps never to come: the drag ends where it began, saving nothing,
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

    /// A swipe on the asks panel pages it; the wheel over an open count's tab scrolls its rows. Internal only for the
    /// tests, which give its time and the pointer on the stage.
    func scroll(_ scroll: Scroll, at time: Double = Displays.now, pointer: CGPoint? = nil) {
        run.scroll(scroll, moment(at: time, pointer: pointer))
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
        } else if window.takesClicks || run.frame.wakes(pointer: edge.stagePoint(NSEvent.mouseLocation)) {
            wake()
        }
    }
}

extension StripController: NSMenuDelegate {
    /// A menu showing holds the strip as if the pointer rested where it was asked for (`StripRun.menuOpened`).
    func menuWillOpen(_ menu: NSMenu) {
        run.menuOpened()
    }

    /// Closed, before any choice on it runs: the strip follows the pointer again, its grace starting from now.
    func menuDidClose(_ menu: NSMenu) {
        run.menuClosed()
        took()
    }
}
