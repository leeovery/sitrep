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
/// board's rows held and folding into the panel's list, the frames and the clock they run on, the scroll, and what a
/// press on it means. The controller draws what this has, and paces its frames.
public final class NotchRun {
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

    /// What a press on the notch comes to.
    public enum Press: Equatable, Sendable {
        /// A row that jumps, pressed in: its session, the session to jump to, and which click it is.
        case jump(Session, to: String, click: Int)
        /// The black off a row, which a move makes a drag.
        case carry
    }

    public private(set) var notch: any Notch
    public private(set) var board = PanelBoard()
    public private(set) var rows = HeldRows()
    /// The panel's list as the model and the drawing have it.
    public private(set) var list: PanelList
    public private(set) var frame: Frame
    /// The display's clock, ms, as the run has it: it never goes back, though the display link's frames are stamped
    /// up to a refresh ahead of what happens between them.
    public private(set) var time: Double
    /// The pointer on the stage as the last frame saw it.
    public private(set) var seen: CGPoint?
    /// How far down the panel's content is scrolled.
    public private(set) var scroll = 0.0
    private var style: NotchStyle
    private var folds = Folds()
    private var asks = AskClock()
    /// How many rows' clicks have asked for a jump: the latest's answer is the one heard.
    private var clicks = 0

    public init(at time: Double, in setting: Setting) {
        self.time = time
        style = setting.style
        list = PanelList(head: board.head, content: Content(laying: []))

        let input = Self.input(at: time, pointer: nil, needsLee: false, list, setting)

        notch = setting.style.notch(input)
        frame = notch.frame(input)
    }

    /// The time on the run's clock: this time, or the latest already taken, if that is later.
    @discardableResult
    public func clock(_ time: Double) -> Double {
        self.time = max(self.time, time)
        return self.time
    }

    public var isOut: Bool { notch.phase == .open || notch.phase == .opening }

    /// One frame: the list as it folds now, the model moved on with the pointer where it is, the rows taking core's
    /// order once the panel is in, the notch Lee chose once it is at rest, and the scroll kept inside the content.
    public func step(at time: Double, pointer: CGPoint?, in setting: Setting) {
        let time = clock(time)

        list.content = folds.content(at: time)

        let input = Self.input(at: time, pointer: pointer, needsLee: board.needsLee, list, setting)

        frame = notch.frame(input)
        seen = pointer
        if rows.hold(notch.phase != .closed) {
            relist(at: time, in: setting)
        }
        restyle(input, to: setting.style)
        scroll = frame.panel.map { list.content.scrolled(scroll, by: 0, showing: $0.frame.height) } ?? 0
        asks.take(lastAsk: frame.light.lastAsk, simTime: frame.time, at: time)
    }

    /// Hidden, the notch's time ran on: it is taken on to now (`Notch.runOn`), and the frame after shows it.
    public func catchUp(to now: Double, in setting: Setting) {
        let from = time, to = clock(now)

        frame = notch.runOn(from: from, to: to) { [board, list] in
            Self.input(at: $0, pointer: nil, needsLee: board.needsLee, list, setting)
        }
    }

    /// The board as `watch` last printed it, told to the notch, its rows held while the panel is out: the rows new
    /// on it to wash, while the panel is out.
    public func show(_ board: PanelBoard, at time: Double, in setting: Setting) -> Set<String> {
        board.tell(notch, after: self.board)
        self.board = board
        rows.take(board.sessions)
        relist(at: clock(time), in: setting)
        return isOut ? board.new : []
    }

    /// Whether a row still folds or fades in at this time.
    public func folds(at time: Double) -> Bool {
        folds.isMoving(at: time)
    }

    /// How long before this time the last new ask was, ms; nil when there has been none.
    public func sinceAsk(at time: Double) -> Double? {
        asks.since(time)
    }

    /// The content scrolled this much further, inside its length.
    public func scroll(by delta: Double) {
        if let panel = frame.panel {
            scroll = list.content.scrolled(scroll, by: delta, showing: panel.frame.height)
        }
    }

    /// The row under a point on the stage, by its index in the list, while the panel shows it.
    public func row(at point: CGPoint, in setting: Setting) -> Int? {
        guard let panel = frame.panel, panel.contains(point) else {
            return nil
        }

        return list.content.row(at: panel.contentPoint(point, mirror: setting.mirror, scroll: scroll))
    }

    /// A press at a point on the stage, at this time. The model takes a frame first, so the row under the press and
    /// the row it presses in are found in the one list, the list as drawn, even when the board changed it since the
    /// model's last frame. On a row that jumps, while jumps may run, the model presses it in; anywhere else on the
    /// black, a drag may begin, unless the notch is still crossing to the other edge.
    public func press(at point: CGPoint, time: Double, in setting: Setting, mayJump: Bool) -> Press? {
        step(at: time, pointer: point, in: setting)
        if let index = row(at: point, in: setting) {
            return jump(index, mayJump: mayJump)
        }
        return frame.hits(point) && notch.mayCarry ? .carry : nil
    }

    /// Whether this click is the latest: an answer to an earlier one changes nothing.
    public func isLatest(_ click: Int) -> Bool {
        click == clicks
    }

    private func jump(_ index: Int, mayJump: Bool) -> Press? {
        let items = notch.items

        guard mayJump, items.indices.contains(index), let session = items[index].session,
              let target = board.jump(session), notch.clickRow(index)
        else {
            return nil
        }

        clicks += 1
        return .jump(session, to: target, click: clicks)
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
