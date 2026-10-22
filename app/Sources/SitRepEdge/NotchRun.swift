import CoreGraphics
import Foundation
import SitRepPanel

/// What the panel lists: its head, where it has one, and its items laid out, in the order the model has them.
public struct PanelList: Equatable, Sendable {
    public var head: Head?
    public var content: Content

    public init(head: Head?, content: Content) {
        self.head = head
        self.content = content
    }

    /// The item at an index, while there is one.
    public func item(_ index: Int) -> Item? {
        content.entries.indices.contains(index) ? content.entries[index].item : nil
    }
}

/// The notch as the controller runs it, with nothing of the screen in it: the model in the style Lee chose, the
/// board's rows held and folding into the panel's sections, the frames and the clock they run on, the scroll, a drag,
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
        /// How long a your-turn row stays before it folds into "N earlier".
        public var period: FoldPeriod

        public init(
            stage: Stage, mirror: CGAffineTransform, style: NotchStyle, reducesMotion: Bool, period: FoldPeriod = .hour
        ) {
            self.stage = stage
            self.mirror = mirror
            self.style = style
            self.reducesMotion = reducesMotion
            self.period = period
        }
    }

    public typealias Moment = RunMoment<Setting>
    public typealias Shown = RunShown
    public typealias Drop = RunDrop


    /// What a press on the notch comes to.
    public enum Press: Equatable, Sendable {
        /// A row that jumps, pressed in: its session, the session to jump to, and which click it is.
        case jump(Session, to: String, click: Int)
        /// A row's button in its time's place (`Opener`), away or not: the session to open in the SitRep window.
        case open(String)
        /// An eyebrow or "N earlier": what it folds folded or unfolded, at once (`folded`).
        case fold
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
    /// The sections Lee folded, kept as they change, by a click or an arrival unfolding Needs you; and whether "N
    /// earlier" is open, which is never kept, and closes each time the panel comes out or the line goes.
    public private(set) var folded: CardFolds {
        didSet {
            if folded.sections != oldValue.sections {
                kept?.save(CardSettings(folded: folded.sections))
            }
        }
    }

    /// Where the sections folded are kept across opens and launches; none, they are not.
    private let kept: SavedSettings<CardSettings>?
    /// The light's own clock, apart from the frames': the latest it was drawn at.
    private var lit: Double
    private var rows = HeldRows()
    private var style: NotchStyle
    private var folds = Folds()
    private var asks = AskClock()
    private var book: RunBook
    /// Whether the panel was out at the last frame.
    private var wasOut = false
    /// The wall clock, ms, against which a your-turn row passes the fold period, and the calendar its days are in.
    private let wall: () -> Double
    private let calendar: Calendar
    /// What the list was last laid out from, which its folds are told apart from, and when on the wall clock a
    /// your-turn row it shows next passes the fold period.
    private var laid: Laid
    private var nextRefold: Double?

    /// The sections folded as kept, if they are, against this wall clock, ms, its days in the Mac's own calendar,
    /// followed as its time zone changes.
    public init(
        at time: Double, in setting: Setting, kept: SavedSettings<CardSettings>? = nil,
        wall: @escaping () -> Double = { Date().timeIntervalSince1970 * 1000 },
        calendar: Calendar = .autoupdatingCurrent
    ) {
        book = RunBook(at: time)
        lit = time
        style = setting.style
        self.kept = kept
        folded = CardFolds(sections: kept?.read().folded ?? [])
        laid = Laid(rows: [], folds: folded, now: wall(), period: setting.period)
        self.wall = wall
        self.calendar = calendar
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
    /// order once the panel is in, a your-turn row folding into "N earlier" as it passes the fold period, or all of
    /// them as the period changes, the notch Lee chose once it is at rest, and the scroll kept inside the content.
    public func step(_ moment: Moment) {
        let time = book.clock(moment.time), setting = moment.setting

        list.content = folds.content(at: time, headed: list.head != nil)

        var input = Self.input(at: time, pointer: moment.pointer, needsLee: board.needsLee, list, setting)

        input.pointerAt = moment.pointerAt
        frame = notch.frame(input)
        seen = moment.pointer
        latch(frame, at: time)
        if hold(notch.phase != .closed) || refolds(by: setting.period) {
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
    /// folding away. An arrival unfolds Needs you, at once.
    public func show(_ board: PanelBoard, _ moment: Moment) -> Set<String> {
        upToNow(moment)
        board.tell(notch, after: self.board)
        self.board = board
        rows.take(board.sessions)

        if !board.new.isEmpty {
            folded.sections.remove(.needsYou)
        }
        relist(at: time, in: moment.setting)
        return isOut ? Set(board.sessions.filter { board.new.contains($0.id) }.map { Item.session($0).key }) : []
    }

    /// A press at the pointer. The model takes a frame first, so the row under the press and the row it presses in
    /// are found in the one list, the list as drawn, even when the board changed it since the model's last frame. On
    /// a row's button in its time's place, its session opens in the SitRep window; on a row that jumps, while jumps
    /// may run, the model presses it in; on an eyebrow or "N earlier", what it folds folds or unfolds; anywhere else on
    /// the black, a drag may begin, unless the notch is still crossing to the other edge.
    public func press(_ moment: Moment, mayJump: Bool) -> Press? {
        upToNow(moment)
        guard let point = moment.pointer else {
            return nil
        }

        if let index = item(at: point, in: moment.setting) {
            if let session = list.item(index)?.session, opens(index, at: point, in: moment.setting) {
                return .open(session.id)
            }
            return click(index, mayJump: mayJump, in: moment.setting)
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

    /// When, after this wall time, the first of the shown rows' times, or a wake's countdown, next reads differently,
    /// or a your-turn row folds into "N earlier"; nil with no rows.
    public func nextAgeChange(after now: Double) -> Double? {
        (rows.shown.map { $0.changes(after: now) } + [nextRefold].compactMap(\.self)).min()
    }

    /// How long before this time the last new ask was, ms; nil when there has been none.
    public func sinceAsk(at time: Double) -> Double? {
        asks.since(time)
    }

    /// The item a click at a point on the stage acts on, a row, an eyebrow or "N earlier", by its index in the list,
    /// while the panel shows it.
    public func item(at point: CGPoint, in setting: Setting) -> Int? {
        contentPoint(point, in: setting).flatMap(list.content.item(at:))
    }

    /// The session whose row is at a point on the stage, away or not, while the panel shows it: what a right-click
    /// there offers to open or jump to.
    public func session(at point: CGPoint, in setting: Setting) -> Session? {
        item(at: point, in: setting).flatMap { list.item($0)?.session }
    }

    /// A jump to a session's row chosen from its menu: as a click on the row, its row pressed in, while it still
    /// shows a row that jumps and jumps may run.
    public func jump(to session: String, _ moment: Moment, mayJump: Bool) -> Press? {
        upToNow(moment)
        let index = list.content.entries.indices.first { index in
            !list.content.entries[index].isGoing && list.item(index)?.session?.id == session
        }

        return index.flatMap { jump($0, mayJump: mayJump) }
    }

    /// A point on the stage in the content's own frame, while the panel shows it there.
    private func contentPoint(_ point: CGPoint, in setting: Setting) -> CGPoint? {
        guard let panel = frame.panel, panel.contains(point) else {
            return nil
        }

        return panel.contentPoint(point, mirror: setting.mirror, scroll: scroll)
    }

    /// Whether a point on the stage is on the button of the row at this index that opens its session.
    private func opens(_ index: Int, at point: CGPoint, in setting: Setting) -> Bool {
        contentPoint(point, in: setting).map { list.content.opens(index, at: $0) } ?? false
    }

    /// A click on an item: an eyebrow folds its section or unfolds it, "N earlier" opens or folds, each at once; a row
    /// jumps.
    private func click(_ index: Int, mayJump: Bool, in setting: Setting) -> Press? {
        switch list.item(index) {
        case let .eyebrow(eyebrow)?:
            folded.toggle(eyebrow.section)
        case .earlier?:
            folded.isEarlierOpen.toggle()
        default:
            return jump(index, mayJump: mayJump)
        }

        relist(at: time, in: setting)
        return .fold
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

    /// The panel out or in: from its coming out the rows keep their places, and "N earlier" is folded; as it goes in
    /// they take core's order. Whether it changed.
    private func hold(_ isOut: Bool) -> Bool {
        guard isOut != wasOut else {
            return false
        }

        wasOut = isOut
        rows.hold(isOut)
        if isOut {
            folded.isEarlierOpen = false
        }
        return true
    }

    /// Whether the list folds differently now: the period changed, or a your-turn row passed it.
    private func refolds(by period: FoldPeriod) -> Bool {
        period != laid.period || nextRefold.map { wall() >= $0 } == true
    }

    /// The rows as they show now in their sections, the your-turn rows past the fold period under "N earlier",
    /// folding in and out while the panel is out, to the model's next frame. What a fold changed, a section folding or
    /// unfolding, "N earlier" opening or closing, or rows passing the period or a new one, changes at once; every
    /// other row keeps its own motion, one folding away finishing and one arriving folding in. "N earlier" closes as
    /// it goes. The head shows only on a card with no rows, or while the board is stale, to say so; otherwise the
    /// eyebrows carry the counts.
    private func relist(at time: Double, in setting: Setting) {
        let next = Laid(rows: rows.shown, folds: folded, now: wall(), period: setting.period)
        let items = next.items(in: calendar)

        folds.take(
            items, at: time, animating: isOut, reducesMotion: setting.reducesMotion,
            atOnce: laid.refolded(to: next, in: calendar)
        )
        if !items.contains(where: { $0.key == "earlier" }) {
            folded.isEarlierOpen = false
        }
        laid = Laid(rows: next.rows, folds: folded, now: next.now, period: next.period)
        nextRefold = next.nextRefold(in: calendar)
        list.head = board.sessions.isEmpty || board.asOf != nil ? board.head : nil
        list.content = folds.content(at: time, headed: list.head != nil)
    }

    /// What the list is laid out from: its rows, and how they fold, by Lee's folds and the fold period at a time on
    /// the wall clock.
    private struct Laid {
        let rows: [Session]
        let folds: CardFolds
        let now: Double
        let period: FoldPeriod

        func items(in calendar: Calendar) -> [Item] {
            items(of: rows, in: calendar)
        }

        /// The keys of the items that fold differently from this to `next` over the same rows, the rows this had: what
        /// a fold changed, which changes at once. A row new with `next` is none of them, and folds in.
        func refolded(to next: Laid, in calendar: Calendar) -> Set<String> {
            let was = Set(items(of: rows, in: calendar).map(\.key))
            let now = Set(next.items(of: rows, in: calendar).map(\.key))

            return was.symmetricDifference(now)
        }

        /// When on the wall clock a your-turn row it shows next passes the period.
        func nextRefold(in calendar: Calendar) -> Double? {
            rows.filter { $0.section == .yourTurn && !isEarlier($0, in: calendar) }
                .compactMap { period.folds($0.since, in: calendar) }.min()
        }

        private func items(of rows: [Session], in calendar: Calendar) -> [Item] {
            Item.card(rows, folds: folds) { isEarlier($0, in: calendar) }
        }

        private func isEarlier(_ session: Session, in calendar: Calendar) -> Bool {
            period.isPast(session.since, at: now, in: calendar)
        }
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
