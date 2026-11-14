import CoreGraphics
import Foundation

/// The strip, ported from its prototype (strip.html) at Lee's choices: the bezel grown into a 36pt black strip on the
/// screen's edge that never shuts, every session a mark on it in the panel's order and its sections, Needs you, Working
/// and Snoozed, a hairline between each two, each section folded to one count as Lee folds it on the card or here, and
/// a mark under the pointer pouring its panel row out of the strip as a tab. At Grows it is only as long as its marks
/// need, centred where the notch sits, and with nothing running it draws back into the notch at rest; at Full it runs
/// the screen's height.
/// The view tells it the board as core orders it, feeds it a frame at a time and draws what each gives back, as it
/// does a notch. Core decides the marks and their order; the strip decides only how a change moves. Its coordinates
/// are the edge's own: x into the screen from its edge, y down from its top.
public final class Strip {
    /// Changing it changes the strip's shape at once: any tab goes, and the marks slide to their new places; with
    /// nothing running, the strip goes into the notch at rest or out of it.
    public var length: StripLength {
        didSet {
            if length != oldValue {
                display.isEmpty ? relayout() : relayoutShape()
            }
        }
    }

    /// Max, which only Grows heeds: changing it changes the strip's shape at once, as Length does.
    public var maxLength: StripMax {
        didSet {
            if maxLength != oldValue {
                relayoutShape()
            }
        }
    }

    /// The sections folded, each to its count in one place, the card's setting as well (14 November 2026): changing it
    /// lays the strip out again at once, the marks going into a count or coming out of it and those below sliding.
    public var folded: Set<BoardSection> {
        didSet {
            if folded != oldValue {
                relayout()
            }
        }
    }

    /// How far down the screen the strip centres at Grows, from 0 at its top to 1 at its bottom: the notch's place.
    /// Changing it moves the strip there, its marks sliding.
    public var along: Double {
        didSet {
            if along != oldValue {
                centre = clampCentre(stage.height * along)
                relayout()
            }
        }
    }

    let feel: StripFeel
    /// Every session on the strip, in core's order as last told.
    public private(set) var sessions: [Session]

    var t = 0.0
    var now: Double
    var stage: StripStage
    var reducesMotion: Bool
    let measure: StripMeasure
    var sp: Vec?
    var trail = Trail()
    var timers = SimTimers<Strip, StripTimer>()

    /// The marks' order on the strip, by their keys (`Session.markID`): the panel's order as of the last sort, new
    /// needs you put in, ...
    var display: [String] = []
    /// ... the section each of them sits in, as of then, ...
    var slot: [String: BoardSection] = [:]
    /// ... and where each mark goes, from that order.
    var layout = StripLayout()
    var marks: [StripMark] = []
    /// Each section's count, past its room or folded.
    var counts: [BoardSection: StripMark] = [:]
    var tabs: [StripTab] = []
    /// The tabs as last drawn, which a click is hit-tested against, and the strip's black.
    var lastTabs: [StripFrame.Tab] = []
    var lastStrip: CGPath?
    var serial = 0

    /// Grows: where along the edge the strip centres, the notch's place unless it has been dragged.
    var centre = 0.0
    /// The strip's ends: where its top S leaves the screen's edge, and its bottom S; and, with nothing running at
    /// Grows, how far it has drawn back into the notch at rest, 0 to 1.
    var yt: Spring
    var yb = Spring(0)
    var drawnIn = Spring(0)
    /// Crossing to the other edge: the strip's depth, draining into this edge and growing out of the other, and its
    /// marks fading out and back; ...
    var sw = Spring(StripTuning.width)
    var mvis = Spring(1)
    /// ... while it crosses, ...
    var crossing = false
    /// ... and from this frame on the other edge.
    var swapsEdge = false

    /// The mark under the pointer, or the open tab's.
    var hot: MarkKey?
    /// The pointer on the strip or its tab.
    var over = false
    /// A mark just jumped to: no tab again until the pointer leaves it.
    var disarmed: MarkKey?
    /// A change shown in place, waiting to move.
    var pendingSort = false
    /// Marks sliding under a tab that keeps with its mark.
    var freeze = false
    var jumping: Jumping?
    /// A press on the strip, from the strip's centre along the edge, which may become a drag.
    var press: NotchDrag?
    /// A press on an open tab, which only clicks.
    var pressesTab = false
    var dragging = false

