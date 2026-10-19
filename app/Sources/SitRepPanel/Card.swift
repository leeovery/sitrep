import CoreGraphics
import Foundation

/// The card notch's feel, ported from its prototype (card.html): a card square into the edge that eases out toward
/// the pointer, slides out of the notch and grows to the panel's size as it comes, like a card from an ATM, and goes
/// back the same way, seating in the slot. The view feeds it a frame at a time and draws what each gives back, as it
/// does Meniscus.
public final class Card: Notch {
    let feel: CardFeel
    public internal(set) var phase = Phase.closed

    var t = 0.0
    var now: Double
    var stage: Stage
    var content: Content
    var needs: Bool
    var reducesMotion: Bool
    public internal(set) var notchY: Double
    var S: CardSprings
    var sp: Vec?
    var trail = Trail()
    var contact = Contact()
    /// The open or the close under way, staged once a frame on where the springs have got to.
    var motion: Motion?
    var reveal = Reveal.none
    /// The sim time of the last push of a new ask, or of an ask while the panel is out.
    var flash: Double?
    /// Under reduced motion, the outline cross-fading out, and since when.
    var fade: (outline: CGPath, t0: Double)?
    var timers = SimTimers<Card, CardTimer>()
    var lastOutline: CGPath?
    var lastHit: CGRect?
    var lastPanel: Frame.Panel?

    let rowsAt = 0.0

    /// At Lee's feel, from its first frame's input.
    public convenience init(_ input: Input) {
        self.init(feel: .lees, input)
    }

    init(feel: CardFeel, _ input: Input) {
        self.feel = feel
        stage = input.stage
        content = input.content
        needs = input.needsLee
        reducesMotion = input.reducesMotion
        now = input.time
        notchY = Self.home(on: input.stage)
        let rest = needs ? NotchShape.needs : .rest
        S = CardSprings(w: rest.w, h: rest.h, light: needs ? 1 : 0)
    }

    /// The notch's home on a screen, kept where it fits inside the band: a new ask never lengthens it.
    private static func home(on stage: Stage) -> Double {
        stage.keep(stage.notchY, half: NotchShape.needs.h / 2)
    }

    public var items: [Item] { content.items }

    var isLive: Bool { phase == .open || phase == .opening }

    public var field: Double { CardTuning.field }

    /// The card at rest is the notch: 15 × 124 while something needs Lee, else 7 × 76.
    var resting: NotchShape { needs ? .needs : .rest }

    /// Open, the card is as long as the panel's content, capped to the band; past that the rows scroll.
    var panelLength: Double {
        min(content.height, max(120, stage.bandBottom - stage.bandTop))
    }

    /// One frame: the view's news since the last, then the prototype's frame loop, in its order.
    public func frame(_ input: Input) -> Frame {
        let dt = min(50, max(0, input.time - now))
        now = input.time
        take(input)
        t += dt
        runTimers()
        followLength()
        updateNudge()
        updateContact(geometry())
        updateLeave()
        for key in CardSprings.all {
            S[keyPath: key].step(dt)
        }
        updateMotion()
        return render(geometry())
    }

    /// What happened since the last frame, before the sim clock moves on: the screen, the content, reduced motion,
    /// what needs Lee, and the pointer.
    private func take(_ input: Input) {
        if input.stage != stage {
            stage = input.stage
            notchY = Self.home(on: stage)
        }
        content = input.content
        reducesMotion = input.reducesMotion
        if input.needsLee != needs {
            if input.needsLee {
                newAsk()
            } else {
                answerAll()
            }
        }
        let p = input.pointer.map { Vec(max(0, $0.x), $0.y) }
        guard p != sp else {
            return
        }

        sp = p
        if let p {
            trail.add(p, at: now)
        }
    }

    /// The live card, from the springs: the nudge adds to the depth.
    func geometry() -> CardGeometry {
        CardGeometry(w: S.w.x + S.n.x, h: S.h.x, near: notchY, on: stage)
    }

