import CoreGraphics
import Foundation

/// The notch's feel, ported from its prototype (meniscus.html): the notch and its attraction to the pointer, the
/// pour, the edge holding the pointer as it leaves, the release, the collapse and the landing. The view feeds it a
/// frame at a time and draws what each gives back. It works in the edge's own coordinates, so it never knows which
/// edge it is on: the view mirrors it for the right.
public final class Meniscus: Notch {
    let feel: MeniscusFeel
    public internal(set) var phase = Phase.closed

    /// The sim clock, ms.
    var t = 0.0
    /// The view's clock at the latest frame, ms: the pointer's trail runs on it.
    var now: Double
    var stage: Stage
    var content: Content
    var needs: Bool
    var reducesMotion: Bool
    public internal(set) var notchY: Double
    var S: MeniscusSprings
    /// While open, the shape's height follows the content.
    var follow = false
    /// The pointer this frame.
    var sp: Vec?
    /// Where the pointer last was along the edge, while on this screen.
    var lastStageY: Double?
    var trail = Trail()
    /// What the pointer was over at its last move.
    var hover: Hover?
    var snap: Snap?
    /// Collapsing home after a leave: the notch's top and bottom on springs of their own.
    var ends: Ends?
    /// After a leave the edge rings on, on its own spring, past the panel's close, ...
    var ringing = false
    /// ... at this share of the way along the outline between the flares.
    var ringAt: Double?
    /// A collapse about to land, at this width.
    var landing: Double?
    /// How fast the pointer left, for a grace that ends in a drain.
    var leaveSpeed = 0.0
    var attract = Attract()
    var contact = Contact()
    var cling = Cling()
    var reveal = Reveal.none
    /// The row a click is jumping to, pressed in until the panel has drained.
    var jumping: String?
    /// A drag has the notch, ...
    var isCarried = false
    /// ... or let it go across the screen's middle, and it is draining into this edge to grow out of the other ...
    var isCrossing = false
    /// ... from this frame.
    var swapsEdge = false
    /// The sim time of the last new ask.
    var flash: Double?
    var timers = SimTimers<Meniscus, MeniscusTimer>()
    /// The collapse started inside this frame, this long before its end: its springs step only that long.
    var lag: Double?
    /// The notch's hit area and the panel's content as last drawn, which the pointer's moves are hit-tested against.
    var lastHit: CGRect?
    var lastPanel: Frame.Panel?
    /// Under reduced motion, the outline cross-fading out, and since when.
    var fade: (outline: CGPath, t0: Double)?
    var lastOutline: CGPath?

    /// At Lee's feel, from its first frame's input.
    public convenience init(_ input: Input) {
        self.init(feel: .lees, input)
    }

    init(feel: MeniscusFeel, _ input: Input) {
        self.feel = feel
        stage = input.stage
        content = input.content
        needs = input.needsLee
        reducesMotion = input.reducesMotion
        now = input.time
        notchY = Self.home(input.stage.notchY, on: input.stage, feel)
        S = MeniscusSprings(notch: needs ? .needs : .rest, notchY: notchY, light: needs ? 1 : 0)
    }

    /// The notch's home at a place on a screen, kept where its deepest swell fits inside the band.
    static func home(_ y: Double, on stage: Stage, _ feel: MeniscusFeel) -> Double {
        stage.keep(y, half: NotchShape(feel.swell).h / 2)
    }

    public var items: [Item] { content.items }

    var isLive: Bool { phase == .open || phase == .opening }

    public var field: Double { feel.field }

    let rowsAt = Tuning.rowsAt

    var resting: NotchShape { needs ? .needs : .rest }

    /// The content's height as shown: its own, capped to the band less the flares.
    var panelHeight: Double {
        min(content.height, max(120, stage.bandBottom - stage.bandTop - 2 * Tuning.panelF))
    }

    /// The open panel's shape height: the content and a flare at each end.
    var panelTargetH: Double { panelHeight + 2 * Tuning.panelF }

    /// One frame: the view's news since the last, then the prototype's frame loop, in its order.
    public func frame(_ input: Input) -> Frame {
        let dt = min(50, max(0, input.time - now))
        now = input.time
        take(input)
        t += dt
        if let sp {
            lastStageY = sp.y
        }
        runTimers()
        followContent()
        updateField()
        // the pointer against the shape as it is on screen; an open or a pop moves it from this frame
        let g0 = lifted(geometry())
        updateContact(g0)
        updateCling(g0)
        // the tongue first: as its ring comes in the second time, the collapse starts in this frame
        S.ba.step(dt)
        watchRing()
        let lagged = MeniscusSprings.collapse
        for key in MeniscusSprings.all where key != \MeniscusSprings.ba {
            S[keyPath: key].step(lagged.contains(key) ? lag ?? dt : dt)
        }
        lag = nil
        updateEnds()
        if ringing, phase == .closed, abs(S.ba.x) < 0.03, abs(S.ba.v) < 0.001 {
            S.ba.snap(0)
            ringOff()
            S.by.snap(notchY)
        }
        if let landing, S.w.x <= landing + clamp(-S.w.v * Tuning.landLead, Tuning.landMin, Tuning.landAt) {
            land()
        }
        var g = lifted(geometry())
        if abs(S.ba.x) > 0.05, !isCrossing {
            g.bump = bumpOf()
        }
        return render(g)
    }

