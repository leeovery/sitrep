import CoreGraphics
import Foundation
import SitRepCore
import SitRepPanel

/// The strip as the controller runs it, with nothing of the screen in it: the model, the board it shows and what its
/// tabs say of it, the sections Lee folded, shared with the card, the frames and the clock they run on, the asks panel
/// beside its tab, and what a press, and a press let go, mean. Every input reaches the model through here, and each
/// first brings it up to the input's moment, so it takes its time from the clock, and a click lands on the strip as it
/// is drawn. The controller draws what this has, and paces its frames.
public final class StripRun: Framed {
    /// What the strip runs in, as it stands at each frame.
    public struct Setting: Equatable, Sendable {
        public var stage: StripStage
        public var reducesMotion: Bool
        /// The stage into the window: mirrored on the right edge. Only its flip matters here, as for the notch's
        /// (`NotchRun.Setting.mirror`): every point read through it is taken from what is drawn through the same one.
        public var mirror: CGAffineTransform
        /// Whether one ask's Snooze offers a time now, as Lee set them: the asks panel's foot shows Snooze ▾ only
        /// while it does.
        public var offersSnooze: Bool

        public init(
            stage: StripStage, reducesMotion: Bool, mirror: CGAffineTransform = .identity, offersSnooze: Bool = true
        ) {
            self.stage = stage
            self.reducesMotion = reducesMotion
            self.mirror = mirror
            self.offersSnooze = offersSnooze
        }
    }

    public typealias Moment = RunMoment<Setting>
    public typealias Shown = RunShown
    public typealias Drop = RunDrop

    /// What a press on the asks panel or a tab's arrow comes to, at once: the rest of the strip waits for the press to
    /// let go (`release`).
    public enum Press: Equatable, Sendable {
        /// What the asks panel shows changed, and nothing else: the tab's arrow opened it or closed it; a click on the
        /// strip or the tab closed it; or a page dot paged it.
        case asks
        /// An answer's row, or Ignore, on the asks panel: the answer to hold.
        case answer(Answering)
        /// The sending line's Undo: the answer held taken back.
        case undo
        /// Snooze ▾ on the asks panel: the ask it shows, by its id, and its session's, to snooze from a menu at this
        /// point on the stage.
        case snooze(ask: String, of: String, at: CGPoint)
        /// Open in Claude, as a click on the tab: its session, the session to jump to, and which click it is.
        case jump(Session, to: String, click: Int)
    }

    /// What a press let go comes to.
    public enum Release: Equatable, Sendable {
        /// A click that jumps, its mark or row pressed in: its session, the session to jump to, and which click it is.
        case jump(Session, to: String, click: Int)
        case dropped(Drop)
    }

    /// The model: every input to it comes through the run, and what is drawn from it is read here. Internal only for
    /// the tests, which read the pointer's speed and the layout off it.
    private(set) var strip: Strip
    public private(set) var board = PanelBoard()
    public private(set) var frame: StripFrame
    /// What the tabs say of the board, which the asks panel's answers change too (`renote`).
    let said: Said
    private var book: RunBook
    /// What Lee folded, the card's setting as well.
    private let folding: Folding
    /// Where the last right-click asked what is under it (`target`), and whether its menu shows (`menuOpened`).
    private var menu: (at: CGPoint, isOpen: Bool)?
    /// The calendar a session's menu words its snooze times on.
    public let calendar: Calendar
    /// The asks panel beside the tab: where it is open, the answer held, the asks answered, and how its words are set.
    var asking: AsksPanel

    /// A pointer let go off the strip's screen, which lands on nothing.
    private static let offStage = CGPoint(x: -1, y: -1)