    /// The hairline over each section after the first showing, by the section under it, and how much of it shows.
    var hairs = Dictionary(uniqueKeysWithValues: StripLayout.hairlined.map { ($0, StripHair()) })
    /// Under reduced motion, a black cross-fading out from where it was, and since when.
    var fade: (outline: CGPath, t0: Double)?

    /// At Lee's feel, from its first frame's input, its sessions in core's order, these sections folded.
    public convenience init(
        length: StripLength, maxLength: StripMax, along: Double, folded: Set<BoardSection> = BoardSection.foldedAtFirst,
        sessions: [Session], measure: StripMeasure, _ input: StripInput
    ) {
        self.init(
            feel: .lees, length: length, maxLength: maxLength, along: along, folded: folded, sessions: sessions,
            measure: measure, input
        )
    }

    init(
        feel: StripFeel, length: StripLength, maxLength: StripMax, along: Double = Tuning.notchAt,
        folded: Set<BoardSection> = BoardSection.foldedAtFirst, sessions: [Session], measure: StripMeasure,
        _ input: StripInput
    ) {
        self.feel = feel
        self.length = length
        self.maxLength = maxLength
        self.folded = folded
        self.along = along
        self.sessions = sessions
        self.measure = measure
        stage = input.stage
        reducesMotion = input.reducesMotion
        now = input.time
        yt = Spring(input.stage.menu)
        centre = clampCentre(stage.height * along)

        takeOrder()
        sessions.forEach { _ = markOf($0) }
        relayout(snapAll: true)
        for section in StripLayout.hairlined {
            hairs[section]?.op.snap(layout.hairs[section] != nil ? 1 : 0)
        }
    }

    /// One frame: the view's news since the last, then the prototype's frame loop, in its order.
    public func frame(_ input: StripInput) -> StripFrame {
        let dt = min(50, max(0, input.time - now))
        trail.frame(at: input.time, after: now)
        now = input.time
        take(input)
        t += dt
        runTimers()
        updateHover()
        for key in [\Strip.yt, \.yb, \.drawnIn, \.sw, \.mvis] {
            self[keyPath: key].step(dt)
        }
        for section in StripLayout.hairlined {
            hairs[section]?.step(dt)
        }
        for mark in marks + countMarks {
            mark.step(dt)
        }
        for tab in tabs {
            tab.step(dt)
        }
        stepTabs()
        return render()
    }

    /// Its time run on while nothing showed it, as over a full-screen app, from the last frame's time to now: a frame
    /// each 50ms, the pointer away, until nothing moves, so it shows at rest and plays nothing late, a new ask's flash
    /// among it. Each frame, with its time, goes to `each`, for what it shows once, as the edge swapping; its last is
    /// returned.
    public func runOn(
        from time: Double, to now: Double, _ input: (Double) -> StripInput,
        each: (Double, StripFrame) -> Void = { _, _ in }
    ) -> StripFrame {
        runningOn(from: time, to: now, frame: { frame(input($0)) }, each: each, isMoving: \.isMoving)
    }

    /// The press given up, as the strip hides with its mouse-up perhaps never to come: a drag puts the strip back
    /// where it began, saving nothing, and no click comes of it. Whether there was one.
    @discardableResult
    public func cancelPress() -> Bool {
        let onTab = pressesTab

        pressesTab = false
        guard let held = press else {
            return onTab
        }

        press = nil
        if held.isCarrying {
            dragging = false
            centre = clampCentre(stage.height * along)
            relayout()
        }
        return true
    }

    /// What changed since the last frame, before the sim clock moves on: the screen, reduced motion, and the pointer,
    /// held to the screen, which carries a drag.
    private func take(_ input: StripInput) {
        reducesMotion = input.reducesMotion
        if input.stage != stage {
            stage = input.stage
            centre = clampCentre(stage.height * along)
            relayout(snapAll: true)
            for section in StripLayout.hairlined {
                hairs[section]?.snapToPlace()
            }
            for count in countMarks {
                count.y.snap(count.y.target)
            }
        }
        let p = input.pointer.map { Vec(clamp($0.x, 0.5, stage.width - 0.5), clamp($0.y, 0, stage.height)) }
        guard p != sp else {
            return
        }

        sp = p
        if let p {
            trail.add(p, at: input.pointerTime)
            drag(to: p)
        }
    }

    /// The counts there are, in their sections' order.
    var countMarks: [StripMark] { BoardSection.allCases.compactMap { counts[$0] } }

