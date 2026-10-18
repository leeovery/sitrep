import CoreGraphics
import Foundation

/// The strip, ported from its prototype (strip.html) at Lee's choices: the bezel grown into a 36pt black strip down the
/// screen's edge that never shuts, every session a mark on it in the panel's order, and a mark under the pointer
/// pouring its panel row out of the strip as a tab. The view feeds it a frame at a time and draws what each gives
/// back, as it does a notch. Its coordinates are the edge's own: x into the screen from its edge, y down from its top.
public final class Strip {
    public var settings: StripSettings
    /// Every session on the strip, in the order they came.
    public private(set) var sessions: [StripSession]

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
    /// The count in the last place, when there are too many.
    var more: StripMark?
    var tabs: [StripTab] = []
    /// The tabs as last drawn, which a click is hit-tested against.
    var lastTabs: [StripFrame.Tab] = []
    var serial = 0

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

    /// Give way: how deep under the menu bar the top end reaches, 28 at rest.
    var give = Spring(StripTuning.topEnd)
    /// The hairline under needs you, and how much of it shows.
    var hair = Spring(0)
    var hairOp = Spring(0)
    /// Under reduced motion, a tab's black cross-fading out from where it was, and since when.
    var fade: (outline: CGPath, t0: Double)?

    public init(
        settings: StripSettings = StripSettings(), sessions: [StripSession], measure: StripMeasure, _ input: StripInput
    ) {
        self.settings = settings
        self.sessions = sessions
        self.measure = measure
        stage = input.stage
        reducesMotion = input.reducesMotion
        now = input.time

        display = StripSession.sorted(sessions).map(\.id)
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
        aimGive()
        for key in [\Strip.give, \.hair, \.hairOp] {
            self[keyPath: key].step(dt)
        }
        for mark in marks + [more].compactMap(\.self) {
            mark.step(dt)
        }
        for tab in tabs {
            tab.step(dt)
        }
        stepTabs()
        holdGive()
        return render()
    }

    /// What changed since the last frame, before the sim clock moves on: the screen, reduced motion, and the pointer,
    /// held to the screen.
    private func take(_ input: StripInput) {
        reducesMotion = input.reducesMotion
        if input.stage != stage {
            stage = input.stage
            relayout(snapAll: true)
            hair.snap(hair.target)
            if let more {
                more.y.snap(more.y.target)
            }
        }
        let p = input.pointer.map { Vec(clamp($0.x, 0.5, stage.width - 0.5), clamp($0.y, 0, stage.height)) }
        guard p != sp else {
            return
        }

        sp = p
        if let p {
            trail.add(p, at: now)
        }
    }

    /// A new ask: its needs you moves in at once, pointer or not, and its ring flashes.
    public func newAsk(_ session: StripSession) {
        sessions.append(session)
        insertNeeds(session)
    }

    /// Sessions that aren't asks, come all at once as the prototype's Too many brings them: the marks re-sort at once,
    /// and the new ones fade and grow in where they land, unless they land in the count.
    public func add(_ new: [StripSession]) {
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
    public func change(_ session: StripSession) {
        guard let i = sessions.firstIndex(where: { $0.id == session.id }) else {
            return
        }

        sessions[i] = session
        changed(session)
    }

    /// A click anywhere off the strip and its tab draws the tab back at once.
    public func clickElsewhere() {
        if let live = liveTab(), live.phase == .open {
            drawBack(live)
        }
    }

    func session(_ id: String) -> StripSession? {
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
            spring.springTo(target, settings.sp(kind))
        }
    }

    /// How far into the screen the black can reach: the strip and its widest tab, overshooting as the springs that
    /// carry its depth do at the least damping Bounce gives them, and a few points spare.
    public static let depth: Double = {
        var loosest = StripSettings()
        loosest.bounce = StripDial.bounce.range.upperBound
        let overshoot = [StripSpring.pour, .width].map { kind in
            let z = loosest.sp(kind).damping
            return exp(-Double.pi * z / (1 - z * z).squareRoot())
        }.max() ?? 0
        return (StripTuning.width + StripTuning.tabMax * (1 + overshoot)).rounded(.up) + 4
    }()

    func nextSerial() -> Int {
        serial += 1
        return serial
    }
}

/// A mark on the strip: a session's, or the count's.
public enum MarkKey: Hashable, Sendable {
    case session(String)
    case more
}

/// A click jumping, for the spin's 450ms: from a tab, to its session or one of the count's, or from a mark whose tab
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

    /// A tab drawing back, by its id.
    static func draw(_ tab: Int) -> Self { Self(rawValue: "draw:\(tab)") }
}

extension Strip: SimModel {}
