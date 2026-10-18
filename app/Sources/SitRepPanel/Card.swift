import CoreGraphics
import Foundation

/// The card notch's feel, ported from its prototype (card.html): a card square into the edge that eases out toward
/// the pointer, slides out of the notch and grows to the panel's size as it comes, like a card from an ATM, and goes
/// back the same way, seating in the slot. The view feeds it a frame at a time and draws what each gives back, as it
/// does Meniscus.
public final class Card: Notch {
    public var settings: CardSettings
    public internal(set) var phase = Phase.closed
    public let items = Item.samples

    var t = 0.0
    var now: Double
    var stage: Stage
    var content: Content
    var needs: Bool
    var reducesMotion: Bool
    var lipY: Double
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

    public init(settings: CardSettings = CardSettings(), _ input: Input) {
        self.settings = settings
        stage = input.stage
        content = input.content
        needs = input.needsLee
        reducesMotion = input.reducesMotion
        now = input.time
        lipY = input.stage.keep(input.stage.lipY, half: LipShape.needs.h / 2)
        let rest = needs ? LipShape.needs : .rest
        S = CardSprings(w: rest.w, h: rest.h, light: needs ? 1 : 0)
    }

    var isLive: Bool { phase == .open || phase == .opening }

    public var field: Double { CardTuning.field }

    /// The card at rest is the notch: 15 × 124 while something needs Lee, else 7 × 76.
    var notch: LipShape { needs ? .needs : .rest }

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
            lipY = stage.keep(stage.lipY, half: LipShape.needs.h / 2)
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
        CardGeometry(w: S.w.x + S.n.x, h: S.h.x, near: lipY, on: stage)
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

        springTo(\.h, LipShape.needs.h, settings.sp(.follow))
        swell()
    }

    /// The pushes, 450ms apart.
    func swell() {
        cancelPrefix(CardTimer.swellPrefix)
        for (i, name) in CardTimer.swells.prefix(Int(settings.swells)).enumerated() {
            later(name, Double(i) * Tuning.swellGap) { $0.pushOut() }
        }
    }

    /// One push: kicked out so it peaks at Swell, then back through the notch's depth and settled; its length is
    /// unchanged.
    func pushOut() {
        guard phase == .closed else {
            return
        }

        flash = t
        let home = notch.w
        guard !reducesMotion else {
            return setShape(w: home)
        }

        springTo(\.w, home, settings.sp(.ask))
        S.w.v = S.w.kick(toPeak: settings.swell)
    }

    private func answerAll() {
        needs = false
        cancelPrefix(CardTimer.swellPrefix)
        to(\.light, 0, 450)
        if phase == .closed {
            setShape(w: notch.w, h: notch.h, 450)
        }
    }

    /// A click on one of `items`: one that jumps closes the panel, as a jump does.
    public func clickRow(_ index: Int) {
        guard isLive, items[index].session?.jumps == true else {
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
enum CardTimer: String {
    case dwell, grace
    case openLength = "open:length"
    case closeLength = "close:length", closeDepth = "close:depth", closeDone = "close:done"
    case swell0 = "swell:0", swell1 = "swell:1", swell2 = "swell:2"

    /// A new ask's pushes, one for each the Swells dial can ask for.
    static let swells: [CardTimer] = [.swell0, .swell1, .swell2]
    static let swellPrefix = "swell:"
}

extension Card: NotchModel {}
