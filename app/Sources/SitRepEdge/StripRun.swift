import CoreGraphics
import SitRepPanel

/// The strip as the controller runs it, with nothing of the screen in it: the model, the board it shows and what its
/// tabs say of it, the frames and the clock they run on, and what a press let go means. Every input reaches the model
/// through here, and each first brings it up to the input's moment, so it takes its time from the clock, and a click
/// lands on the strip as it is drawn. The controller draws what this has, and paces its frames.
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

    /// A pointer let go off the strip's screen, which lands on nothing.
    private static let offStage = CGPoint(x: -1, y: -1)

    /// The strip at its length, Max and place along the edge, its tabs' words measured as the drawing sets them,
    /// saying what the board's note says.
    public init(
        at time: Double, in setting: Setting, _ settings: EdgeSettings,
        measure: (@escaping () -> StripNote) -> StripMeasure
    ) {
        let input = Self.input(at: time, pointer: nil, setting), said = Said()

        self.said = said
        book = RunBook(at: time)
        strip = Strip(
            length: settings.length, maxLength: settings.maxLength, along: settings.along, sessions: [],
            measure: measure { said.note }, input
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

    /// One frame: the model moved on with the pointer where it is, what the drawing must show once latched.
    public func step(_ moment: Moment) {
        let time = book.clock(moment.time)
        var input = Self.input(at: time, pointer: moment.pointer, moment.setting)

        input.pointerAt = moment.pointerAt
        frame = strip.frame(input)
        latch(frame, at: time)
    }

    /// Hidden, the strip's time ran on: it is taken on to now (`Strip.runOn`), the pointer away, and the frame after
    /// shows it.
    public func catchUp(_ moment: Moment) {
        let from = time, to = book.clock(moment.time)

        let input = { (time: Double) in Self.input(at: time, pointer: nil, moment.setting) }

        frame = strip.runOn(from: from, to: to, input) { latch($1, at: $0) }
    }

    /// What a frame at this time showed, for the drawing: the edge swapped, and the spin over for a click's jump.
    private func latch(_ frame: StripFrame, at time: Double) {
        book.latch(swapsEdge: frame.swapsEdge, drained: !frame.isJumping, at: time)
    }

    /// The board as `watch` last printed it: its rows, in core's order, become the marks, a needs you new on it
    /// flashing; while it is stale, the tabs say since when, an open one taking its new words as it does.
    public func show(_ board: PanelBoard, _ moment: Moment) {
        let note = StripNote(board), reworded = note != said.note

        upToNow(moment)
        said.note = note
        self.board = board
        strip.show(board.sessions, new: board.new, reworded: reworded)
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

    /// The press let go at the pointer, a drag with these settings: a click, while jumps may run, lands on the strip as
    /// it is now, the mark or row it presses in the one it jumps to; a drag leaves the strip where it took it, or on
    /// the other edge.
    public func release(_ settings: EdgeSettings, mayJump: Bool, _ moment: Moment) -> Release? {
        upToNow(moment)
        switch strip.release(at: moment.pointer ?? Self.offStage, clicks: mayJump) {
        case .nothing:
            return nil
        case let .jump(session):
            return jump(session)
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

    /// The count's row under the pointer as the last frame saw it, by its session, while its tab is out.
    public var hoverRow: String? {
        frame.pointer.flatMap { point in
            frame.tabs.first { $0.isLive && $0.key.isCount && $0.contains(point) }?.row(at: point)
        }
    }

    /// When, after this wall time, the time on a tab out next reads differently; nil with none, and while the board
    /// is stale, its times as of then.
    public func nextAgeChange(after now: Double) -> Double? {
        guard note.asOf == nil else {
            return nil
        }

        return frame.tabs.flatMap(\.words).compactMap(\.session).map { $0.ageChanges(after: now) }.min()
    }

    /// A click on a session: one no window holds ends its spin at once, as there is nowhere to jump.
    private func jump(_ session: Session) -> Release? {
        guard let target = board.jump(session) else {
            strip.jumpAnswered()
            return nil
        }

        return .jump(session, to: target, click: book.click())
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
    /// A session's row's session.
    var session: Session? {
        if case let .row(session) = content {
            return session
        }
        return nil
    }
}
