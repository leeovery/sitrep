import Foundation
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The Live light against the prototype: every expected number here is what lights.js's own `drawLive`, run under
/// node on a canvas that records what it is given, paints at the same moment, as the canvas's colour strings round
/// it: each body stop's red, green and blue, the centre line's alpha to three places, and the opacity.
@Suite(.backstop)
struct LiveLightTests {
    struct Drawn: Sendable, CustomTestStringConvertible {
        let time: Double
        let sinceAsk: Double?
        let opacity: Double
        let line: String
        let body: [String]

        var testDescription: String { "at \(time)ms, \(sinceAsk.map { "\($0)ms after an ask" } ?? "no ask")" }
    }

    static let drawn = [
        Drawn(time: 0, sinceAsk: nil, opacity: 0.86, line: "0.140", body: [
            "223 94 58", "225 96 59", "230 100 62", "234 104 65", "235 107 67",
            "236 110 70", "236 114 73", "237 118 76", "238 121 79", "239 123 80",
            "239 123 81", "239 123 81", "238 122 80", "238 122 80", "238 122 80",
            "239 123 80", "239 124 81", "239 125 82", "239 124 82", "238 122 80",
            "238 119 77", "236 115 74", "232 108 68", "226 101 63", "224 97 60",
        ]),
        Drawn(time: 1234.5, sinceAsk: 30, opacity: 0.999714669481583, line: "0.259", body: [
            "229 118 79", "232 121 81", "237 126 85", "241 130 88", "241 132 89",
            "242 133 90", "242 135 92", "243 138 94", "244 141 97", "244 145 100",
            "245 148 103", "245 148 103", "245 148 103", "245 148 103", "245 148 103",
            "245 148 103", "245 148 103", "245 145 100", "244 142 97", "243 138 95",
            "242 135 92", "241 133 90", "237 127 86", "232 122 81", "229 119 79",
        ]),
        Drawn(time: 5000, sinceAsk: 150, opacity: 1, line: "0.245", body: [
            "231 126 85", "234 130 88", "239 138 94", "244 144 99", "244 146 101",
            "245 148 102", "245 148 102", "245 148 102", "245 148 102", "245 148 102",
            "245 148 102", "245 148 102", "245 149 103", "245 150 104", "245 151 104",
            "245 150 104", "245 149 103", "244 146 101", "244 144 98", "243 141 96",
            "243 139 94", "242 137 93", "238 132 89", "233 126 85", "230 123 82",
        ]),
        Drawn(time: 20000, sinceAsk: 800, opacity: 0.9650000000000002, line: "0.200", body: [
            "226 106 68", "229 108 70", "234 113 73", "238 117 77", "238 119 78",
            "239 122 80", "239 124 82", "240 126 84", "240 128 85", "240 129 86",
            "240 129 86", "240 128 86", "240 127 85", "240 127 85", "240 127 85",
            "240 129 86", "241 131 88", "241 133 90", "242 134 91", "242 134 91",
            "241 133 90", "240 130 87", "236 123 82", "230 115 76", "227 110 72",
        ]),
        Drawn(time: 47321, sinceAsk: 65, opacity: 0.9854227405247813, line: "0.287", body: [
            "232 131 89", "235 136 93", "241 144 99", "245 150 104", "246 152 106",
            "246 154 107", "246 154 108", "246 154 108", "246 154 107", "246 153 107",
            "246 153 107", "246 153 107", "246 154 107", "246 154 108", "246 154 107",
            "246 153 107", "246 151 105", "245 149 103", "245 147 101", "244 145 100",
            "244 143 98", "243 142 97", "239 137 93", "234 131 89", "231 128 87",
        ]),
        Drawn(time: 3100, sinceAsk: -5, opacity: 0.9481173331571764, line: "0.190", body: [
            "226 104 67", "228 107 68", "233 111 72", "237 116 75", "238 118 77",
            "238 120 79", "239 123 81", "240 125 83", "240 127 85", "240 129 86",
            "241 130 87", "241 131 88", "241 132 89", "241 131 88", "241 131 88",
            "241 129 87", "240 127 85", "239 124 82", "239 121 80", "238 118 77",
            "237 116 75", "237 114 74", "233 110 71", "228 106 68", "226 104 66",
        ]),
    ]