    /// The strip at its length, Max and place along the edge, its sections folded as `folding` has them, its tabs'
    /// words measured as the drawing sets them, saying what the board's note says, its menus' snooze times worded in
    /// the Gregorian calendar in the Mac's time zone, followed as it changes (`WakeTime.calendar`).
    public init(
        at time: Double, in setting: Setting, _ settings: EdgeSettings, folding: Folding = Folding(),
        calendar: Calendar = WakeTime.calendar, asksMeasure: AsksMeasure = .estimated,
        measure: (@escaping () -> StripNote) -> StripMeasure
    ) {
        let input = Self.input(at: time, pointer: nil, setting), said = Said()

        self.said = said
        self.folding = folding
        self.calendar = calendar
        asking = AsksPanel(measure: asksMeasure)
        book = RunBook(at: time)
        strip = Strip(
            length: settings.length, maxLength: settings.maxLength, along: settings.along,
            folded: folding.folds.sections, sessions: [], measure: measure { said.note }, input
        )
        frame = strip.frame(input)
    }

    /// The display's clock, ms, as the frames and what comes between them have it: it never goes back.
    public var time: Double { book.time }

    /// Whether this click is the latest: an answer to an earlier one changes nothing.
    public func isLatest(_ click: Int) -> Bool {
        book.isLatest(click)
    }

    /// What frames have shown since this was last asked, for the drawing to show once.
    public func takeShown() -> Shown {
        book.takeShown()
    }

    /// What the tabs say of the board as last heard.
    public var note: StripNote { said.note }

    /// A press moved into a drag, which carries the strip till it lets go.
    public var isDragging: Bool { strip.isDragging }

    /// While a drag carries the strip, whether letting go takes it to the other edge.
    public var isAcross: Bool { strip.isAcross }

    /// One frame: the sections as folded on the card meanwhile, the model moved on with the pointer where it is, or
    /// where a menu was opened while it shows, the asks panel and the way to it counting as the tab, what the drawing
    /// must show once latched, and the asks panel placed beside the tab.
    public func step(_ moment: Moment) {
        let time = book.clock(moment.time), held = menu.flatMap { $0.isOpen ? $0.at : nil }
        let pointer = held ?? moment.pointer
        var input = Self.input(at: time, pointer: pointer, moment.setting)

        input.pointerAt = held == nil ? moment.pointerAt : nil
        input.beside = asking.beside(pointer, onList: pointer.map(frame.covers) ?? false, at: time)
        strip.folded = folding.folds.sections
        frame = strip.frame(input)
        latch(frame, at: time)
        placeAsks(in: moment.setting)
    }

    /// Hidden, the strip's time ran on: the sections as folded on the card meanwhile, it is taken on to now
    /// (`Strip.runOn`), the pointer away, and the frame after shows it.
    public func catchUp(_ moment: Moment) {
        let from = time, to = book.clock(moment.time)

        let input = { (time: Double) in Self.input(at: time, pointer: nil, moment.setting) }

        strip.folded = folding.folds.sections
        frame = strip.runOn(from: from, to: to, input) { latch($1, at: $0) }
        placeAsks(in: moment.setting)
    }

    /// What a frame at this time showed, for the drawing: the edge swapped, and the spin over for a click's jump.
    private func latch(_ frame: StripFrame, at time: Double) {
        book.latch(swapsEdge: frame.swapsEdge, drained: !frame.isJumping, at: time)
    }

    /// The board as `watch` last printed it: its rows, in the panel's order, Snoozed's last, the card's, become the
    /// marks, a needs you new on it and a session it moved into Lee's turn each flashing where Lee has that pulse on,
    /// as the notch's pulse does; while it is stale, the tabs say since when, an open one taking its new words as it
    /// does.
    public func show(_ board: PanelBoard, _ moment: Moment) {
        upToNow(moment)
        self.board = board
        asking.take(board)

        let (was, arrows) = renote()

        strip.show(
            board.cardSessions, new: board.new, stopped: board.newTurns, pulses: board.pulses,
            reworded: !note.saysAlike(was), rewording: arrows
        )
        placeAsks(in: moment.setting)
    }

    /// A section folded, or unfolded, from a menu on the strip: at once, here and on the card.
    public func fold(_ section: BoardSection, folded isFolded: Bool, _ moment: Moment) {
        upToNow(moment)
        set(section, folded: isFolded)
    }

    /// A fold set where both surfaces read it, and on the strip at once: the one place either changes.
    private func set(_ section: BoardSection, folded isFolded: Bool) {
        folding.set(section, folded: isFolded)
        strip.folded = folding.folds.sections
    }

