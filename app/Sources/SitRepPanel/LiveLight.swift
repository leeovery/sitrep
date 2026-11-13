import CoreGraphics
import Foundation

/// The Live light's colours at a moment, ported from the prototype's `drawLive` (lights.js): the breath, the two
/// spots swaying along the bar, the deeper tips and a new ask's brighten, in the palette of what lights it, an ask's
/// orange or your turn's blue. The view draws the bar from these; they run on the display's clock, never the model's
/// sim clock, so the light breathes while the model is idle. Under reduced motion it holds still, mid-breath with its
/// spots at home, and a new ask is a shorter brighten.
public struct LiveLight: Equatable, Sendable {
    /// A colour as the prototype mixes it: red, green and blue from 0 to 255, unrounded.
    public struct RGB: Equatable, Sendable {
        public var r, g, b: Double

        init(hex: UInt32) {
            r = Double(hex >> 16 & 0xFF)
            g = Double(hex >> 8 & 0xFF)
            b = Double(hex & 0xFF)
        }

        public init(r: Double, g: Double, b: Double) {
            self.r = r
            self.g = g
            self.b = b
        }

        public func mix(_ other: RGB, _ k: Double) -> RGB {
            RGB(r: lerp(r, other.r, k), g: lerp(g, other.g, k), b: lerp(b, other.b, k))
        }
    }

    /// The light's four colours: its body, its halo's and its marks' colour too; the body banked down, for the tips;
    /// lighter, the breath's peak; and lighter again, the spots, the brighten and the centre line.
    public struct Palette: Equatable, Sendable {
        public let body, deep, warm, hot: RGB

        /// Claude Code's orange, an ask's, the prototype's: its lighter colours a little yellower.
        public static let ask = Palette(
            body: RGB(hex: 0xE9643D), deep: RGB(hex: 0xA93D24), warm: RGB(hex: 0xF7956A), hot: RGB(hex: 0xFFBE8A)
        )
        /// Your turn's blue: each of the orange's colours at its OKLCH lightness and chroma, turned to the hue of
        /// macOS's system blue, 255.5, so neither shouts over the other; the two lightest with their chroma cut to what
        /// sRGB holds.
        public static let turn = Palette(
            body: RGB(hex: 0x3F93FB), deep: RGB(hex: 0x1F65B7), warm: RGB(hex: 0x7CB5FF), hot: RGB(hex: 0xAED0FF)
        )

        /// The palette of what lights it.
        public static func of(_ need: Need) -> Palette {
            switch need {
            case .ask: ask
            case .turn: turn
            }
        }
    }

    /// Claude Code's orange: an ask's light, and every ask's mark.
    public static let orange = Palette.ask.body
    /// Your turn's blue: its light, and every your-turn mark.
    public static let blue = Palette.turn.body

    /// The bar: 2.5 wide and 36 long, set a quarter point toward the edge from the light's centre, so at 2x its
    /// sides land on whole pixels.
    public static let bar = CGRect(x: -1.5, y: -18, width: 2.5, height: 36)
    /// The halo, a shadow of the bar alone: its σ, in points, and its alpha in orange.
    public static let haloSigma = 1.5, haloAlpha = 0.6

    /// The colours it is drawn in.
    public let palette: Palette
    /// How opaque the whole light is, before its level: 0.86 at the breath's trough to 1 at its peak, or the
    /// brighten's, whichever is more.
    public let opacity: Double
    /// The body's gradient from the bar's top to its bottom, `bodyStops` + 1 evenly spaced colours.
    public let body: [RGB]
    /// The faint lighter line down the bar's middle: the alpha of `hot` at its centre, fading to 0 at its sides.
    public let line: Double

    static let bodyStops = 24

    /// The light at a time on the display's clock, ms, this long after the last new ask (nil when there has been
    /// none), lit by an ask or by your turn.
    public init(time t: Double, sinceAsk e: Double?, reducesMotion reduce: Bool = false, need: Need = .ask) {
        let p = Palette.of(need)
        let b = reduce ? Self.held : Self.breath(t), k = reduce ? Self.brighten(e) : Self.brightenUp(e)
        let base = p.body.mix(p.warm, 0.38 * b).mix(p.hot, 0.38 * k)
        let spots = Self.sways.map { $0.spot(at: reduce ? 0 : t) }
        let half = Self.bar.height / 2

        opacity = max(lerp(0.86, 1, b), k)
        body = (0 ... Self.bodyStops).map { i in
            let y = -half + Self.bar.height * Double(i) / Double(Self.bodyStops)
            let heat = spots.reduce(0) { sum, p in
                let z = (y - p.centre) / p.width
                return sum + p.strength * exp(-0.5 * z * z)
            }
            let tip = 1 - smooth(clamp((half - abs(y)) / 5, 0, 1))
            return base.mix(p.hot, 0.28 * clamp(heat, 0, 1.1)).mix(p.deep, 0.16 * tip)
        }
        palette = p
        line = 0.14 + 0.08 * b + 0.1 * k
    }

    /// Whether the light changes from moment to moment: always, as it breathes, but under reduced motion only while
    /// a new ask's brighten plays.
    public static func moves(sinceAsk e: Double?, reducesMotion: Bool) -> Bool {
        !reducesMotion || e.map { $0 >= 0 && $0 < reducedFlash } == true
    }

    /// Under reduced motion the breath holds here.
    static let held = 0.6

    /// How long a new ask's brighten lasts under reduced motion, ms.
    static let reducedFlash = 540.0

    /// The breath: one 2.4s cosine, 0 at the trough and 1 at the peak.
    static func breath(_ t: Double) -> Double {
        0.5 - 0.5 * cos(2 * .pi * t / 2400)
    }

    /// A new ask's brighten: up in 70ms, held, and back by 700ms.
    static func brightenUp(_ e: Double?) -> Double {
        guard let e, e >= 0, e < 700 else {
            return 0
        }

        if e < 70 {
            return smooth(e / 70)
        }
        if e < 200 {
            return 1
        }
        return 1 - easeInOut((e - 200) / 500)
    }

    /// A new ask's brighten under reduced motion: up in 80ms, held, and back by 540ms.
    static func brighten(_ e: Double?) -> Double {
        guard let e, e >= 0, e < reducedFlash else {
            return 0
        }

        if e < 80 {
            return smooth(e / 80)
        }
        if e < 220 {
            return 1
        }
        return 1 - smooth((e - 220) / 320)
    }

    /// A warmer spot swaying round its home along the bar, on a slow period and a slower harmonic, never travelling
    /// one way (the prototype's `SWAYS`).
    struct Sway {
        let home, a, p, a2, p2, s, ph: Double

        func spot(at t: Double) -> (centre: Double, width: Double, strength: Double) {
            let centre = home + a * sin(2 * .pi * t / p + ph) + a2 * sin(2 * .pi * t / p2 + 1.3 * ph)
            return (centre, s, 0.8 + 0.2 * sin(2 * .pi * t / (p * 0.63) + ph))
        }
    }

    static let sways = [
        Sway(home: -6, a: 4.5, p: 8300, a2: 1.0, p2: 3900, s: 5.5, ph: 0.4),
        Sway(home: 7, a: 4.0, p: 10700, a2: 0.8, p2: 4700, s: 5.0, ph: 2.6),
    ]
}
