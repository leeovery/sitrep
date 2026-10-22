import CoreGraphics
import SitRepPanel

/// What the panel lists: its head, and its items laid out, in the order the model has them.
public struct PanelList: Equatable, Sendable {
    public var head: Head
    public var content: Content

    public init(head: Head, content: Content) {
        self.head = head
        self.content = content
    }

    /// The item at an index, while there is one.
    public func item(_ index: Int) -> Item? {
        content.entries.indices.contains(index) ? content.entries[index].item : nil
    }
}

/// The notch as the controller runs it, with nothing of the screen in it: the model in the style Lee chose, the
/// board's rows held and folding into the panel's list, the frames and the clock they run on, the scroll, a drag,
/// and what a press means. Every input reaches the model through here, and each first brings it up to the input's
/// moment, so it takes its time from the clock, and the row it finds is the row drawn. The controller draws what this
/// has, and paces its frames.
public final class NotchRun: Framed {
    /// What the notch runs in, as it stands at each frame.
    public struct Setting: Equatable, Sendable {
        public var stage: Stage
        /// The stage into the window: mirrored on the right edge.
        public var mirror: CGAffineTransform
        /// The notch Lee chose, which the model becomes once it is at rest.
        public var style: NotchStyle
        public var reducesMotion: Bool

        public init(stage: Stage, mirror: CGAffineTransform, style: NotchStyle, reducesMotion: Bool) {
            self.stage = stage
            self.mirror = mirror
            self.style = style
            self.reducesMotion = reducesMotion
        }
    }

    public typealias Moment = RunMoment<Setting>
    public typealias Shown = RunShown
    public typealias Drop = RunDrop


    /// What a press on the notch comes to.
    public enum Press: Equatable, Sendable {
        /// A row that jumps, pressed in: its session, the session to jump to, and which click it is.
        case jump(Session, to: String, click: Int)
        /// The black off a row, which a move makes a drag.
        case carry
    }

    /// The model: every input to it comes through the run, and what is drawn from it is read here. Internal only for
    /// the tests, which read the pointer's speed off it.
    private(set) var notch: any Notch
    public private(set) var board = PanelBoard()
    /// The panel's list as the model and the drawing have it.
    public private(set) var list: PanelList
    public private(set) var frame: Frame
    /// The pointer on the stage as the last frame saw it.
    public private(set) var seen: CGPoint?
    /// How far down the panel's content is scrolled.
    public private(set) var scroll = 0.0
    /// A press off a row, which a move makes a drag, until it lets go.
    public private(set) var drag: NotchDrag?
    /// The light's own clock, apart from the frames': the latest it was drawn at.
    private var lit: Double
    private var rows = HeldRows()
    private var style: NotchStyle
    private var folds = Folds()
    private var asks = AskClock()
    private var book: RunBook