    /// A new ask: the light comes on, and a closed notch is pushed out to Swell and back, Swells times, the light
    /// flashing with each push; with the panel out the light flashes alone.
    public func newAsk() {
        needs = true
        to(\.light, 1, 160)
        guard phase == .closed else {
            flash = t
            return
        }

        springTo(\.h, NotchShape.needs.h, feel.sp(.follow))
        swell()
    }

    /// The pushes, 450ms apart; with none, the notch comes straight out to its depth.
    func swell() {
        cancelPrefix(CardTimer.swellPrefix)
        guard feel.swells > 0 else {
            return springTo(\.w, resting.w, feel.sp(.follow))
        }

        for i in 0 ..< feel.swells {
            later(.swell(i), Double(i) * Tuning.swellGap) { $0.pushOut() }
        }
    }

    /// One push: kicked out so it peaks at Swell, then back through the notch's depth and settled; its length is
    /// unchanged.
    func pushOut() {
        guard phase == .closed else {
            return
        }

        flash = t
        let home = resting.w
        guard !reducesMotion else {
            return setShape(w: home)
        }

        springTo(\.w, home, feel.sp(.ask))
        S.w.v = S.w.kick(toPeak: feel.swell)
    }

    /// The way back from `answerAll`; a push under way is left to play out.
    public func needsLeeQuietly() {
        guard !needs else {
            return
        }

        needs = true
        to(\.light, 1, 160)
        if phase == .closed {
            setShape(w: resting.w, h: resting.h, 450)
        }
    }

    private func answerAll() {
        needs = false
        cancelPrefix(CardTimer.swellPrefix)
        to(\.light, 0, 450)
        if phase == .closed {
            setShape(w: resting.w, h: resting.h, 450)
        }
    }

    /// A click on one of `items`: one that jumps closes the panel, as a jump does.
    public func clickRow(_ index: Int) {
        guard isLive, rowJumps(index) else {
            return
        }

        close()
    }

    /// A click anywhere off the panel and the notch closes it at once.
    public func clickElsewhere() {
        if isLive {
            close()
        }
    }

    public func carry() {
        close()
    }

    /// Straight to a shape: on critically damped springs, or under reduced motion a cross-fade to it.
    func setShape(w: Double? = nil, h: Double? = nil, _ dur: Double = 120) {
        let targets = [(\CardSprings.w, w), (\.h, h)].compactMap { key, target in target.map { (key, $0) } }
        guard reducesMotion else {
            return targets.forEach { to($0, $1, dur) }
        }

        crossfade(to: targets)
    }
}

/// Every spring the card is made of, by the prototype's names (its `S`).
struct CardSprings {
    /// The card's depth out of the edge, ...
    var w: Spring
    /// ... its length along it, ...
    var h: Spring
    /// ... and the nudge toward a pointer near it, on top of the depth.
    var n = Spring(0)
    /// Anything needs Lee.
    var light: Spring
    /// The light, dimmed while the panel is out.
    var vis = Spring(1)

    init(w: Double, h: Double, light: Double) {
        self.w = Spring(w)
        self.h = Spring(h)
        self.light = Spring(light)
    }

    static var all: [WritableKeyPath<CardSprings, Spring>] { [\.w, \.h, \.n, \.light, \.vis] }
}

/// The open or the close under way.
struct Motion {
    enum Kind {
        case open, close
    }

    let kind: Kind
    /// Opening: the length has started out.
    var lengthOn = false
    /// Closing: the depth has started home, ...
    var homing = false
    /// ... and the light has come back.
    var lit = false
}

/// A timer on the card's sim clock, by the prototype's name for it.
struct CardTimer: RawRepresentable, Equatable {
    let rawValue: String

    static let dwell = Self(rawValue: "dwell")
    static let grace = Self(rawValue: "grace")
    static let openLength = Self(rawValue: "open:length")
    static let closeLength = Self(rawValue: "close:length")
    static let closeDepth = Self(rawValue: "close:depth")
    static let closeDone = Self(rawValue: "close:done")

    /// A new ask's push, by its place among them.
    static func swell(_ i: Int) -> Self { Self(rawValue: swellPrefix + String(i)) }
    static let swellPrefix = "swell:"
}

extension Card: NotchModel {}