    /// What a right-click at the pointer offers a menu for, on the strip as it is now (`Strip.target`); the point it
    /// asked at is where the strip holds while the menu shows (`menuOpened`).
    public func target(_ moment: Moment) -> StripTarget? {
        upToNow(moment)
        menu = moment.pointer.map { (at: $0, isOpen: false) }
        return moment.pointer.flatMap { asking.isOn($0) ? nil : strip.target(at: $0) }
    }

    /// The menu asked for showing: until it closes, the strip holds as if the pointer rested where the right-click
    /// asked (`target`), wherever it goes on the menu, its hover held on what it was on (`Strip.holdHover`), so a tab
    /// out stays out, no other pours, and nothing re-sorts under a choice made on it.
    public func menuOpened() {
        menu?.isOpen = true
        strip.holdHover()
    }

    /// A menu opened from a press at a point on the stage, as the asks panel's Snooze ▾ opens its own: the strip holds
    /// as if the pointer rested there until it closes (`menuOpened()`).
    public func menuOpened(at point: CGPoint) {
        menu = (at: point, isOpen: true)
        strip.holdHover()
    }

    /// The menu closed: the pointer is where it is again.
    public func menuClosed() {
        menu = nil
        strip.releaseHover()
    }

    /// A jump chosen from a session's menu, the session as the menu had it: as a click on its tab or its mark as the
    /// strip has them now, a board while the menu showed having snoozed or woken it maybe; the jump goes though
    /// nothing presses in, another jump spinning or the session gone from the strip (`Strip.jump`).
    public func jump(to session: Session, _ moment: Moment) -> Release {
        upToNow(moment)
        return jump(strip.jump(to: session))
    }

    /// Where a session's own mark is going on the strip, by the mark's key, while it has a place of its own
    /// (`Strip.markTarget`).
    public func markTarget(ofMark key: String) -> CGPoint? {
        strip.markTarget(ofMark: key)
    }

    /// Lee's settings for the strip: its length, Max, and where along the edge it sits.
    public func place(_ settings: EdgeSettings, _ moment: Moment) {
        upToNow(moment)
        strip.length = settings.length
        strip.maxLength = settings.maxLength
        strip.along = settings.along
    }

    /// A press at the pointer, on the strip as it is now. On the asks panel, what it is on there (`pressAsks`); on the
    /// tab's arrow, the asks panel opens beside the tab, or, open beside it, closes; anywhere else on the strip or the
    /// tab while the asks panel is open, it closes, and nothing else, the press letting go on nothing: no jump, no drag.
    /// Else on the strip, which moved may become a drag, or an open tab, which clicks as it lets go.
    @discardableResult
    public func press(_ moment: Moment) -> Press? {
        upToNow(moment)
        guard let point = moment.pointer else {
            return nil
        }
        defer { placeAsks(in: moment.setting) }

        if asking.isOn(point) {
            return pressAsks(at: point, in: moment.setting)
        }
        if let row = arrow(at: point, in: moment.setting) {
            toggleAsks(row)
            return .asks
        }
        if asking.row != nil, frame.covers(point) {
            asking.close()
            return .asks
        }
        strip.press(at: point)
        return nil
    }

    /// The press moved to the pointer: the model's frame then carries the strip with it.
    public func moved(_ moment: Moment) {
        upToNow(moment)
    }

    /// The press let go at the pointer, a drag with these settings: a click, whatever jump runs, as the latest click
    /// wins, lands on the strip as it is now, the mark or row it presses in the one it jumps to, or a section folded
    /// unfolding, here and on the card; a drag leaves the strip where it took it, or on the other edge.
    public func release(_ settings: EdgeSettings, _ moment: Moment) -> Release? {
        upToNow(moment)
        switch strip.release(at: moment.pointer ?? Self.offStage) {
        case .nothing:
            return nil
        case let .jump(session):
            return jump(session)
        case let .unfold(section):
            set(section, folded: false)
            return nil
        case let .dropped(along, across):
            return .dropped(Drop(move: settings.dropped(along: along, across: across), isAcross: across))
        }
    }