    public init(at time: Double, in setting: Setting) {
        book = RunBook(at: time)
        lit = time
        style = setting.style
        list = PanelList(head: board.head, content: Content(laying: []))

        let input = Self.input(at: time, pointer: nil, needsLee: false, list, setting)

        notch = setting.style.notch(input)
        frame = notch.frame(input)
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

    public var phase: Phase { notch.phase }

    public var isOut: Bool { phase == .open || phase == .opening }

    /// The notch's home along the edge, its centre.
    public var notchY: Double { notch.notchY }

    /// How far from the edge a pointer by the notch counts as near it, for `Frame.wakes`.
    public var field: Double { notch.field }

    /// The notch at rest, its home this far down the stage: a drag's ghost on the other edge.
    public func restingOutline(at y: Double) -> CGPath {
        notch.restingOutline(at: y)
    }

    /// One frame: the list as it folds now, the model moved on with the pointer where it is, the rows taking core's
    /// order once the panel is in, the notch Lee chose once it is at rest, and the scroll kept inside the content.
    public func step(_ moment: Moment) {
        let time = book.clock(moment.time), setting = moment.setting

        list.content = folds.content(at: time)

        var input = Self.input(at: time, pointer: moment.pointer, needsLee: board.needsLee, list, setting)

        input.pointerAt = moment.pointerAt
        frame = notch.frame(input)
        seen = moment.pointer
        latch(frame, at: time)
        if rows.hold(notch.phase != .closed) {
            relist(at: time, in: setting)
        }
        restyle(input, to: setting.style)
        scroll = frame.panel.map { list.content.scrolled(scroll, by: 0, showing: $0.frame.height) } ?? 0
        asks.take(lastAsk: frame.light.lastAsk, simTime: frame.time, at: time)
    }

    /// Hidden, the notch's time ran on: it is taken on to now (`Notch.runOn`), the pointer away, and the frame after
    /// shows it.
    public func catchUp(_ moment: Moment) {
        let from = time, to = book.clock(moment.time)
        let input = { [board, list] (time: Double) in
            Self.input(at: time, pointer: nil, needsLee: board.needsLee, list, moment.setting)
        }

        frame = notch.runOn(from: from, to: to, input) { latch($1, at: $0) }
    }

    /// What a frame at this time showed, for the drawing: the edge swapped, and the panel going in for a click's jump.
    private func latch(_ frame: Frame, at time: Double) {
        book.latch(swapsEdge: frame.swapsEdge, drained: phase == .closing || phase == .closed, at: time)
    }

    /// The board as `watch` last printed it, told to the notch, its rows held while the panel is out: the items
    /// arriving on it to wash, by their keys, while the panel is out; never one a row crossing the hairline leaves,
    /// folding away.
    public func show(_ board: PanelBoard, _ moment: Moment) -> Set<String> {
        upToNow(moment)
        board.tell(notch, after: self.board)
        self.board = board
        rows.take(board.sessions)
        relist(at: time, in: moment.setting)
        return isOut ? Set(board.sessions.filter { board.new.contains($0.id) }.map { Item.session($0).key }) : []
    }

    /// A press at the pointer. The model takes a frame first, so the row under the press and the row it presses in
    /// are found in the one list, the list as drawn, even when the board changed it since the model's last frame. On
    /// a row that jumps, while jumps may run, the model presses it in; anywhere else on the black, a drag may begin,
    /// unless the notch is still crossing to the other edge.
    public func press(_ moment: Moment, mayJump: Bool) -> Press? {
        upToNow(moment)
        guard let point = moment.pointer else {
            return nil
        }

        if let index = row(at: point, in: moment.setting) {
            return jump(index, mayJump: mayJump)
        }
        guard frame.hits(point), notch.mayCarry else {
            return nil
        }

        drag = NotchDrag(at: point, home: notch.notchY)
        return .carry
    }

    /// The press moved to the pointer on a screen this wide: once it is a drag the panel closes and the notch lifts,
    /// and it follows the pointer along the edge. The drag as it now is.
    public func moved(width: Double, _ moment: Moment) -> NotchDrag? {
        upToNow(moment)
        guard var drag, let point = moment.pointer else {
            return drag
        }

        if drag.move(to: point, width: width) {
            notch.carry()
            drag.carries(from: notch.notchY)
        }
        if drag.isCarrying {
            notch.carried(to: drag.notchY)
        }
        self.drag = drag
        return drag
    }

    /// The press let go, on a screen this tall: a drag sets the notch down where it took it, or past the screen's
    /// middle, on the other edge. The settings with its new place, if it was a drag.
    public func release(_ settings: EdgeSettings, height: Double, _ moment: Moment) -> Drop? {
        upToNow(moment)
        defer { drag = nil }

        guard let drag, drag.isCarrying else {
            return nil
        }

        let dropped = drag.dropped(settings, at: notch.notchY, height: height)

        notch.drop(across: drag.isAcross)
        return Drop(move: dropped, isAcross: drag.isAcross)
    }

    /// The notch hidden mid-drag, its mouse-up perhaps never to come: the drag ends where it began, saving nothing.
    /// Whether there was one.
    public func endDrag(_ moment: Moment) -> Bool {
        upToNow(moment)
        guard let drag else {
            return false
        }

        self.drag = nil
        if drag.isCarrying {
            notch.carried(to: moment.setting.stage.notchY)
            notch.drop(across: false)
        }
        return true
    }

    /// A click anywhere off the panel and the notch: the panel closes at once.
    public func clickElsewhere(_ moment: Moment) {
        upToNow(moment)
        notch.clickElsewhere()
    }

    /// The jump a click asked for answered: a row still pressed in drains the panel now.
    public func jumpAnswered(_ moment: Moment) {
        upToNow(moment)
        notch.jumpAnswered()
    }

    /// The content scrolled this much further, inside its length.
    public func scroll(by delta: Double, _ moment: Moment) {
        upToNow(moment)
        if let panel = frame.panel {
            scroll = list.content.scrolled(scroll, by: delta, showing: panel.frame.height)
        }
    }

    /// The time the light draws at, from its own link's target or a frame's time: the latest of that, the run's time,
    /// and the last it was drawn at, so it never steps back. It is the light's own clock, apart from the frames':
    /// its refresh, up to one of its own ahead, never stamps the model's frames.
    public func lightTime(_ target: Double) -> Double {
        lit = max(lit, time, target)
        return lit
    }

    /// Whether a row still folds or fades in at this time.
    public func isFolding(at time: Double) -> Bool {
        folds.isMoving(at: time)
    }

    /// When, after this wall time, the first of the shown rows' times, or a wake's countdown, next reads differently; nil
    /// with no rows.
    public func nextAgeChange(after now: Double) -> Double? {
        rows.shown.map { $0.changes(after: now) }.min()
    }

    /// How long before this time the last new ask was, ms; nil when there has been none.
    public func sinceAsk(at time: Double) -> Double? {
        asks.since(time)
    }

    /// The row under a point on the stage, by its index in the list, while the panel shows it.
    public func row(at point: CGPoint, in setting: Setting) -> Int? {
        guard let panel = frame.panel, panel.contains(point) else {
            return nil
        }

        return list.content.row(at: panel.contentPoint(point, mirror: setting.mirror, scroll: scroll))
    }

    private func jump(_ index: Int, mayJump: Bool) -> Press? {
        let items = notch.items

        guard mayJump, items.indices.contains(index), let session = items[index].session,
              let target = board.jump(session), notch.clickRow(index)
        else {
            return nil
        }

        return .jump(session, to: target, click: book.click())
    }

    /// The rows as they show now, folding in and out while the panel is out, to the model's next frame.
    private func relist(at time: Double, in setting: Setting) {
        folds.take(Item.list(rows.shown), at: time, animating: isOut, reducesMotion: setting.reducesMotion)
        list.head = board.head
        list.content = folds.content(at: time)
    }

    /// Lee chose the other notch: an open panel closes first, and the notch changes once it is at rest.
    private func restyle(_ input: Input, to chosen: NotchStyle) {
        guard chosen != style else {
            return
        }

        if isOut {
            notch.clickElsewhere()
        } else if notch.phase == .closed, !frame.isMoving {
            style = chosen
            notch = style.notch(input)
            frame = notch.frame(input)
        }
    }

    private static func input(
        at time: Double, pointer: CGPoint?, needsLee: Bool, _ list: PanelList, _ setting: Setting
    ) -> Input {
        Input(
            time: time, pointer: pointer, needsLee: needsLee, stage: setting.stage, content: list.content,
            reducesMotion: setting.reducesMotion
        )
    }
}
