import CoreGraphics
import Foundation

/// The strip, ported from its prototype (strip.html) at Lee's choices: the bezel grown into a 36pt black strip on the
/// screen's edge that never shuts, every session a mark on it in the panel's order, and a mark under the pointer
/// pouring its panel row out of the strip as a tab. At Grows it is only as long as its marks need, centred where the
/// notch sits, and with nothing running it draws back into the notch at rest; at Full it runs the screen's height.
/// The view feeds it a frame at a time and draws what each gives back, as it does a notch. Its coordinates are the
/// edge's own: x into the screen from its edge, y down from its top.
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

    let feel: StripFeel
    /// Every session on the strip, in the order they came.
    public private(set) var sessions: [Session]

    var t = 0.0
    var now: Double
    var stage: StripStage
    var reducesMotion: Bool
    let measure: StripMeasure
    var sp: Vec?
    var trail = Trail()
    var timers = SimTimers<Strip, StripTimer>()

    /// The marks' order on the strip: the panel's order as of the last sort, new needs you put in, ...
    var display: [String] = []
    /// ... those of them on the needs you side of the hairline, as of then, ...
    var needsSlot: Set<String> = []
    /// ... and where each mark goes, from that order.
    var layout = StripLayout()
    var marks: [StripMark] = []
    /// The grey count in the last place, when there are too many; and needs you's own, when its asks pass its room.
    var more: StripMark?
    var moreNeeds: StripMark?
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
    /// A press on the strip, where along the edge and with the strip centred where, and whether it became a drag.
    var press: (y0: Double, centre: Double, moved: Bool)?
    var dragging = false

    /// The hairline under needs you, and how much of it shows.
    var hair = Spring(0)
    var hairOp = Spring(0)
    /// Under reduced motion, a black cross-fading out from where it was, and since when.
    var fade: (outline: CGPath, t0: Double)?

    /// At Lee's feel, from its first frame's input.
    public convenience init(
        length: StripLength, maxLength: StripMax, sessions: [Session], measure: StripMeasure, _ input: StripInput
    ) {
        self.init(feel: .lees, length: length, maxLength: maxLength, sessions: sessions, measure: measure, input)
    }

    init(
        feel: StripFeel, length: StripLength, maxLength: StripMax, sessions: [Session], measure: StripMeasure,
        _ input: StripInput
    ) {
        self.feel = feel
        self.length = length
        self.maxLength = maxLength
        self.sessions = sessions
        self.measure = measure
        stage = input.stage
        reducesMotion = input.reducesMotion
        now = input.time
        yt = Spring(input.stage.menu)
        centre = clampCentre(stage.height * Tuning.notchAt)

        display = Session.sorted(sessions).map(\.id)
        needsSlot = Set(sessions.filter { $0.kind == .needs }.map(\.id))
        sessions.forEach { _ = markOf($0) }
        relayout(snapAll: true)
        hairOp.snap(layout.hair != nil ? 1 : 0)
    }

    /// One frame: the view's news since the last, then the prototype's frame loop, in its order.
    public func frame(_ input: StripInput) -> StripFrame {
        let dt = min(50, max(0, input.time - now))
        now = input.time
        take(input)
        t += dt
        runTimers()
        updateHover()
        for key in [\Strip.hair, \.hairOp, \.yt, \.yb, \.drawnIn] {
            self[keyPath: key].step(dt)
        }
        for mark in marks + counts {
            mark.step(dt)
        }
        for tab in tabs {
            tab.step(dt)
        }
        stepTabs()
        return render()
    }

    /// What changed since the last frame, before the sim clock moves on: the screen, reduced motion, and the pointer,
    /// held to the screen, which carries a drag.
    private func take(_ input: StripInput) {
        reducesMotion = input.reducesMotion
        if input.stage != stage {
            stage = input.stage
            centre = clampCentre(centre)
            relayout(snapAll: true)
            hair.snap(hair.target)
            for count in counts {
                count.y.snap(count.y.target)
            }
        }
        let p = input.pointer.map { Vec(clamp($0.x, 0.5, stage.width - 0.5), clamp($0.y, 0, stage.height)) }
        guard p != sp else {
            return
        }

        sp = p
        if let p {
            trail.add(p, at: now)
            drag(to: p.y)
        }
    }

    /// The counts there are, the grey one first.
    var counts: [StripMark] { [more, moreNeeds].compactMap(\.self) }

    /// A new ask: its needs you moves in at once, pointer or not, and its ring flashes, or its count's.
    public func newAsk(_ session: Session) {
        sessions.append(session)
        insertNeeds(session)
    }

    /// Sessions that aren't asks, come all at once as the prototype's Too many brings them: the marks re-sort at once,
    /// and the new ones fade and grow in where they land, unless they land in the count.
    public func add(_ new: [Session]) {
        sessions += new
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

    /// A session changed: it shows in place, and moves once the pointer has been off the strip for Settle.
    public func change(_ session: Session) {
        guard let i = sessions.firstIndex(where: { $0.id == session.id }) else {
            return
        }

        sessions[i] = session
        changed(session)
    }

    /// Sessions that have ended: their marks fade where they are and the rest close up.
    public func remove(_ ids: [String]) {
        let gone = Set(ids).intersection(sessions.map(\.id))
        if !gone.isEmpty {
            sessions.removeAll { gone.contains($0.id) }
            leave(gone)
        }
    }

    /// A click anywhere off the strip and its tab draws the tab back at once.
    public func clickElsewhere() {
        if let live = liveTab(), live.phase == .open {
            drawBack(live)
        }
    }

    func session(_ id: String) -> Session? {
        sessions.first { $0.id == id }
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
    case session(String)
    /// The grey count, of your turn and working past their places, ...
    case more
    /// ... and needs you's own orange one, of the newest asks past its.
    case moreNeeds
    case empty

    public var isCount: Bool { self == .more || self == .moreNeeds }
}

/// A click jumping, for the spin's 450ms: from a tab, to its session or one of a count's, or from a mark whose tab
/// wasn't out.
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

    /// A tab drawing back, by its id.
    static func draw(_ tab: Int) -> Self { Self(rawValue: "draw:\(tab)") }
}

extension Strip: SimModel {}