    /// The strip hidden mid-drag, its mouse-up perhaps never to come: the drag ends where it began, saving nothing.
    /// Whether a press was held.
    public func endDrag(_ moment: Moment) -> Bool {
        upToNow(moment)
        return strip.cancelPress()
    }

    /// A click anywhere off the strip, its tab and the asks panel: a tab out draws back, and the asks panel closes with
    /// it.
    public func clickElsewhere(_ moment: Moment) {
        upToNow(moment)
        strip.clickElsewhere()
        asking.close()
        placeAsks(in: moment.setting)
    }

    /// The jump a click asked for answered: its spin ends now.
    public func jumpAnswered(_ moment: Moment) {
        upToNow(moment)
        strip.jumpAnswered()
    }

    /// A scroll: over the asks panel, or in a swipe across it under way, a horizontal swipe pages it
    /// (`AsksPanel.takes`, `AsksPanel.swiped`); anywhere else, an open count's tab scrolled down by it (`scroll(by:)`).
    public func scroll(_ scroll: Scroll, _ moment: Moment) {
        guard asking.takes(scroll, at: moment.pointer, reducesMotion: moment.setting.reducesMotion) else {
            return self.scroll(by: scroll.down, moment)
        }

        upToNow(moment)
        asking.swiped(scroll, at: time, tabRows, board, reducesMotion: moment.setting.reducesMotion)
        placeAsks(in: moment.setting)
    }

    /// The wheel over an open count's tab scrolls its rows this much further.
    public func scroll(by delta: Double, _ moment: Moment) {
        upToNow(moment)
        if let point = moment.pointer {
            strip.scroll(by: delta, at: point)
        }
    }

    /// The count's row under the pointer as the last frame saw it, by its mark's key (`Session.markID`), while its tab
    /// is out.
    public var hoverRow: String? {
        frame.pointer.flatMap { point in
            frame.tabs.first { $0.isLive && $0.key.isCount && $0.contains(point) }?.row(at: point)
        }
    }

    /// When, after this wall time, the time or a wake's countdown on a tab out, or the asks panel's ask's age, next
    /// reads differently; nil with none, and while the board is stale, the tabs' times as of then.
    public func nextAgeChange(after now: Double) -> Double? {
        let asked = asking.shown.map { $0.ask.ageChanges(after: now) }

        guard note.asOf == nil else {
            return asked
        }

        return (frame.tabs.flatMap(\.words).compactMap { $0.changes(after: now) } + [asked].compactMap { $0 }).min()
    }

    /// Whether frames must keep coming at this time, though the pointer is still: the strip moves, the way to the asks
    /// panel holds the pointer, which a rest or its time ends with no move (`SafeTriangle`), or its asks slide, under
    /// the fingers or settling (`AsksSlide`).
    public var needsFrames: Bool {
        frame.isMoving || asking.needsFrames
    }

    /// A click on a session: its jump, or an away one carried on.
    private func jump(_ session: Session) -> Release {
        .jump(session, to: session.id, click: book.click())
    }

    /// Open in Claude on the asks panel, for the session of the tab it opened beside: the asks panel closes, and the
    /// jump goes as a click on the tab, which presses in (`Strip.jump`).
    func open(_ row: String) -> Press? {
        guard let session = tabRows.session(ofRow: row) else {
            return nil
        }

        let jumping = strip.jump(to: session)

        asking.close()
        return .jump(jumping, to: jumping.id, click: book.click())
    }

    private static func input(at time: Double, pointer: CGPoint?, _ setting: Setting) -> StripInput {
        StripInput(time: time, pointer: pointer, stage: setting.stage, reducesMotion: setting.reducesMotion)
    }
}

/// What the tabs say of the board as last heard: the model's measure reads it as a tab pours, so it is held apart
/// from the run, which the model is made inside.
final class Said {
    var note = StripNote()
}

private extension StripFrame.Words {
    /// When after this wall time they next read differently: a session's row's time or its wake's countdown; a count's
    /// rows' countdowns, as they show no time; nil with neither.
    func changes(after now: Double) -> Double? {
        switch content {
        case let .row(session): session.changes(after: now)
        case let .rows(sessions): sessions.compactMap { $0.countdownChanges(after: now) }.min()
        case .idle: nil
        }
    }
}