    /// The board's sessions, in the panel's order, those of them arriving, holding a line new on it that needs Lee,
    /// and those it moved into Lee's turn (`stopped`):
    /// - one gone fades where it is, and the rest close up;
    /// - one changed shows in place, and moves once the pointer has been off the strip for Settle, as one whose asks
    ///   were answered, or whose turn ended, does;
    /// - one arriving off the needs you side, new to the strip or already on it, moves in at once, pointer or not; one
    ///   arriving on the needs you side stays where it is;
    /// - one stopping, moved into Lee's turn from working or on its own work, moves in at once too, or stays where it
    ///   is when it is on the needs you side still, its turn's end come before the re-sort; one back at a turn whose
    ///   end it stood at before, so not stopping anew, moves in at once all the same, unflashed;
    /// - each arriving or stopping flashes its ring, or its count's, only where Lee has that pulse on (`pulses`), as
    ///   the notch pulses: a new ask washed too;
    /// - any other new to the strip comes in as the marks re-sort at once, unflashed: needs you with nothing new among
    ///   them, as on any run's first board;
    /// - one snoozed, or woken, its row in Snoozed coming as its row elsewhere goes or the other way round, keeps its
    ///   mark, which changes in place and moves as any change does.
    ///
    /// Its sessions are its rows, each a mark by its key (`Session.markID`), so a session with a row in Snoozed and
    /// another in Needs you or Working has two. `reworded`, what the tabs say of the board changed with it, as when it
    /// goes stale: each open tab that says it takes its new words. A tab takes them once, though its row changed too.
    public func show(
        _ board: [Session], new: Set<String>, stopped: Set<String> = [], pulses: Set<Need> = [.ask],
        reworded: Bool = false
    ) {
        let renamed = carry(into: board)
        let was = Dictionary(sessions.map { (renamed[$0.markID] ?? $0.markID, $0) }) { first, _ in first }
        let gone = Set(was.keys).subtracting(board.map(\.markID))
        let fresh = board.filter { was[$0.markID] == nil }
        let arriving = board.filter { $0.needsLee && new.contains($0.id) }
        let stopping = board.filter { $0.kind == .turn && stopped.contains($0.id) }
        let ask = StripArrival(.ask, pulses: pulses), stop = StripArrival(.turn, pulses: pulses)
        let asks = arriving.filter { slot[$0.markID] != .needsYou }
        let stops = board.filter { session in
            session.kind == .turn && slot[session.markID] != .needsYou
                && (was[session.markID] != nil || stopped.contains(session.id))
        }
        let moving = asks.map { (session: $0, how: ask) }
            + stops.map { (session: $0, how: stopped.contains($0.id) ? stop : .quiet) }
        let crossing = moving.map(\.session).filter { was[$0.markID] != nil }
        let changes = board.filter { session in was[session.markID].map { $0 != session } ?? false }

        sessions = board
        if !renamed.isEmpty {
            relayout()
        }
        if !gone.isEmpty {
            leave(gone)
        }
        lift(crossing)
        moving.forEach { insertNeeds($0.session, $0.how) }
        // after them all, as one may fold another in that has shown its arrival on its own mark
        moving.filter { layout.rest(of: .needsYou).contains($0.session.markID) }.forEach {
            landInCount($0.session, $0.how)
        }
        arriving.filter { !asks.contains($0) }.forEach { flashInPlace($0, ask) }
        stopping.filter { !stops.contains($0) }.forEach { flashInPlace($0, stop) }
        changes.filter { !crossing.contains($0) }.forEach(changed)
        let others = fresh.filter { session in !moving.contains { $0.session == session } }
        if !others.isEmpty {
            add(others)
        }

        let rewords = reworded ? tabsSayingTheBoard : tabs.filter { tab in
            tab.phase == .open && changes.contains { tab.key == .session($0.markID) }
        }
        rewords.forEach(reword)
    }

    /// Sessions this board snoozes or wakes, each one's row in Snoozed come as its row elsewhere goes, or the other way
    /// round: its mark keeps its place, and everything that knows it by its key takes the new row's. The keys renamed,
    /// each to its new one.
    private func carry(into board: [Session]) -> [String: String] {
        let onStrip = Set(sessions.map(\.markID)), onBoard = Set(board.map(\.markID))
        var renamed: [String: String] = [:]

        for session in board where !onStrip.contains(session.markID) {
            let other = Session.markID(of: session.id, snoozed: !session.isSnoozed)

            if onStrip.contains(other), !onBoard.contains(other) {
                rekey(other, to: session.markID)
                renamed[other] = session.markID
            }
        }
        return renamed
    }

