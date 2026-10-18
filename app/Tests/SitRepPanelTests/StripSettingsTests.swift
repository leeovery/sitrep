import Foundation
@testable import SitRepPanel
import Testing

struct StripSettingsTests {
    private static let lees = #"{"bounce":0.50,"dwell":120,"reach":3,"pour":1.00,"glide":1.00,"fade":160,"close":1.00,"room":12,"grace":300,"settle":1000,"slide":1.00,"swells":2,"edge":"left"}"#

    @Test func theDefaultsAreLeesPrintedAsTheDesignAndTheCopySettingsJSONHaveThem() {
        #expect(StripSettings().json == Self.lees)
    }

    @Test func leesJSONReadsBackAsTheDefaults() throws {
        #expect(try StripSettings(json: Self.lees) == StripSettings())
    }

    /// The switches the prototype has dropped, Lee's choices now built in, are passed over.
    @Test func onlyTheEdgeIsASwitchStill() throws {
        let read = try StripSettings(json: #"{"between":"each","during":"stay","top":"hang","edge":"right"}"#)

        var expected = StripSettings()
        expected.edge = .right
        #expect(read == expected)
        #expect(read.json.hasSuffix(#""swells":2,"edge":"right"}"#))
    }

    @Test func otherSettingsPrintAsThePrototypePrintsThem() {
        var settings = StripSettings()
        settings.bounce = 0.42
        settings.reach = 2.5
        settings.pour = 2
        settings.settle = 50

        #expect(settings.json == #"{"bounce":0.42,"dwell":120,"reach":2.5,"pour":2.00,"glide":1.00,"fade":160,"close":1.00,"room":12,"grace":300,"settle":50,"slide":1.00,"swells":2,"edge":"left"}"#)
    }

    @Test func eachDialGoesOntoItsSlidersRangeAndStep() throws {
        let read = try StripSettings(json: #"{"bounce":2,"dwell":124,"reach":2.7,"pour":0.1,"fade":10,"room":25,"grace":999,"settle":1020,"swells":5}"#)

        #expect(read.bounce == 1)
        #expect(read.dwell == 120)
        #expect(read.reach == 2.5)
        #expect(read.pour == 0.5)
        #expect(read.fade == 40)
        #expect(read.room == 20)
        #expect(read.grace == 800)
        #expect(read.settle == 1000)
        #expect(read.swells == 3)
    }

    @Test func theDialsHaveThePrototypesNamesRangesAndSteps() {
        let dials = StripDial.allCases.map { "\($0.name) \($0.range.lowerBound)...\($0.range.upperBound) by \($0.step)" }

        #expect(dials == [
            "Bounce 0.0...1.0 by 0.01",
            "Dwell 0.0...400.0 by 10.0",
            "Reach 0.0...8.0 by 0.5",
            "Pour 0.5...2.0 by 0.01",
            "Glide 0.5...2.0 by 0.01",
            "Fade 40.0...400.0 by 10.0",
            "Close 0.5...2.0 by 0.01",
            "Room 0.0...20.0 by 1.0",
            "Grace 0.0...800.0 by 10.0",
            "Settle 0.0...3000.0 by 50.0",
            "Slide 0.5...2.0 by 0.01",
            "Swells 1.0...3.0 by 1.0",
        ])
    }

    @Test func eachDialShowsAsItsSlidersLabelDoes() {
        let settings = StripSettings()

        #expect(StripDial.allCases.map { $0.show(settings[$0]) } == [
            "0.50", "120ms", "3px", "1.00×", "1.00×", "160ms", "1.00×", "12px", "300ms", "1000ms", "1.00×", "2×",
        ])
        #expect(StripDial.reach.show(2.5) == "2.5px")
    }

    @Test func atLeesSettingsTheDerivedSpringsAreTheDesignsTable() {
        #expect(StripSettings().derived == "springs, response·damping after Bounce ×1.00, Pour 1.00×, Glide 1.00×, "
            + "Close 1.00×, Slide 1.00×: reach 0.20·0.70, pour 0.26·0.72, grow 0.22·0.80, glide 0.24·0.82, "
            + "width 0.24·0.86, draw 0.22·0.80, slide 0.36·0.80, arrive 0.30·0.55, press 0.10·0.70")
    }

    @Test func eachSpeedDialSpeedsItsOwnSpringsAndNothingElse() {
        var settings = StripSettings()
        settings.pour = 2
        settings.glide = 0.5
        settings.close = 1.25
        settings.slide = 1.6

        let responses = StripSpring.allCases.map { settings.sp($0).response / $0.listed.response }

        #expect(responses.map { ($0 * 1e9).rounded() / 1e9 } == [0.5, 0.5, 0.5, 2, 2, 0.8, 0.625, 0.625, 1])
    }

    @Test func copySettingsCopiesAHeaderTheJSONAndWhatItMakes() {
        let settings = StripSettings()

        #expect(settings.copied == "SitRep · Strip settings\n\(settings.json)\n\(settings.derived)")
    }
}
