import Foundation
@testable import SitRepPanel
import Testing

struct SettingsTests {
    private static let lees = #"{"bounce":0.90,"pull":0.35,"hold":35,"reach":10,"push":20,"land":1.11,"close":1.81,"swell":25,"swells":2,"edge":"left","light":"live"}"#

    @Test func theDefaultsAreLeesRoundElevenSettingsPrintedAsTheCopySettingsJSON() {
        #expect(Settings().json == Self.lees)
    }

    @Test func leesJSONReadsBackAsTheDefaults() throws {
        #expect(try Settings(json: Self.lees) == Settings())
    }

    @Test func otherSettingsPrintAsThePrototypePrintsThem() {
        var settings = Settings()
        settings.bounce = 0.5
        settings.pull = 1
        settings.hold = 8
        settings.push = 100
        settings.close = 0.5
        settings.edge = .right

        #expect(settings.json == #"{"bounce":0.50,"pull":1.00,"hold":8,"reach":10,"push":100,"land":1.11,"close":0.50,"swell":25,"swells":2,"edge":"right","light":"live"}"#)
    }

    @Test func aKeyMissingOrUnreadableKeepsItsDefault() throws {
        let read = try Settings(json: #"{"bounce":0.4,"pull":"lots","edge":"top","light":"glow"}"#)

        var expected = Settings()
        expected.bounce = 0.4
        #expect(read == expected)
    }

    @Test func eachDialGoesOntoItsSlidersRangeAndStep() throws {
        let read = try Settings(json: #"{"bounce":1.7,"pull":0.344,"hold":34.5,"reach":2,"push":-5,"land":0.006,"close":0.123,"swell":40,"swells":0}"#)

        #expect(read.bounce == 1)
        #expect(read.pull == 0.34)
        #expect(read.hold == 35)
        #expect(read.reach == 4)
        #expect(read.push == 0)
        #expect(read.land == 0.01)
        #expect(read.close == 0.5)
        #expect(read.swell == 30)
        #expect(read.swells == 1)
    }

    @Test func theSettingsRoundTripThroughCodable() throws {
        var settings = Settings()
        settings.pull = 0.62
        settings.edge = .right

        let data = try JSONEncoder().encode(settings)

        #expect(try JSONDecoder().decode(Settings.self, from: data) == settings)
    }

    @Test func theDialsHaveThePrototypesRangesAndSteps() {
        let dials = Dial.allCases.map { "\($0.rawValue) \($0.range.lowerBound)...\($0.range.upperBound) by \($0.step)" }

        #expect(dials == [
            "bounce 0.0...1.0 by 0.01",
            "pull 0.0...2.0 by 0.01",
            "hold 8.0...44.0 by 1.0",
            "reach 4.0...24.0 by 1.0",
            "push 0.0...100.0 by 1.0",
            "land 0.0...2.0 by 0.01",
            "close 0.5...2.0 by 0.01",
            "swell 15.0...30.0 by 1.0",
            "swells 1.0...3.0 by 1.0",
        ])
    }

    @Test func eachDialShowsAsItsSlidersLabelDoes() {
        let settings = Settings()

        #expect(Dial.allCases.map { $0.show(settings[$0]) } == ["0.90", "0.35×", "35px", "10px", "20%", "1.11×", "1.81×", "25px", "2×"])
    }

    @Test func atLeesSettingsTheDerivedSpringsAndReachesAreTheReadmesTable() {
        #expect(Settings().derived == "springs, response·damping after Bounce ×0.76: "
            + "attract 0.20·0.57, relax 0.45·0.42, home 0.60·0.61, pour h 0.40·0.57, pour w 0.34·0.55, cling 0.24·0.55, "
            + "cling y 0.16·0.65, tongue 0.08·0.61, return 0.30·0.29, ring 0.17·0.29, release 0.30·0.38, drain 0.60·0.95, "
            + "land 0.19·0.24, rebound 0.20·0.42, ask 0.42·0.38 · from Pull: field 49px, tongue 7.7px, cling 2.1px")
    }

    @Test func copySettingsCopiesAHeaderTheJSONAndWhatItMakesAsThePrototypeDoes() {
        var settings = Settings()
        settings.pull = 1

        #expect(settings.copied == "SitRep · Meniscus settings\n\(settings.json)\n\(settings.derived)")
    }

    @Test func eachDialIsNamedAsThePrototypesSliderIs() {
        #expect(Dial.allCases.map(\.name) == ["Bounce", "Pull", "Hold", "Reach", "Push", "Land", "Close", "Swell", "Swells"])
    }

    @Test(arguments: [(0.0, 1.4), (0.5, 1.0), (1.0, 0.7)])
    func bounceScalesEveryDampingFraction(bounce: Double, scale: Double) {
        var settings = Settings()
        settings.bounce = bounce

        #expect(abs(settings.bounceScale - scale) < 1e-12)
        for kind in SpringKind.allCases {
            #expect(settings.sp(kind).response == kind.listed.response)
            #expect(abs(settings.sp(kind).damping - min(1, kind.listed.damping * scale)) < 1e-12)
        }
    }

    @Test func noBounceCapsTheDampingFractionAtOne() {
        var settings = Settings()
        settings.bounce = 0

        #expect(settings.sp(.attract).damping == 1)
        #expect(settings.sp(.drain).damping == 1)
        #expect(abs(settings.sp(.ring).damping - 0.532) < 1e-12)
    }
}