    @Test(arguments: drawn)
    func theLightIsDrawnAsThePrototypeDrawsIt(_ drawn: Drawn) {
        let light = LiveLight(time: drawn.time, sinceAsk: drawn.sinceAsk)

        #expect(abs(light.opacity - drawn.opacity) < 1e-12)
        #expect(String(format: "%.3f", light.line) == drawn.line)
        #expect(light.body.map(Self.css) == drawn.body)
    }

    @Test(arguments: [(0.0, 0.0), (600, 0.5), (1200, 1), (1800, 0.5), (2400, 0)])
    func itBreathesOnTwoPointFourSecondsFromItsTrough(time: Double, breath: Double) {
        #expect(abs(LiveLight.breath(time) - breath) < 1e-12)
    }

    @Test(arguments: [(nil, 0.0), (-5, 0), (0, 0), (30, 0.39358600583090375), (70, 1), (150, 1), (450, 0.5), (700, 0)])
    func aNewAskBrightensItUpInSeventyMillisecondsAndBackBySevenHundred(sinceAsk: Double?, brighten: Double) {
        #expect(abs(LiveLight.brightenUp(sinceAsk) - brighten) < 1e-12)
    }

    /// Under reduced motion, as `drawLive` paints it with `reduce` set.
    static let reduced = [
        Drawn(time: 0, sinceAsk: nil, opacity: 0.944, line: "0.188", body: Self.still),
        Drawn(time: 1234.5, sinceAsk: 30, opacity: 0.944, line: "0.220", body: [
            "227 112 73", "230 114 75", "235 119 79", "239 124 82", "240 126 84",
            "240 129 86", "241 131 88", "242 134 91", "242 137 93", "243 138 94",
            "243 139 94", "243 138 94", "243 138 94", "242 137 93", "242 137 94",
            "243 138 94", "243 139 95", "243 140 95", "243 139 95", "243 138 94",
            "242 135 92", "241 132 89", "236 125 84", "231 118 78", "228 114 75",
        ]),
        Drawn(time: 5000, sinceAsk: 150, opacity: 1, line: "0.288", body: [
            "232 129 87", "234 132 90", "239 138 94", "244 143 98", "244 145 100",
            "245 147 101", "245 149 103", "246 151 105", "246 152 106", "246 153 107",
            "246 154 107", "246 154 107", "246 153 107", "246 153 107", "246 153 107",
            "246 153 107", "246 154 108", "247 155 108", "246 154 108", "246 153 107",
            "246 151 105", "245 149 103", "240 142 98", "235 134 92", "232 130 89",
        ]),
        Drawn(time: 20000, sinceAsk: 300, opacity: 0.944, line: "0.272", body: [
            "231 125 84", "233 128 86", "238 134 91", "243 139 95", "243 141 96",
            "244 143 98", "244 145 100", "245 147 102", "245 149 103", "245 150 104",
            "246 150 104", "245 150 104", "245 150 104", "245 149 104", "245 149 104",
            "245 150 104", "246 151 105", "246 151 105", "246 151 105", "245 150 104",
            "245 148 102", "244 145 100", "240 138 95", "234 131 89", "231 127 85",
        ]),
        Drawn(time: 47321, sinceAsk: 500, opacity: 0.944, line: "0.192", body: [
            "226 105 67", "228 107 69", "233 112 72", "237 116 76", "238 119 78",
            "239 121 80", "239 125 83", "240 128 85", "241 130 87", "241 132 89",
            "241 133 89", "241 132 89", "241 132 89", "241 131 88", "241 131 88",
            "241 132 89", "241 133 90", "242 134 90", "241 133 90", "241 132 89",
            "240 129 86", "239 125 83", "235 118 78", "229 111 72", "226 107 69",
        ]),
        Drawn(time: 3100, sinceAsk: -5, opacity: 0.944, line: "0.188", body: Self.still),
        Drawn(time: 900, sinceAsk: 540, opacity: 0.944, line: "0.188", body: Self.still),
    ]

    /// The light held still: mid-breath, its spots at home.
    private static let still = [
        "226 104 66", "228 106 68", "233 111 71", "237 115 74", "238 117 77",
        "238 120 79", "239 123 82", "240 127 84", "241 129 87", "241 131 88",
        "241 132 89", "241 131 88", "241 131 88", "241 130 87", "241 130 87",
        "241 131 88", "241 132 89", "241 133 90", "241 132 89", "241 131 88",
        "240 128 85", "239 124 82", "235 117 77", "229 110 71", "226 106 68",
    ]