    /// What happened since the last frame, before the sim clock moves on: the screen, the content, what needs Lee,
    /// whether to reduce motion, and the pointer.
    private func take(_ input: Input) {
        reducesMotion = input.reducesMotion
        if input.stage != stage {
            stage = input.stage
            measure()
        }
        content = input.content
        if input.needsLee != needs {
            if input.needsLee {
                newAsk()
            } else {
                answerAll()
            }
        }
        pointerMoved(input.pointer.map { Vec(max(0, $0.x), $0.y) })
    }

    /// The screen changed: the notch's home moves with it, unless a drag has already taken it there.
    private func measure() {
        let home = Self.home(stage.notchY, on: stage, feel)

        guard abs(home - notchY) > Self.samePlace else {
            return
        }

        notchY = home
        S.y.snap(notchY)
    }

    /// Two homes this close are one: a drag's place, saved as a share of the screen, comes back a hair off.
    static let samePlace = 1e-6

    /// A new ask: the light flashes, and a closed notch over-swells, as many times as Swells says, the light
    /// flashing again with each; with none, it goes straight to 15 deep. Something needs Lee from here.
    public func newAsk() {
        needs = true
        flash = t
        to(\.light, 1, 160)
        guard phase == .closed else {
            return
        }
        guard feel.swells > 0 else {
            let needs = NotchShape.needs
            return setShape(w: needs.w, h: needs.h, r: needs.r, f: needs.f, 450)
        }

        swellNotch()
        swellAgain(feel.swells - 1)
    }

    /// The swells after the first, each `swellGap` after the last, while the notch stays closed and something needs
    /// Lee.
    private func swellAgain(_ left: Int) {
        guard left > 0 else {
            return
        }

        later(.swell, Tuning.swellGap) { model in
            guard model.phase == .closed, model.needs else {
                return
            }

            model.flash = model.t
            model.swellNotch()
            model.swellAgain(left - 1)
        }
    }

    @discardableResult
    public func clickRow(_ index: Int) -> Bool {
        guard isLive, jumping == nil, let id = jumpingRow(index) else {
            return false
        }

        cancel(.grace)
        jumping = id
        later(.jump, Tuning.jumpFor) { $0.close() }
        return true
    }

    public func jumpAnswered() {
        if timers.has(.jump) {
            cancel(.jump)
            close()
        }
    }

    /// A click anywhere off the panel and the notch closes it at once.
    public func clickElsewhere() {
        if isLive {
            close()
        }
    }

    public func restingOutline(at y: Double) -> CGPath {
        let l = resting, cy = stage.centre(l.h, near: y)

        return shapePath(MeniscusGeometry(w: l.w, h: l.h, cy: cy, rt: l.r, ft: l.f, rb: l.r, fb: l.f), nil)
    }

    /// The way back from `answerAll`; a swell under way is left to play out.
    public func needsLeeQuietly() {
        guard !needs else {
            return
        }

        needs = true
        to(\.light, 1, 160)
        if phase == .closed {
            let needs = NotchShape.needs
            setShape(w: needs.w, h: needs.h, r: needs.r, f: needs.f, 450)
        }
    }

    private func answerAll() {
        needs = false
        to(\.light, 0, 450)
        if phase == .closed {
            let rest = NotchShape.rest
            setShape(w: rest.w, h: rest.h, r: rest.r, f: rest.f, 450)
        }
    }

    /// The live geometry, from the springs.
    func geometry() -> MeniscusGeometry {
        var h = max(0, S.h.x)
        let r = max(0, S.r.x), f = max(0, S.f.x)
        var kt = 1.0, kb = 1.0
        let e = r + f
        func fit() {
            if e * (kt + kb) > h {
                let k = h / max(e * (kt + kb), 1e-6)
                kt *= k
                kb *= k
            }
        }

        fit()
        var cy = stage.centre(h, near: S.y.x + S.ay.x)
        if ends != nil {
            // collapsing home after a leave: the ends are their own springs
            let top = S.et.x + S.rb.x, bot = S.eb.x + S.rb.x
            h = max(0, bot - top)
            cy = (top + bot) / 2
            fit()
        }
        // past the panel's width, the front edge meets resistance: the spring's overshoot shows as a few points
        var w = S.w.x
        let T = S.w.target
        if T >= 100, w > T {
            w = T + Tuning.frontGive * tanh((w - T) / Tuning.frontGive)
        }
        // and a kicked drain, or the landing's bounce, dips under the notch's depth by a few points at most
        if T < 100, S.w.x < T {
            w = T - Tuning.notchGive * tanh((T - S.w.x) / Tuning.notchGive)
        }
        // the landing's wobble: shallower, the notch runs longer along the edge; deeper, shorter
        w += S.lw.x
        if S.lw.x != 0 {
            h = max(0, h - Tuning.squash * S.lw.x)
            fit()
        }
        return MeniscusGeometry(w: max(0, w), h: h, cy: cy, rt: r * kt, ft: f * kt, rb: r * kb, fb: f * kb)
    }

