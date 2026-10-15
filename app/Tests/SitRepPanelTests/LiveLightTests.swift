import Foundation
@testable import SitRepPanel
import Testing

/// The Live light against the prototype: every expected number here is what lights.js's own `drawLive`, run under
/// node on a canvas that records what it is given, paints at the same moment, as the canvas's colour strings round
/// it: each body stop's red, green and blue, the centre line's alpha to three places, and the opacity.
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
        #expect(abs(LiveLight.brighten(sinceAsk) - brighten) < 1e-12)
    }

    @Test func atTheBreathsTroughItStaysOrangeAtEightySixPercent() {
        let light = LiveLight(time: 0, sinceAsk: nil)

        #expect(light.opacity == 0.86)
        #expect(light.body.allSatisfy { $0.r > $0.g && $0.g > $0.b })
    }

    private static func css(_ c: LiveLight.RGB) -> String {
        "\(Int(c.r.rounded())) \(Int(c.g.rounded())) \(Int(c.b.rounded()))"
    }
}