    @Test(arguments: reduced)
    func underReducedMotionItIsDrawnAsThePrototypeDrawsIt(_ drawn: Drawn) {
        let light = LiveLight(time: drawn.time, sinceAsk: drawn.sinceAsk, reducesMotion: true)

        #expect(abs(light.opacity - drawn.opacity) < 1e-12)
        #expect(String(format: "%.3f", light.line) == drawn.line)
        #expect(light.body.map(Self.css) == drawn.body)
    }

    @Test(arguments: [0.0, 600, 1234.5, 8300, 47321])
    func underReducedMotionItHoldsStillWithNoAsk(time: Double) {
        #expect(LiveLight(time: time, sinceAsk: nil, reducesMotion: true) == LiveLight(time: 0, sinceAsk: nil, reducesMotion: true))
        #expect(LiveLight(time: time, sinceAsk: 5000, reducesMotion: true) == LiveLight(time: 0, sinceAsk: nil, reducesMotion: true))
    }

    @Test(arguments: [(nil, 0.0), (-5, 0), (0, 0), (40, 0.5), (80, 1), (220, 1), (380, 0.5), (540, 0)])
    func underReducedMotionANewAskBrightensItUpInEightyAndBackBy540(sinceAsk: Double?, brighten: Double) {
        #expect(abs(LiveLight.brighten(sinceAsk) - brighten) < 1e-12)
    }

    @Test func itMovesAlwaysButUnderReducedMotionOnlyWhileANewAskBrightensIt() {
        expectEvery([nil, -5, 0, 300, 5000]) { LiveLight.moves(sinceAsk: $0, reducesMotion: false) }
        expectEvery([0, 80, 300, 539]) { LiveLight.moves(sinceAsk: $0, reducesMotion: true) }
        #expect(![nil, -5, 540, 5000].contains { LiveLight.moves(sinceAsk: $0, reducesMotion: true) })
    }

    @Test func atTheBreathsTroughItStaysOrangeAtEightySixPercent() {
        let light = LiveLight(time: 0, sinceAsk: nil)

        #expect(light.opacity == 0.86)
        expectEvery(light.body) { $0.r > $0.g && $0.g > $0.b }
    }

    // MARK: Lee's turn

    /// Lit by Lee's turn, it is blue, breathing as the orange does: the same opacity and line, in its own palette.
    @Test(arguments: [0.0, 1234.5, 20000])
    func litByLeesTurnItIsBlueAndBreathesAsTheOrangeDoes(time: Double) {
        let turn = LiveLight(time: time, sinceAsk: nil, need: .turn), ask = LiveLight(time: time, sinceAsk: nil)

        #expect(turn.palette == .turn && ask.palette == .ask)
        #expect(turn.opacity == ask.opacity && turn.line == ask.line)
        expectEvery(turn.body) { $0.b > $0.g && $0.g > $0.r }
    }

    /// The blue matches the orange in strength, its OKLCH lightness and chroma the orange's, at the hue of macOS's
    /// system blue, so neither shouts over the other.
    @Test func theBlueIsTheOrangesLightnessAndChromaAtSystemBluesHue() {
        let orange = Self.oklch(LiveLight.orange), blue = Self.oklch(LiveLight.blue)
        let systemBlue = Self.oklch(LiveLight.RGB(r: 0x0A, g: 0x84, b: 0xFF))

        #expect(abs(blue.l - orange.l) < 0.005 && abs(blue.c - orange.c) < 0.005)
        #expect(abs(blue.h - systemBlue.h) < 1)
    }

    /// A colour's OKLCH lightness, chroma and hue in degrees, from its sRGB.
    private static func oklch(_ colour: LiveLight.RGB) -> (l: Double, c: Double, h: Double) {
        let linear = [colour.r, colour.g, colour.b].map { value -> Double in
            let v = value / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = (linear[0], linear[1], linear[2])
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s

        return (lightness, hypot(a, bb), (atan2(bb, a) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360))
    }

    private static func css(_ c: LiveLight.RGB) -> String {
        "\(Int(c.r.rounded())) \(Int(c.g.rounded())) \(Int(c.b.rounded()))"
    }
}