    /// Where the open panel's content tops out, for a given shape height: centred on the notch, inside the band.
    func finalTop(_ h: Double) -> Double {
        stage.centre(h, near: notchY) - h / 2 + Tuning.panelF
    }

    /// While the panel is out, its height and the content's top follow the content.
    func followContent() {
        guard isLive else {
            return
        }

        let h = panelTargetH
        S.ct.target = finalTop(h)
        S.ct.copySpring(S.h)
        if follow {
            S.h.target = h
        }
    }

    /// Straight to a shape: on critically damped springs, or under reduced motion a cross-fade to it.
    func setShape(w: Double? = nil, h: Double? = nil, r: Double? = nil, f: Double? = nil, _ dur: Double = 120) {
        let targets = shapeTargets(w, h, r, f)
        guard reducesMotion else {
            return targets.forEach { to($0, $1, dur) }
        }

        crossfade(to: targets)
    }

    /// The same, on underdamped springs; under reduced motion a cross-fade too.
    func springShape(w: Double? = nil, h: Double? = nil, r: Double? = nil, f: Double? = nil, _ p: SpringParams) {
        let targets = shapeTargets(w, h, r, f)
        guard reducesMotion else {
            return targets.forEach { springTo($0, $1, p) }
        }

        crossfade(to: targets)
    }

    private func shapeTargets(
        _ w: Double?, _ h: Double?, _ r: Double?, _ f: Double?
    ) -> [(WritableKeyPath<MeniscusSprings, Spring>, Double)] {
        [(\MeniscusSprings.w, w), (\.h, h), (\.r, r), (\.f, f)].compactMap { key, target in target.map { (key, $0) } }
    }

    /// A new ask: the swell runs as one underdamped spring. The notch is kicked outward, so it over-swells to about
    /// Swell, falls back a little past 15, and settles: one quiver. Under reduced motion it cross-fades to 15.
    func swellNotch() {
        let needs = NotchShape.needs
        guard !reducesMotion else {
            return setShape(w: needs.w, h: needs.h, r: needs.r, f: needs.f)
        }

        let p = feel.sp(.ask), omega = 2 * Double.pi / (p.response * 1000)
        let swell = NotchShape(feel.swell)
        let keys: [(WritableKeyPath<MeniscusSprings, Spring>, Double, Double)] = [
            (\.w, needs.w, swell.w), (\.h, needs.h, swell.h), (\.r, needs.r, swell.r), (\.f, needs.f, swell.f),
        ]
        for (key, home, over) in keys {
            springTo(key, home, p)
            S[keyPath: key].v = max(S[keyPath: key].v, 0) + (over - home) * omega / peakShare(p.damping)
        }
    }
}

enum MeniscusTimer: String {
    case dwell, grace, swell
    case jump = "jump:go"
    case moveStart = "move:start", moveSwap = "move:swap", moveDone = "move:done"
    case openW = "open:w", openDone = "open:done"
    case closeW = "close:w", closeH = "close:h", closeVis = "close:vis", closeDone = "close:done"
    case closeFar = "close:far", closeBurst = "close:burst", closePush = "close:push"
}

extension Meniscus: NotchModel {}
/// Every spring the shape is made of, by the prototype's names (its `S`).
struct MeniscusSprings {
    var w, h, r, f: Spring
    /// The shape's centre, chasing the notch's home.
    var y: Spring
    /// The content's top edge.
    var ct = Spring(0)
    /// Anything needs Lee.
    var light: Spring
    /// The light, dimmed while the panel is out.
    var vis = Spring(1)
    /// The notch's slide along the edge after its tongue, off its home.
    var ay = Spring(0)
    /// The tongue: how far its tip stands out of the edge (a dent below 0) ...
    var ba = Spring(0)
    /// ... and where along the edge its tip is, stage y.
    var by: Spring
    /// Collapsing home after a leave: the shape's top end, stage y, ...
    var et = Spring(0)
    /// ... its bottom end, ...
    var eb = Spring(0)
    /// ... and the rebound past home that both carry, away from the exit.
    var rb = Spring(0)
    /// The landing's wobble on the notch's depth.
    var lw = Spring(0)
    /// A drag lifting the notch off the edge.
    var lift = Spring(0)

    init(notch: NotchShape, notchY: Double, light: Double) {
        w = Spring(notch.w)
        h = Spring(notch.h)
        r = Spring(notch.r)
        f = Spring(notch.f)
        y = Spring(notchY)
        by = Spring(notchY)
        self.light = Spring(light)
    }

    /// Every one, in the prototype's order.
    static var all: [WritableKeyPath<MeniscusSprings, Spring>] {
        [\.w, \.h, \.r, \.f, \.y, \.ct, \.light, \.vis, \.ay, \.ba, \.by, \.et, \.eb, \.rb, \.lw, \.lift]
    }
}
