import Foundation
@testable import SitRepPanel
import Testing

struct CardSettingsTests {
    private static let lees = #"{"bounce":0.70,"nudge":8,"slide":0.93,"lag":30,"close":0.88,"swell":25,"swells":2,"edge":"left","light":"live"}"#

    @Test func theDefaultsAreLeesRoundTwoSettingsPrintedAsTheCopySettingsJSON() {
        #expect(CardSettings().json == Self.lees)
    }

    @Test func leesJSONReadsBackAsTheDefaults() throws {
        #expect(try CardSettings(json: Self.lees) == CardSettings())
    }

    @Test func otherSettingsPrintAsThePrototypePrintsThem() {
        var settings = CardSettings()
        settings.bounce = 0.5
        settings.nudge = 7.5
        settings.slide = 2
        settings.lag = 0
        settings.edge = .right

        #expect(settings.json == #"{"bounce":0.50,"nudge":7.5,"slide":2.00,"lag":0,"close":0.88,"swell":25,"swells":2,"edge":"right","light":"live"}"#)
    }

    @Test func aKeyMissingOrUnreadableKeepsItsDefault() throws {
        let read = try CardSettings(json: #"{"nudge":4,"lag":"long","edge":"top"}"#)

        var expected = CardSettings()
        expected.nudge = 4
        #expect(read == expected)
    }

    @Test func eachDialGoesOntoItsSlidersRangeAndStep() throws {
        let read = try CardSettings(json: #"{"bounce":-1,"nudge":7.3,"slide":0.934,"lag":33,"close":9,"swell":14,"swells":2.6}"#)

        #expect(read.bounce == 0)
        #expect(read.nudge == 7.5)
        #expect(read.slide == 0.93)
        #expect(read.lag == 35)
        #expect(read.close == 2)
        #expect(read.swell == 15)
        #expect(read.swells == 3)
    }

    @Test func theDialsHaveThePrototypesNamesRangesAndSteps() {
        let dials = CardDial.allCases.map { "\($0.name) \($0.range.lowerBound)...\($0.range.upperBound) by \($0.step)" }

        #expect(dials == [
            "Bounce 0.0...1.0 by 0.01",
            "Nudge 0.0...10.0 by 0.5",
            "Slide 0.5...2.0 by 0.01",
            "Lag 0.0...200.0 by 5.0",
            "Close 0.5...2.0 by 0.01",
            "Swell 15.0...30.0 by 1.0",
            "Swells 1.0...3.0 by 1.0",
        ])
    }

    @Test func eachDialShowsAsItsSlidersLabelDoes() {
        let settings = CardSettings()

        #expect(CardDial.allCases.map { $0.show(settings[$0]) } == ["0.70", "8px", "0.93×", "30ms", "0.88×", "25px", "2×"])
        #expect(CardDial.nudge.show(7.5) == "7.5px")
    }

    @Test func atLeesSettingsTheDerivedSpringsAreTheDesignsTable() {
        #expect(CardSettings().derived == "springs, response·damping after Bounce ×0.88, Slide 0.93×, Close 0.88×: "
            + "slide 0.19·0.70, length 0.17·0.75, follow 0.24·0.79, shrink 0.14·1.00, home 0.16·1.00, nudge 0.25·0.79, "
            + "ask 0.32·0.53")
    }

    @Test func slideSpeedsTheOpeningSpringsAndCloseTheClosingOnesAndNothingElse() {
        var settings = CardSettings()
        settings.bounce = 0.5
        settings.slide = 2
        settings.close = 0.5

        let responses = CardSpring.allCases.map { settings.sp($0).response / $0.listed.response }

        #expect(responses == [0.5, 0.5, 1, 2, 2, 1, 1])
        #expect(CardSpring.allCases.allSatisfy { settings.sp($0).damping == min(1, $0.listed.damping) })
    }

    @Test func copySettingsCopiesAHeaderTheJSONAndWhatItMakes() {
        let settings = CardSettings()

        #expect(settings.copied == "SitRep · Card settings\n\(settings.json)\n\(settings.derived)")
    }
}