    /// A mark's key renamed: in the strip's order and its sections, on the mark, on any tab of it, under the pointer,
    /// jumping, and as a count's arrival.
    private func rekey(_ old: String, to new: String) {
        let was = MarkKey.session(old), now = MarkKey.session(new)

        display = display.map { $0 == old ? new : $0 }
        slot[new] = slot.removeValue(forKey: old)
        mark(was)?.key = now
        tabs.filter { $0.key == was }.forEach { $0.key = now }
        hot = hot == was ? now : hot
        disarmed = disarmed == was ? now : disarmed
        switch jumping {
        case let .tab(tab, id) where id == old: jumping = .tab(tab, new)
        case let .mark(key) where key == was: jumping = .mark(now)
        default: break
        }
        for count in counts.values where count.arrivalOf == old {
            count.arrivalOf = new
        }
    }

    /// Sessions new to the strip, all at once, as the prototype's Too many brings them: the marks re-sort at once, and
    /// the new ones fade and grow in where they land, unless they land in the count.
    private func add(_ new: [Session]) {
        let fresh = new.map(markOf)
        resort()
        for m in fresh where !m.folded {
            m.op.x = 0
            to(&m.op, 1, 220)
            if !reducesMotion {
                m.sc.x = 0.6
                springTo(&m.sc, 1, .arrive)
            }
        }
    }

    /// A click anywhere off the strip and its tab draws the tab back at once.
    public func clickElsewhere() {
        if let live = liveTab(), live.phase == .open {
            drawBack(live)
        }
    }

    /// The session whose mark goes by this key.
    func session(_ id: String) -> Session? {
        sessions.first { $0.markID == id }
    }

    /// A spring to a target in a duration, critically damped; under reduced motion never longer than 140ms.
    func to(_ spring: inout Spring, _ target: Double, _ dur: Double) {
        spring.to(target, reducesMotion ? min(dur, 140) : dur)
    }

    /// The same on an underdamped spring; under reduced motion, no spring: it is there.
    func springTo(_ spring: inout Spring, _ target: Double, _ kind: StripSpring) {
        if reducesMotion {
            spring.snap(target)
        } else {
            spring.springTo(target, feel.sp(kind))
        }
    }

    /// How far into the screen the strip reaches at rest, whatever its length, as what stands beside it is placed.
    public static let restingWidth = StripTuning.width

    /// How far into the screen the black can reach: the strip and its widest tab, overshooting as the springs that
    /// carry its depth do, and a few points spare.
    public static let depth: Double = {
        let overshoot = [StripSpring.pour, .width].map { overshootShare(StripFeel.lees.sp($0).damping) }.max() ?? 0
        return (StripTuning.width + StripTuning.tabMax * (1 + overshoot)).rounded(.up) + 4
    }()

    func nextSerial() -> Int {
        serial += 1
        return serial
    }
}

/// A mark on the strip, a session's or a count's; or, with nothing running, the notch at rest, whose tab says so.
public enum MarkKey: Hashable, Sendable {
    /// A session's row, by its mark's key (`Session.markID`).
    case session(String)
    /// A section's count: of those past its room, the end of its order, Needs you's stopped and then its away asks
    /// first; or, the section folded, all of them, in its one place.
    case count(BoardSection)
    case empty

    public var isCount: Bool { section != nil }

    /// A count's section.
    public var section: BoardSection? {
        if case let .count(section) = self {
            return section
        }
        return nil
    }
}

/// A click jumping, until its jump answers, 450ms at most: from a tab, to its session or one of a count's, or from a
/// mark whose tab wasn't out.
enum Jumping {
    case tab(StripTab, String)
    case mark(MarkKey)
}

/// A timer on the strip's sim clock, by the prototype's name for it.
struct StripTimer: RawRepresentable, Equatable {
    let rawValue: String

    static let dwell = Self(rawValue: "dwell")
    static let grace = Self(rawValue: "grace")
    static let settle = Self(rawValue: "settle")
    static let jumpGo = Self(rawValue: "jump:go")
    static let morph = Self(rawValue: "morph")
    static let crossSwap = Self(rawValue: "move:swap")
    static let crossDone = Self(rawValue: "move:done")

    /// A tab drawing back, by its id.
    static func draw(_ tab: Int) -> Self { Self(rawValue: "draw:\(tab)") }
}

extension Strip: SimModel {}
