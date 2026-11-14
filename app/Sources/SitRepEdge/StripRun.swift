import CoreGraphics
import Foundation
import SitRepPanel

/// The strip as the controller runs it, with nothing of the screen in it: the model, the board it shows and what its
/// tabs say of it, the sections Lee folded, shared with the card, the frames and the clock they run on, and what a
/// press let go means. Every input reaches the model through here, and each first brings it up to the input's moment,
/// so it takes its time from the clock, and a click lands on the strip as it is drawn. The controller draws what this
/// has, and paces its frames.
public final class StripRun: Framed {
    /// What the strip runs in, as it stands at each frame.
    public struct Setting: Equatable, Sendable {
        public var stage: StripStage
        public var reducesMotion: Bool

        public init(stage: StripStage, reducesMotion: Bool) {
            self.stage = stage
            self.reducesMotion = reducesMotion
        }
    }

    public typealias Moment = RunMoment<Setting>
    public typealias Shown = RunShown
    public typealias Drop = RunDrop

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
    private let said: Said
    private var book: RunBook
    /// What Lee folded, the card's setting as well.
    private let folding: Folding
    /// Where the last right-click asked what is under it (`target`), and whether its menu shows (`menuOpened`).
    private var menu: (at: CGPoint, isOpen: Bool)?
    /// The calendar a session's menu words its snooze times on.
    public let calendar: Calendar

    /// A pointer let go off the strip's screen, which lands on nothing.
    private static let offStage = CGPoint(x: -1, y: -1)

    /// The strip at its length, Max and place along the edge, its sections folded as `folding` has them, its tabs'
    /// words measured as the drawing sets them, saying what the board's note says, its menus' snooze times worded in
    /// the Gregorian calendar in the Mac's time zone, followed as it changes (`WakeTime.calendar`).
    public init(
        at time: Double, in setting: Setting, _ settings: EdgeSettings, folding: Folding = Folding(),
        calendar: Calendar = WakeTime.calendar, measure: (@escaping () -> StripNote) -> StripMeasure
    ) {
        let input = Self.input(at: time, pointer: nil, setting), said = Said()

        self.said = said
        self.folding = folding
        self.calendar = calendar
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
    /// where a menu was opened while it shows, what the drawing must show once latched.
    public func step(_ moment: Moment) {
        let time = book.clock(moment.time), held = menu.flatMap { $0.isOpen ? $0.at : nil }
        var input = Self.input(at: time, pointer: held ?? moment.pointer, moment.setting)

        input.pointerAt = held == nil ? moment.pointerAt : nil
        strip.folded = folding.folds.sections
        frame = strip.frame(input)
        latch(frame, at: time)
    }

    /// Hidden, the strip's time ran on: the sections as folded on the card meanwhile, it is taken on to now
    /// (`Strip.runOn`), the pointer away, and the frame after shows it.
    public func catchUp(_ moment: Moment) {
        let from = time, to = book.clock(moment.time)

        let input = { (time: Double) in Self.input(at: time, pointer: nil, moment.setting) }

        strip.folded = folding.folds.sections
        frame = strip.runOn(from: from, to: to, input) { latch($1, at: $0) }
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
        let note = StripNote(board), reworded = note != said.note

        upToNow(moment)
        said.note = note
        self.board = board
        strip.show(
            board.cardSessions, new: board.new, stopped: board.newTurns, pulses: board.pulses, reworded: reworded
        )
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
        return moment.pointer.flatMap(strip.target)
    }

    /// The menu asked for showing: until it closes, the strip holds as if the pointer rested where the right-click
    /// asked (`target`), wherever it goes on the menu, so a tab out stays out and nothing re-sorts under a choice made
    /// on it.
    public func menuOpened() {
        menu?.isOpen = true
    }

    /// The menu closed: the pointer is where it is again.
    public func menuClosed() {
        menu = nil
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

    /// A press at the pointer, on the strip as it is now, which moved may become a drag.
    public func press(_ moment: Moment) {
        upToNow(moment)
        if let point = moment.pointer {
            strip.press(at: point)
        }
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

    /// A click anywhere off the strip and its tab: a tab out draws back.
    public func clickElsewhere(_ moment: Moment) {
        upToNow(moment)
        strip.clickElsewhere()
    }

    /// The jump a click asked for answered: its spin ends now.
    public func jumpAnswered(_ moment: Moment) {
        upToNow(moment)
        strip.jumpAnswered()
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

    /// When, after this wall time, the time or a wake's countdown on a tab out next reads differently; nil with none,
    /// and while the board is stale, its times as of then.
    public func nextAgeChange(after now: Double) -> Double? {
        guard note.asOf == nil else {
            return nil
        }

        return frame.tabs.flatMap(\.words).compactMap { $0.changes(after: now) }.min()
    }

    /// A click on a session: its jump, or an away one carried on.
    private func jump(_ session: Session) -> Release {
        .jump(session, to: session.id, click: book.click())
    }

    private static func input(at time: Double, pointer: CGPoint?, _ setting: Setting) -> StripInput {
        StripInput(time: time, pointer: pointer, stage: setting.stage, reducesMotion: setting.reducesMotion)
    }
}

/// What the tabs say of the board as last heard: the model's measure reads it as a tab pours, so it is held apart
/// from the run, which the model is made inside.
private final class Said {
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
